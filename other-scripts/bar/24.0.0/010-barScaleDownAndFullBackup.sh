#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2025-2026. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# This script is for preparing and performing a full backup of the given namespace. It will backup and scale down all CP4BA components in the given namespace.
#    Only tested with CP4BA version: 24.0.0 IF005, dedicated common services set-up

# Reference: 
# - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=recovery-backing-up-your-environment
# - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=data-taking-snapshots-by-using-snapshot-api
# - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=data-restoring-snapshots-by-using-snapshot-api

# Check if jq is installed
type jq > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo
  echo "Please install jq to continue."
  echo
  exit 1
fi

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import common utilities
source ${CUR_DIR}/common.sh
DATETIMESTR=$(date +'%Y%m%d_%H%M%S')

INPUT_PROPS_FILENAME="001-barParameters.sh"
INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${INPUT_PROPS_FILENAME}"

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${INPUT_PROPS_FILENAME}. Reading in variables from that script."
   
   . $INPUT_PROPS_FILENAME_FULL
   
   if [[ $cp4baProjectName == "REQUIRED" ]] || [[ $barTokenUser == "REQUIRED" ]] || [[ $barTokenPass == "REQUIRED" ]] || [[ $barTokenResolveCp4ba == "REQUIRED" ]] || [[ $barCp4baHost == "REQUIRED" ]]; then
      echo "File ${INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 1
   fi
   
   ##### Get Access Token if needed ###############################################
   if $useTokenForInsightsengineManagementURL || $useTokenForOpensearchRoute; then
     # get the access token
     if [[ "$barTokenUser" = "" ]] || [[ "$barTokenPass" = "" ]] || [[ "$barTokenResolveCp4ba" = "" ]] || [[ "$barCp4baHost" = "" ]]; then
      echo "File ${INPUT_PROPS_FILENAME} not fully updated. Pls. update parameters barTokenUser, barTokenPass, barTokenResolveCp4ba and barCp4baHost."
      echo
      exit 1
     else
       cp4batoken=$(curl -sk "$barCp4baHost/v1/preauth/validateAuth" -u $barTokenUser:$barTokenPass --resolve $barTokenResolveCp4ba | jq -r .accessToken)
     fi
   fi
   
   echo "Done!"
else
   echo
   echo "File ${INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 1
fi

BACKUP_ROOT_DIRECTORY_FULL="${CUR_DIR}/${cp4baProjectName}"
if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo
else
   echo
   mkdir "$BACKUP_ROOT_DIRECTORY_FULL"
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/ScaleDownAndFullBackup_$DATETIMESTR.log"
logInfo "Details will be logged to $LOG_FILE."
echo

echo -e "\x1B[1mThis script prepares namespace ${cp4baProjectName} for backup and performs a full backup of it. It will scale down and backup all CP4BA components in the given namespace. \x1B[0m"

if $suppressConfirmations; then
  echo
else
  echo
  printf "Do you want to continue? (Yes/No, default: No): "
  read -rp "" ans
  case "$ans" in
  "y"|"Y"|"yes"|"Yes"|"YES")
    echo
    logInfo "Ok, scaling down and backing up the CP4BA deployment in namespace ${cp4baProjectName}..."
    echo
    ;;
  *)
    echo
    logInfo "Exiting..."
    echo
    exit 0
    ;;
  esac
fi

##### Preparation ##############################################################
## Verify OCP Connection
logInfo "Verifying OC CLI is connected to the OCP cluster..."
WHOAMI=$(oc whoami)
logInfo "WHOAMI =" $WHOAMI

if [[ "$WHOAMI" == "" ]]; then
   logError "OC CLI is NOT connected to the OCP cluster. Please log in first with an admin user to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
   echo
   exit 1
fi
echo

## Switch to CP4BA project
project=$(oc project --short)
logInfo "project =" $project
if [[ "$project" != "$cp4baProjectName" ]]; then
   logInfo "Switching to project ${cp4baProjectName}..."
   logInfo $(oc project $cp4baProjectName)
fi
echo

## Create backup directory
logInfo "Creating backup directory..."
BACKUP_DIR=$BACKUP_ROOT_DIRECTORY_FULL/backup_${DATETIMESTR}
mkdir -p $BACKUP_DIR
echo

## Create properties file to record made changes
propertiesfile=$BACKUP_ROOT_DIRECTORY_FULL/properties.sh
if [[ -f $propertiesfile ]]; then
  backupFile=$BACKUP_ROOT_DIRECTORY_FULL/properties_$(date +'%Y%m%d_%H%M%S').bak
  logInfo "Old properties file found. Moving it to" $backupFile
  mv $propertiesfile $backupFile
fi
logInfo "Persisting scale down information in" $propertiesfile
cp ${CUR_DIR}/templates/properties.template.sh $propertiesfile

# Persist the project for which this backup is
sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g" $propertiesfile

# Persist the replica size of the common-web-ui deployment
commonWebUiReplicas=$(oc get pod -l=app.kubernetes.io/name=common-web-ui -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
sed -i.bak "s|§cp4baCommonWebUiReplicaSize|$commonWebUiReplicas|g" $propertiesfile
echo

## Get CP4BA deployment name
CP4BA_NAME=$(oc get ICP4ACluster -o name |cut -d "/" -f 2)
logInfo "CP4BA deployment name: $CP4BA_NAME"
sed -i.bak "s|§cp4baClusterName|$CP4BA_NAME|g" $propertiesfile
echo

# Persist replica size of insights engine task manager pods
# not always deployed
if oc get deployment $CP4BA_NAME-insights-engine-flink-taskmanager > /dev/null 2>&1; then
  insightsEngineFlinkTaskManagerReplicaSize=$(oc get deployment $CP4BA_NAME-insights-engine-flink-taskmanager -o=jsonpath='{.spec.replicas}')
  logInfo "insightsEngineFlinkTaskManagerReplicaSize: $insightsEngineFlinkTaskManagerReplicaSize"
  sed -i.bak "s|§cp4baInsightsEngineFlinkTaskmanagerReplicaSize|$insightsEngineFlinkTaskManagerReplicaSize|g" $propertiesfile
  echo
fi

## Get CP4BA version
CP4BA_VERSION=$(oc get ICP4ACluster $CP4BA_NAME -o 'custom-columns=NAME:.metadata.name,VERSION:.spec.appVersion' --no-headers | awk '{print $2}')
logInfo "Found CP4BA version: $CP4BA_VERSION"
echo

## Get all deployment / sts and pod counts before scaling down
logInfo "Get current running state & count of all pod, deployment, sts counts before scaling down"
echo
logInfo "=== Pods ==="
oc get pods -n $cp4baProjectName
echo
logInfo "=== Deployments ==="
oc get deployments -n $cp4baProjectName
echo
logInfo "=== Stateful Sets ==="
oc get sts -n $cp4baProjectName
echo
logInfo "=== PostgreSQL Cluster ==="
oc get cluster.postgresql -n $cp4baProjectName
echo
logInfo "=== Strimzi Pod Set ==="
oc get strimzipodset -n $cp4baProjectName
echo
logInfo "=== CronJobs ==="
oc get cronjobs -n $cp4baProjectName
echo
logInfo "=== Jobs ==="
oc get jobs -n $cp4baProjectName
echo



##### Initial scale down ##############################################################
# Scale down all operators
logInfo "Scaling down operators..."
logInfo $(oc scale deploy ibm-cp4a-operator --replicas=0)
logInfo $(oc scale deploy ibm-content-operator --replicas=0)
logInfo $(oc scale deploy ibm-cp4a-wfps-operator --replicas=0)
logInfo $(oc scale deploy ibm-dpe-operator --replicas=0)
logInfo $(oc scale deploy ibm-insights-engine-operator --replicas=0)
# Not always deployed - This is for BAI
if oc get deployment flink-kubernetes-operator > /dev/null 2>&1; then
  logInfo $(oc scale deploy flink-kubernetes-operator --replicas=0)
fi
logInfo $(oc scale deploy ibm-ads-operator --replicas=0)
logInfo $(oc scale deploy ibm-pfs-operator --replicas=0)
logInfo $(oc scale deploy ibm-workflow-operator --replicas=0)
logInfo $(oc scale deploy ibm-zen-operator --replicas=0)
logInfo $(oc scale deploy icp4a-foundation-operator --replicas=0)
logInfo $(oc scale deploy ibm-iam-operator --replicas=0)
logInfo $(oc scale deploy ibm-commonui-operator --replicas=0)
logInfo $(oc scale deploy ibm-common-service-operator --replicas=0)
logInfo $(oc scale deploy ibm-odm-operator --replicas=0)
# Not always deployed - This is for BAI and PFS
if oc get deployment ibm-elasticsearch-operator-ibm-es-controller-manager > /dev/null 2>&1; then
  logInfo $(oc scale deploy ibm-elasticsearch-operator-ibm-es-controller-manager --replicas=0)
fi
# Not always deployed - This is for BAI KAFKA Events
if oc get deployment iaf-system-entity-operator > /dev/null 2>&1; then
  logInfo $(oc scale deploy iaf-system-entity-operator --replicas=0)
fi
logInfo $(oc scale deploy operand-deployment-lifecycle-manager --replicas=0)

# these two operator deployments do have the version in their name, therefore we have to get the deployment name first
eventsOperatorDeployment=$(oc get deployment -o 'custom-columns=NAME:.metadata.name,SELECTOR:.spec.selector.matchLabels.name' --no-headers --ignore-not-found | grep 'ibm-events-operator' | awk '{print $1}')
# not always deployed
if [[ "$eventsOperatorDeployment" != "" ]]; then
  logInfo $(oc scale deploy $eventsOperatorDeployment --replicas=0)
fi
postgresqlOperatorDeployment=$(oc get deployment -l=app.kubernetes.io/name=cloud-native-postgresql -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | awk '{print $1}')
#logInfo $(oc scale deploy $postgresqlOperatorDeployment --replicas=0)
sleep 20
echo

# Scale down bastudio, navigator, baw, cpe and navigator related pods
logInfo $(oc scale deployment $CP4BA_NAME-navigator-watcher --replicas=0)
cpewatcherdeployment=$(oc get deployment -l=app.kubernetes.io/name=$CP4BA_NAME-cpe-watcher --no-headers --ignore-not-found | awk '{print $1}')
if [[ "$cpewatcherdeployment" != "" ]]; then
  logInfo $(oc scale deployment $cpewatcherdeployment --replicas=0)
fi
echo

# Scale to 1, wait till all other pods are gone, then scale to 0
logInfo "Scaling major CP4BA components to 1..."
bastudiosts=$(oc get sts -l=app.kubernetes.io/name=bastudio --no-headers --ignore-not-found | awk '{print $1}')
if [[ "$bastudiosts" != "" ]]; then
  logInfo $(oc scale statefulset $bastudiosts --replicas=1)
fi
logInfo $(oc scale deployment $CP4BA_NAME-navigator-deploy --replicas=1)
bawserversts=$(oc get sts -l=app.kubernetes.io/name=workflow-server --no-headers --ignore-not-found | awk '{print $1}')
if [[ "$bawserversts" != "" ]]; then
  for i in $bawserversts; do
    logInfo $(oc scale statefulset $i --replicas=1)
  done
fi
logInfo $(oc scale deployment $CP4BA_NAME-cpe-deploy --replicas=1)
echo

sleep 30

# Delete all completed pods so that they don't block scaling down bastudio or workflow
logInfo "Deleting completed pods..."
completedpods=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase' --no-headers --ignore-not-found | grep 'Succeeded' | awk '{print $1}')
logInfo "completed pods = " $completedpods
for i in $completedpods; do
   logInfo "deleting pod =" $i;
   logInfo $(oc delete pod $i)
done
echo

# Now scale down bastudio, navigator, baw, pfs, cpe and navigator to 0
logInfo "Scaling major CP4BA components to 0. This would wait forever! In that case please check manually why the pods do not get removed, or manually remove any Completed pods that could interfere here."
echo
if [[ "$bastudiosts" != "" ]]; then
  logInfo "Scaling down BAStudio pods to 0..."
  logInfo $(oc scale statefulset $bastudiosts --replicas=0)
  bastudiopod=$(oc get pod -l=app.kubernetes.io/name=bastudio -o name)
  GONE=false
  echo -n "  Waiting..."
  while [[ $GONE == false ]]
  do
    if [[ $bastudiopod != "" ]]; then
      echo -n "."
      sleep 10
      bastudiopod=$(oc get pod -l=app.kubernetes.io/name=bastudio -o name)
    else
      GONE=true
      echo
      logInfo "BAStudio pods scaled to 0"
    fi
  done
  echo
fi

logInfo "Scaling down Navigator pods to 0..."
logInfo $(oc scale deployment $CP4BA_NAME-navigator-deploy --replicas=0)
navigatorpod=$(oc get pod -l=app.kubernetes.io/name=$CP4BA_NAME-navigator-deploy -o name)
GONE=false
echo -n "  Waiting..."
while [[ $GONE == false ]]
do
  if [[ $navigatorpod != "" ]]; then
    echo -n "."
    sleep 10
    navigatorpod=$(oc get pod -l=app.kubernetes.io/name=$CP4BA_NAME-navigator-deploy -o name)
  else
    GONE=true
    echo
    logInfo "Navigator pods scaled to 0"
  fi
done
echo

if [[ "$bawserversts" != "" ]]; then
  logInfo "Scaling down BAW Server pods to 0..."
  for i in $bawserversts; do
    logInfo $(oc scale statefulset $i --replicas=0)
  done
  bawserverpod=$(oc get pod -l=app.kubernetes.io/name=workflow-server -o name)
  GONE=false
  echo -n "  Waiting..."
  while [[ $GONE == false ]]
  do
    if [[ $bawserverpod != "" ]]; then
      echo -n "."
      sleep 10
      bawserverpod=$(oc get pod -l=app.kubernetes.io/name=workflow-server -o name)
    else
      GONE=true
      echo
      logInfo "BAW Server pods scaled to 0"
    fi
  done
  echo
fi

logInfo "Scaling down CPE pods to 0..."
logInfo $(oc scale deployment $CP4BA_NAME-cpe-deploy --replicas=0)
cpepod=$(oc get pod -l=app.kubernetes.io/name=$CP4BA_NAME-cpe-deploy -o name)
GONE=false
echo -n "  Waiting..."
while [[ $GONE == false ]]
do
  if [[ $cpepod != "" ]]; then
    echo -n "."
    sleep 10
    cpepod=$(oc get pod -l=app.kubernetes.io/name=$CP4BA_NAME-cpe-deploy -o name)
  else
    GONE=true
    echo
    logInfo "CPE pods scaled to 0"
  fi
done
echo

# Suspend all cron jobs
logInfo "Suspending cron jobs..."
cronJobs=$(oc get cronjob -o 'custom-columns=NAME:.metadata.name,SUSPEND:.spec.suspend' --no-headers --ignore-not-found | grep 'false' | awk '{print $1}')
cronJobsProperty=""
logInfo "cronJobs =" $cronJobs
for i in $cronJobs; do
   if [[ $cronJobsProperty = "" ]]; then
     cronJobsProperty="$i"
   else
     cronJobsProperty="$cronJobsProperty,$i"
   fi
   logInfo "suspending cron job=" $i;
   logInfo $(oc patch cronJob $i --type merge --patch '{"spec":{"suspend":true}}');
done
sed -i.bak "s|§cp4baSuspendedCronJobs|$cronJobsProperty|g" $propertiesfile
echo



##### Initial backup ##############################################################

##### Backup uid definition ####################################################
NAMESPACE_UID=$(oc describe project $cp4baProjectName | grep uid-range | cut -d"=" -f2 | cut -d"/" -f1)
logInfo "Namespace $cp4baProjectName uid: $NAMESPACE_UID"
echo $NAMESPACE_UID > ${BACKUP_DIR}/namespace_uid
echo

##### CPfs backup #####################################################################
if [[ $CP4BA_VERSION =~ "24.0.0" ]]; then

  ##### Backup CommonService-IM PostgreSQL Database ###########################################
  csimpods=$(oc get pod -l=postgresql=common-service-db --no-headers --ignore-not-found | awk '{print $1}' | sort)
  for pod in ${csimpods[*]}
  do
    logInfo "Backing up CommonService-IM PostgreSQL Database using pod ${pod}..."
    oc exec --container postgres $pod -it -- bash -c "pg_dump -d im -U postgres -Fp -c -C --if-exists  -f /var/lib/postgresql/data/backup_csimdb.sql"
    logInfo $(oc cp --container postgres ${pod}:/var/lib/postgresql/data/backup_csimdb.sql ${BACKUP_DIR}/postgresql/backup_csimdb.sql)
    break
  done

  # check if backup was taken successfully
  if [ -e "${BACKUP_DIR}/postgresql/backup_csimdb.sql" ]; then
    logInfo "CommonService-IM PostgreSQL Database backup completed successfully."
    # clean up pod storage
    oc exec --container postgres $pod -it -- bash -c "rm -f /var/lib/postgresql/data/backup_csimdb.sql"
  else
    logError "CommonService-IM PostgreSQL Database backup failed, check logs!"
    echo
    exit 1
  fi
  echo

  ##### Backup Zen Metastore PostgreSQL Database ###########################################
  zendbpgpods=$(oc get pod -l=postgresql=zen-metastore-edb --no-headers --ignore-not-found | awk '{print $1}' | sort)
  for pod in ${zendbpgpods[*]}
  do
    logInfo "Backing up Zen Metastore DB PostgreSQL Database using pod ${pod}..."
    oc exec --container postgres $pod -it -- bash -c "pg_dump -d zen -U postgres -Fp -c -C --if-exists  -f /var/lib/postgresql/data/backup_zendb.sql"
    logInfo $(oc cp --container postgres ${pod}:/var/lib/postgresql/data/backup_zendb.sql ${BACKUP_DIR}/postgresql/backup_zendb.sql)
    break
  done

  # check if backup was taken successfully
  if [ -e "${BACKUP_DIR}/postgresql/backup_zendb.sql" ]; then
    logInfo "Zen Metastore PostgreSQL Database backup completed successfully."
    # clean up pod storage
    oc exec --container postgres $pod -it -- bash -c "rm -f /var/lib/postgresql/data/backup_zendb.sql"
  else
    logError "Zen Metastore PostgreSQL Database backup failed, check logs!"
    echo
    exit 1
  fi
  echo

  # ##### Backup Keycloak PostgreSQL Database (Not always installed)###########################################
  # kcedbpods=$(oc get pod -l=postgresql=keycloak-edb-cluster --no-headers --ignore-not-found | awk '{print $1}' | sort)
  # for pod in ${kcedbpods[*]}
  # do
  #   logInfo "Backing up Keycloak PostgreSQL Database using pod ${pod}..."
  #   oc exec --container postgres $pod -it -- bash -c "pg_dump -d keycloak -U postgres -Fp -c -C --if-exists  -f /var/lib/postgresql/data/backup_kcedb.sql"
  #   logInfo $(oc cp --container postgres ${pod}:/var/lib/postgresql/data/backup_kcedb.sql ${BACKUP_DIR}/postgresql/backup_kcedb.sql)
  #   break
  # done

  # # check if backup was taken successfully
  # if [ -e "${BACKUP_DIR}/postgresql/backup_kcedb.sql" ]; then
  #   logInfo "Keycloak PostgreSQL Database backup completed successfully."
  #   # clean up pod storage
  #   oc exec --container postgres $pod -it -- bash -c "rm -f /var/lib/postgresql/data/backup_kcedb.sql"
  # else
  #   logError "Keycloak PostgreSQL Database backup failed, check logs!"
  #   echo
  #   exit 1
  # fi
  # echo

else
  # Backup implementation of CPfs for CP4BA versions 24.0.1, 25 is not developed yet. 
  logError "Do not know how to take backup of CPFS services for this Cloud Pak version $CP4BA_VERSION"
  echo
  exit 1
fi

##### Backup BTS PostgreSQL Database ###########################################
btscnpgpods=$(oc get pod -l=app.kubernetes.io/name=ibm-bts-cp4ba-bts --no-headers --ignore-not-found | awk '{print $1}' | sort)
for pod in ${btscnpgpods[*]}
do
  logInfo "Backing up BTS PostgreSQL Database using pod ${pod}..."
  oc exec --container postgres $pod -it -- bash -c "pg_dump -d BTSDB -U postgres -Fp -c -C --if-exists  -f /var/lib/postgresql/data/backup_btsdb.sql"
  logInfo $(oc cp --container postgres ${pod}:/var/lib/postgresql/data/backup_btsdb.sql ${BACKUP_DIR}/postgresql/backup_btsdb.sql)
  break
done

# check if backup was taken successfully
if [ -e "${BACKUP_DIR}/postgresql/backup_btsdb.sql" ]; then
  logInfo "BTS PostgreSQL Database backup completed successfully."
  # clean up pod storage
  oc exec --container postgres $pod -it -- bash -c "rm -f /var/lib/postgresql/data/backup_btsdb.sql"
else
  logError "BTS PostgreSQL Database backup failed, check logs!"
  echo
  exit 1
fi
echo

##### BAI ######################################################################
# Take Opensearch snapshot

# iaf-insights-engine-management needs to be up and running
if [[ $CP4BA_VERSION =~ "21.0.3" ]]; then
  MANAGEMENT_POD=$(oc get pod --no-headers --ignore-not-found -l component=iaf-insights-engine-management |awk {'print $1'})
else
  MANAGEMENT_POD=$(oc get pod --no-headers --ignore-not-found -l component=${CP4BA_NAME}-insights-engine-management |awk {'print $1'})
fi

# not always deployed
if [[ "$MANAGEMENT_POD" != "" ]]; then
  logInfo "Management pod: $MANAGEMENT_POD"
  
  # Get management service URL and credentails
  logInfo "Getting insightsengine details..."
  INSIGHTS_ENGINE=$(oc get insightsengine --no-headers | awk {'print $1'})
  BPC_URL=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.cockpit.endpoints[?(@.scope=="External")].uri}')
  logInfo "BPC URL: $BPC_URL"
  
  MANAGEMENT_URL=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].uri}')
  logInfo "Management URL: $MANAGEMENT_URL"
  
  MANAGEMENT_AUTH_SECRET=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].authentication.secret.secretName}')
  MANAGEMENT_USERNAME=$(oc get secret ${MANAGEMENT_AUTH_SECRET} -o jsonpath='{.data.username}' | base64 -d)
  MANAGEMENT_PASSWORD=$(oc get secret ${MANAGEMENT_AUTH_SECRET} -o jsonpath='{.data.password}' | base64 -d)
  FLINK_UI_URL=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.flinkUi.endpoints[?(@.scope=="External")].uri}')
  logInfo "Flink UI: $FLINK_UI_URL"
  
  # Retrieve the flink jobs
  FLINK_AUTH_SECRET=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.flinkUi.endpoints[?(@.scope=="External")].authentication.secret.secretName}')
  FLINK_USERNAME=$(oc get secret ${FLINK_AUTH_SECRET} -o jsonpath='{.data.username}' | base64 -d)
  FLINK_PASSWORD=$(oc get secret ${FLINK_AUTH_SECRET} -o jsonpath='{.data.password}' | base64 -d)
  logInfo "Retrieving flink jobs from $MANAGEMENT_URL/api/v1/processing/jobs/list..."
  
  # Take savepoints and cancel the jobs
  logInfo "Creating flink savepoints and canceling the jobs..."
  if $useTokenForInsightsengineManagementURL; then
    FLINK_SAVEPOINT_RESULTS=$(curl -X POST -sk --header "Authorization: ${cp4batoken}" -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} "${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints?cancel-job=true" --resolve "${barTokenResolveCp4ba}")
  else
    FLINK_SAVEPOINT_RESULTS=$(curl -X POST -sk -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} "${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints?cancel-job=true")
  fi
  if [[ $FLINK_SAVEPOINT_RESULTS == "" ]]; then
    FLINK_SAVEPOINT_COUNT=0
  else
    FLINK_SAVEPOINT_COUNT=$(echo $FLINK_SAVEPOINT_RESULTS | jq 'length')
  fi
  
  for ((i=0; i<$FLINK_SAVEPOINT_COUNT; i++)); do
    FLINK_SAVEPOINT_NAME=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].name")
    FLINK_SAVEPOINT_JID=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].jid")
    FLINK_SAVEPOINT_STATE=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].state")
    FLINK_SAVEPOINT_LOCATION=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].location")
    logInfo "  Flink savepoint: $FLINK_SAVEPOINT_NAME, JID: $FLINK_SAVEPOINT_JID, STATE: $FLINK_SAVEPOINT_STATE, Location: $FLINK_SAVEPOINT_LOCATION"
    logInfo "  Copying the savepoint to ${BACKUP_DIR}/flink/${FLINK_SAVEPOINT_LOCATION}..."
    logInfo $(oc cp --container management ${MANAGEMENT_POD}:${FLINK_SAVEPOINT_LOCATION} ${BACKUP_DIR}/flink${FLINK_SAVEPOINT_LOCATION})
  done
  echo
fi

# OpenSearch: There is in 24.0.0 no status in CP4BA's CR for that. In addition to that, there are various conditions under which OpenSearch will get installed, for example
# when requested exlicitely by optional components bai or opensearch, or when requested implicitely when enabling full text search in BAW or when PFS is installed in addition.
# We therefore here check if an OpenSearch cluster is installed, and if yes we back it up.

# TODO: In our dtq test environment we don't have a deployment without opensearch deployed. This is due to all deployments had elasticsearch in 21.0.3 due to PFS being always
# there when BAW is installed in 21.0.3.
# In 24.0.0 PFS is no longer installed by default, needs explicit deployment. We have to remove OpenSearch in -qa environment to cover this new variation.

isOpenSearchInstalled=false
OPENSEARCH_CLUSTER=$(oc get ElasticsearchClusters opensearch --ignore-not-found)
if [[ "$OPENSEARCH_CLUSTER" != "" ]]; then
  isOpenSearchInstalled=true
fi

# Create ES/OS snapshots
if $isOpenSearchInstalled; then
  logInfo "Declaring the location of the snapshot repository for OpenSearch..."
  OPENSEARCH_ROUTE=$(oc get route opensearch-route -o jsonpath='{.spec.host}')
  OPENSEARCH_PASSWORD=$(oc get secret opensearch-ibm-elasticsearch-cred-secret --no-headers --ignore-not-found -o jsonpath={.data.elastic} | base64 -d)
  if $useTokenForOpensearchRoute; then
    curl -skl --header "Authorization: ${cp4batoken}" -u elastic:$OPENSEARCH_PASSWORD -XPUT "https://$OPENSEARCH_ROUTE/_snapshot/${DATETIMESTR}" --resolve "${barTokenResolveCp4ba}" -H "Content-Type: application/json" -d'{"type":"fs","settings":{"location": "/workdir/snapshot_storage","compress": true}}'
  else
    curl -skl -u elastic:$OPENSEARCH_PASSWORD -XPUT "https://$OPENSEARCH_ROUTE/_snapshot/${DATETIMESTR}" -H "Content-Type: application/json" -d'{"type":"fs","settings":{"location": "/workdir/snapshot_storage","compress": true}}'
  fi
  echo
  
  logInfo "Creating snapshot backup_${DATETIMESTR}..."
  if $useTokenForOpensearchRoute; then
    SNAPSHOT_RESULT=$(curl -skL --header "Authorization: ${cp4batoken}" -u elastic:${OPENSEARCH_PASSWORD} -XPUT "https://${OPENSEARCH_ROUTE}/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?wait_for_completion=true&pretty=true" --resolve "${barTokenResolveCp4ba}")
  else
    SNAPSHOT_RESULT=$(curl -skL -u elastic:${OPENSEARCH_PASSWORD} -XPUT "https://${OPENSEARCH_ROUTE}/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?wait_for_completion=true&pretty=true")
  fi
  SNAPSHOT_STATE=$(echo $SNAPSHOT_RESULT | jq -r ".snapshot.state")
  checkResult $SNAPSHOT_STATE "SUCCESS" "Snapshot state"
  
  # Snapshots are incremental, we therefore leave it on the snapshot PVC without copying it onto the bastion host. It will get backed up when the PVCs are backed up.
  echo
fi



##### Final scale down ##############################################################

## Remove flink job submitters
if [[ "$MANAGEMENT_POD" != "" ]]; then
  logInfo "Removing flink job submitters..."
  logInfo $(oc get jobs -o custom-columns=NAME:.metadata.name | grep bai- | grep -v bai-setup | xargs oc delete job)
  echo
fi

# Scale down all deployments
# TODO: We want to be more specific here, scale down only the deployments we are aware of, not all.
logInfo "Scaling down deployments..."
deployments=$(oc get deploy -o name)
logInfo "deployments =" $deployments
for i in $deployments; do
   logInfo "scaling deployment =" $i
   logInfo $(oc scale $i --replicas=0)
done
echo


# Scale down all stateful sets
# TODO: We want to be more specific here, scale down only the stateful sets we are aware of, not all.
logInfo "Scaling down stateful sets..."
statefulSets=$(oc get sts -o name)
logInfo "statefulSets =" $statefulSets
for s in $statefulSets; do
  logInfo "Scaling stateful set =" $s
  logInfo $(oc scale $s --replicas=0)
done
echo

# Delete all remaing running pods that we know
logInfo "Deleting all remaing running CP4BA pods..."
kafkapods=$(oc get pod -l=app.kubernetes.io/name=kafka --no-headers --ignore-not-found | awk '{print $1}')
for pod in ${kafkapods[*]}
do
  logInfo $(oc delete pod $pod)
done
sleep 10

zookeeperpods=$(oc get pod -l=app.kubernetes.io/name=zookeeper --no-headers --ignore-not-found | awk '{print $1}')
for pod in ${zookeeperpods[*]}
do
  logInfo $(oc delete pod $pod)
done
sleep 10

btscnpgpods=$(oc get pod -l=app.kubernetes.io/name=ibm-bts-cp4ba-bts --no-headers --ignore-not-found | awk '{print $1}')
for pod in ${btscnpgpods[*]}
do
  logInfo $(oc delete pod $pod)
done
sleep 10

rrpods=$(oc get pod -l=app.kubernetes.io/name=resource-registry --no-headers --ignore-not-found | awk '{print $1}')
for pod in ${rrpods[*]}
do
   logInfo $(oc delete pod $pod)
done
echo


# Scale down all postgresql db zen-metastore-edb, common-service-db
logInfo $(oc annotate cluster.postgresql.k8s.enterprisedb.io zen-metastore-edb --overwrite k8s.enterprisedb.io/hibernation=on)
logInfo $(oc annotate cluster.postgresql.k8s.enterprisedb.io common-service-db --overwrite k8s.enterprisedb.io/hibernation=on)
sleep 60
echo

# Scale down postgres-operator
logInfo $(oc scale deploy $postgresqlOperatorDeployment --replicas=0)
sleep 20
echo

# Delete all completed pods
logInfo "Deleting completed pods..."
completedpods=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase' --no-headers --ignore-not-found | grep 'Succeeded' | awk '{print $1}')
logInfo "completed pods = " $completedpods
for i in $completedpods; do
   logInfo "deleting pod =" $i;
   logInfo $(oc delete pod $i)
done
echo

# Take backup of catalog sources before deleting catalog source pods
logInfo "Taking backup of catalog sources before deleting catalog source pods..."
# This will be used during ScaleUp.
oc get catalogsource -o yaml > $BACKUP_ROOT_DIRECTORY_FULL/catalogsource.yaml
# This will be stored inside Backup Folder and will be used during Restoration.
oc get catalogsource -o yaml > $BACKUP_DIR/catalogsource.yaml
logInfo "Deleting Catalog sources..."
logInfo $(oc delete catalogsource -n ${cp4baProjectName} --all)
echo

# Wait till all pods are gone
allpods=$(oc get pod --no-headers --ignore-not-found)
if [[ $allpods != "" ]]; then
  logInfo "Waiting till all pods in project $cp4baProjectName are gone before taking full backup. This would run forever, so please manually check the remaining pods and get them removed manually if needed!"
  echo
  logInfo "Currently there are the following pods remaining:"
  logInfo $allpods
  GONE=false
  echo -n "  Waiting..."
  while [[ $GONE == false ]]
  do
    if [[ $allpods != "" ]]; then
      echo -n "."
      sleep 10
      allpods=$(oc get pod --no-headers --ignore-not-found)
    else
      GONE=true
      echo
      logInfo "All pods are gone. Continuing with full backup."
    fi
  done
fi
echo



##### Final backup ##############################################################
# Now that those backups are done and everything is scaled down, we can take a full backup of all resources in the namespace
# In 001-barParameters.sh, one can specify which resources to skip, get that list first
skipToBackupResourceKinds=$(echo $barSkipToBackupResourceKinds | tr "," "\n")
logInfo "Collecting resources that need to be backed up..."
allResources=$(oc api-resources --verbs=list --namespaced=true -o name | xargs -n 1 oc get --show-kind --ignore-not-found -n $cp4baProjectName -o name)
echo
for i in $allResources; do
   # Get the kind and the name
   kind=$(echo $i | grep -oP '.*(?=/)')
   name=$(echo $i | grep -oP '(?<=/).*')
   
   doSkip=false
   for skipKind in $skipToBackupResourceKinds
   do
     if [[ "$skipKind" == "$kind" ]]; then
       logInfo "Skipping backup for resource =" $i
       doSkip=true
     fi
   done
   
   if [[ "$doSkip" = "false" ]]; then
     logInfo "Backing up resource =" $i
     RESOURCE_BACKUP_DIR=$BACKUP_DIR/$kind
     if [[ !(-d $RESOURCE_BACKUP_DIR) ]]; then
       mkdir -p $RESOURCE_BACKUP_DIR
     fi
     
     oc get $kind $name -o yaml > $RESOURCE_BACKUP_DIR/$name.yaml
   fi
done
echo

# Next, creating the script to backup the content of the PVs
logInfo "Creating 025-backup-pvs-<storageclass>.sh files..."
PV_BACKUP_DIR=${pvBackupDirectory}/$(basename $(dirname $BACKUP_DIR))/$(basename $BACKUP_DIR)

index=0
for storageclass in ${barStorageClass[@]}; do
  method=${barMethod[$index]}
  configData=${barConfigData[$index]}
  index=$(( index + 1 ))
  
  if [ "$method" == "ServerBackup" ]; then
    logInfoValue "Backing Up PV data for PVs using StorageClass " $storageclass
    
    rootDirectory=$(echo $configData | jq -r '.rootDirectory')        
    PV_BACKUP_DIR=${pvBackupDirectory}/$(basename $(dirname $BACKUP_DIR))/$(basename $BACKUP_DIR)        
    
    cat > $BACKUP_DIR/025-backup-pvs-${storageclass}.sh <<EOF
#!/bin/bash

function perform_backup() {
  namespace=\$1
  policy=\$2
  volumename=\$3
  claimname=\$4
  
  if [ "\$policy" == "${storageclass}" ]; then
    echo "Backing up PVC \$claimname"
    directory="$rootDirectory/\${namespace}-\${claimname}-\${volumename}"
    if [ -d "\$directory" ]; then
      (cd \$directory; tar cfz \$pvBackupDirectory/\${claimname}.tgz .)
    else
      echo "*** Error: Did not find persistent volume data in directory \$directory"
    fi
  else
    echo "*** Error: Dont know how to backup storage policy named \$policy"
  fi
}

pvBackupDirectory="${PV_BACKUP_DIR}"

mkdir -p \$pvBackupDirectory
EOF

    for pvc in $(oc get pvc -n $cp4baProjectName -o 'custom-columns=name:.metadata.name' --no-headers); do
      class=$(oc get pvc $pvc -o 'jsonpath={.spec.storageClassName}')
      if [ "$class" == "$storageclass" ]; then
        namespace=$(oc get pvc $pvc -o 'jsonpath={.metadata.namespace}')
        pv=$(oc get pvc $pvc -o 'jsonpath={.spec.volumeName}')
        echo perform_backup $namespace $class $pv $pvc >> $BACKUP_DIR/025-backup-pvs-${storageclass}.sh
        chmod +x $BACKUP_DIR/025-backup-pvs-${storageclass}.sh
      fi
    done
    logInfoValue "PV Backup Script Generated:" $BACKUP_DIR/025-backup-pvs-${storageclass}.sh
  fi
done
echo



rm $propertiesfile.bak



##### Finally... ###########################################
logInfo "Environment is scaled down, all resources are backed up. Next, please back up:"
logInfo "  - the content of the PVs (For exmaple, if storage class is nfs-client, use the generated the just generated script(s) $BACKUP_DIR/025-backup-pvs-<storageclass>.sh on the storage server using the root account)"
logInfo "  - the databases"
logInfo "  - the binary document data of CPE"
echo
