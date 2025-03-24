#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2025. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# This script is for preparing and performing a full backup of the given namespace. It will backup and scale down all CP4BA components in the given namespace.
#    Only tested with CP4BA version: 21.0.3 IF029 and 039, dedicated common services set-up

# Reference: 
# - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=recovery-backing-up-your-environments
# - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=elasticsearch-taking-restoring-snapshots-data
# - https://community.ibm.com/community/user/automation/blogs/dian-guo-zou/2022/10/12/backup-and-restore-baw-2103
# - https://www.ibm.com/docs/en/cloud-paks/foundational-services/3.23?topic=operator-foundational-services-backup-restore

# Check if jq is installed
type jq > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo "Please install jq to continue."
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
   if $useTokenForInsightsengineManagementURL || $useTokenForElasticsearchRoute; then
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

echo -e "\x1B[1mThis script prepares namespace ${cp4baProjectName} for backup and performs a full backup of it. It will scale down and backup all CP4BA components in the given namespace. \n \x1B[0m"

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

# Persist the replica size of the bts-316 deployment
cp4baBTS316ReplicaSize=$(oc get bts cp4ba-bts -o 'custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas' --no-headers | awk '{print $2}')
sed -i.bak "s|§cp4baBTS316ReplicaSize|$cp4baBTS316ReplicaSize|g" $propertiesfile
echo

## Get CP4BA deployment name
CP4BA_NAME=$(oc get ICP4ACluster -o name |cut -d "/" -f 2)
logInfo "CP4BA deployment name: $CP4BA_NAME"
echo

## Get CP4BA version
CP4BA_VERSION=$(oc get ICP4ACluster $CP4BA_NAME -o 'custom-columns=NAME:.metadata.name,VERSION:.spec.appVersion' --no-headers | awk '{print $2}')
logInfo "Found CP4BA version: $CP4BA_VERSION"
echo



##### Initial scale down ##############################################################
# Scale down all operators
logInfo "Scaling down operators..."
logInfo $(oc scale deploy ibm-cp4a-operator --replicas=0)
logInfo $(oc scale deploy ibm-cp4a-wfps-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-core-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-eventprocessing-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-flink-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-insights-engine-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy ibm-bts-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy ibm-elastic-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy nginx-ingress-controller --replicas=0)
logInfo $(oc scale deploy ibm-zen-operator --replicas=0)
logInfo $(oc scale deploy ibm-platform-api-operator --replicas=0)
logInfo $(oc scale deploy ibm-namespace-scope-operator --replicas=0)
logInfo $(oc scale deploy ibm-mongodb-operator --replicas=0)
logInfo $(oc scale deploy ibm-management-ingress-operator --replicas=0)
logInfo $(oc scale deploy ibm-ingress-nginx-operator --replicas=0)
logInfo $(oc scale deploy ibm-iam-operator --replicas=0)
logInfo $(oc scale deploy ibm-commonui-operator --replicas=0)
logInfo $(oc scale deploy ibm-common-service-operator --replicas=0)
# not always deployed
if oc get deployment iaf-system-entity-operator > /dev/null 2>&1; then
  logInfo $(oc scale deploy iaf-system-entity-operator --replicas=0)
fi
logInfo $(oc scale deploy iam-policy-controller --replicas=0)
logInfo $(oc scale deploy operand-deployment-lifecycle-manager --replicas=0)

# these two operator deployments do have the version in their name, therefore we have to get the deployment name first
eventsOperatorDeployment=$(oc get deployment -o 'custom-columns=NAME:.metadata.name,SELECTOR:.spec.selector.matchLabels.name' --no-headers --ignore-not-found | grep 'ibm-events-operator' | awk '{print $1}')
# not always deployed
if [[ "$eventsOperatorDeployment" != "" ]]; then
  logInfo $(oc scale deploy $eventsOperatorDeployment --replicas=0)
fi
postgresqlOperatorDeployment=$(oc get deployment -l=app.kubernetes.io/name=cloud-native-postgresql -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | awk '{print $1}')
logInfo $(oc scale deploy $postgresqlOperatorDeployment --replicas=0)
sleep 20
echo

# Scale down bastudio, navigator, baw, pfs, cpe and navigator related pods
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
logInfo $(oc scale statefulset $CP4BA_NAME-pfs --replicas=1)
logInfo $(oc scale deployment $CP4BA_NAME-cpe-deploy --replicas=1)
echo

sleep 30

# Now scale to 0
logInfo "Scaling major CP4BA components to 0..."
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
fi
logInfo "Scaling down PFS pods to 0..."
logInfo $(oc scale statefulset $CP4BA_NAME-pfs --replicas=0)
logInfo $(oc scale deployment $CP4BA_NAME-pfs-dbareg --replicas=0)
pfspod=$(oc get pod -l=app.kubernetes.io/name=$CP4BA_NAME-pfs -o name)
GONE=false
echo -n "  Waiting..."
while [[ $GONE == false ]]
do
  if [[ $pfspod != "" ]]; then
    echo -n "."
    sleep 10
    pfspod=$(oc get pod -l=app.kubernetes.io/name=$CP4BA_NAME-pfs -o name)
  else
    GONE=true
    echo
    logInfo "PFS pods scaled to 0"
  fi
done
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
if [[ $CP4BA_VERSION =~ "21.0.3" ]]; then
  ## Take MongoDB Backup 
  # Prime templates 
  logInfo "Priming resources to take MongoDB backup"
  cp ${CUR_DIR}/templates/mongodb-backup-pvc.template.yaml ${CUR_DIR}/mongodb-backup-pvc.yaml
  cp ${CUR_DIR}/templates/mongodb-backup-deployment.template.yaml ${CUR_DIR}/mongodb-backup-deployment.yaml

  sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g; s|§pvcStorageClass|$pvcStorageClassName|g" ${CUR_DIR}/mongodb-backup-pvc.yaml
  sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/mongodb-backup-deployment.yaml

  # Create resources necessary to backup MongoDB 
  oc apply -f ${CUR_DIR}/mongodb-backup-pvc.yaml
  oc apply -f ${CUR_DIR}/mongodb-backup-deployment.yaml

  # Wait indefinitely for deployment to be Available (pod Ready)
  oc wait -f ${CUR_DIR}/mongodb-backup-deployment.yaml --for=condition=Available --timeout=-1s

  mongodbpods=$(oc get pod -l=foundationservices.cloudpak.ibm.com=mongo-data --no-headers --ignore-not-found | awk '{print $1}' | sort)

  for pod in ${mongodbpods[*]}
  do
    logInfo "Backing up MongoDB in from pod ${pod}..."
    # prep certs files that will be used to take the backup
    oc exec $pod -it -- bash -c 'cat /cred/mongo-certs/tls.crt /cred/mongo-certs/tls.key > /work-dir/mongo.pem; cat /cred/cluster-ca/tls.crt /cred/cluster-ca/tls.key > /work-dir/ca.pem'
    oc exec $pod -it -- bash -c 'mongodump --oplog --archive=/dump/mongo.archive --host mongodb:$MONGODB_SERVICE_PORT --username $ADMIN_USER --password $ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /work-dir/ca.pem --sslPEMKeyFile /work-dir/mongo.pem'
    oc cp $pod:/dump/mongo.archive ${BACKUP_DIR}/mongodb/mongo.archive
    break
  done

  # check if backup was taken successfully
  if [ -e "${BACKUP_DIR}/mongodb/mongo.archive" ]; then
    # clean up pod storage and notify successful completion
    logInfo "MongoDB backup completed successfully."
    oc delete -f ${CUR_DIR}/mongodb-backup-deployment.yaml
    oc delete -f ${CUR_DIR}/mongodb-backup-pvc.yaml
  else
    logError "MongoDB backup failed, check logs!"
    echo
    exit 1
  fi
  echo

  ## Take Zen Services Backup
  # Prime templates 
  logInfo "Priming resources to take Zen Services backup"
  cp ${CUR_DIR}/templates/zen-backup-pvc.template.yaml ${CUR_DIR}/zen-backup-pvc.yaml
  cp ${CUR_DIR}/templates/zen4-br-scripts.template.yaml ${CUR_DIR}/zen4-br-scripts.yaml
  cp ${CUR_DIR}/templates/zen4-sa.template.yaml ${CUR_DIR}/zen4-sa.yaml
  cp ${CUR_DIR}/templates/zen4-role.template.yaml ${CUR_DIR}/zen4-role.yaml
  cp ${CUR_DIR}/templates/zen4-rolebinding.template.yaml ${CUR_DIR}/zen4-rolebinding.yaml
  cp ${CUR_DIR}/templates/zen-backup-deployment.template.yaml ${CUR_DIR}/zen-backup-deployment.yaml

  sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g; s|§pvcStorageClass|$pvcStorageClassName|g" ${CUR_DIR}/zen-backup-pvc.yaml
  sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen4-br-scripts.yaml
  sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen4-sa.yaml
  sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen4-role.yaml
  sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen4-rolebinding.yaml
  sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen-backup-deployment.yaml

  # Create resources necessary to backup Zen Services
  oc apply -f ${CUR_DIR}/zen-backup-pvc.yaml
  oc apply -f ${CUR_DIR}/zen4-br-scripts.yaml
  oc apply -f ${CUR_DIR}/zen4-sa.yaml
  oc apply -f ${CUR_DIR}/zen4-role.yaml
  oc apply -f ${CUR_DIR}/zen4-rolebinding.yaml
  oc apply -f ${CUR_DIR}/zen-backup-deployment.yaml

  # Wait indefinitely for deployment to be Available (pod Ready)
  oc wait -f ${CUR_DIR}/zen-backup-deployment.yaml --for=condition=Available --timeout=-1s

  zenbkpods=$(oc get pod -l=foundationservices.cloudpak.ibm.com=zen-data --no-headers --ignore-not-found | awk '{print $1}')

  for pod in ${zenbkpods[*]}
  do
    logInfo "Backing up Zen Services from pod ${pod}..."
    oc exec $pod -it -- bash -c "/zen4/zen4-br.sh $cp4baProjectName true"
    # Go into directory where backup was created and compress into single file
    oc exec $pod -it -- bash -c "cd /user-home && tar -cf zen-metastoredb-backup.tar zen-metastoredb-backup"
    oc cp $pod:/user-home/zen-metastoredb-backup.tar ${BACKUP_DIR}/zenbackup/zen-metastoredb-backup.tar
    break
  done

  # check if backup was taken successfully
  if [ -e "${BACKUP_DIR}/zenbackup/zen-metastoredb-backup.tar" ]; then
    logInfo "Zen Services backup completed successfully."

    oc delete -f ${CUR_DIR}/zen-backup-deployment.yaml
    oc delete -f ${CUR_DIR}/zen4-rolebinding.yaml
    oc delete -f ${CUR_DIR}/zen4-role.yaml
    oc delete -f ${CUR_DIR}/zen4-sa.yaml
    oc delete -f ${CUR_DIR}/zen4-br-scripts.yaml
    oc delete -f ${CUR_DIR}/zen-backup-pvc.yaml
  else
    logError "Zen Services backup failed, check logs!"
    echo
    exit 1
  fi
  echo
else
  # Backup implementation of CPfs for CP4BA versions 22, 23, and 24 is not developed yet. 
  # TODO: Backup CPfs for other versions of CP4BA specially 24
  logError "Do not know how to take backup of CPfs services for this Cloud Pak version $CP4BA_VERSION"
  echo
  exit 1
fi

##### Backup BTS PostgreSQL Database ###########################################
btscnpgpods=$(oc get pod -l=app.kubernetes.io/name=ibm-bts-cp4ba-bts --no-headers --ignore-not-found | awk '{print $1}' | sort)
for pod in ${btscnpgpods[*]}
do
  logInfo "Backing up BTS PostgreSQL Database from pod ${pod}..."
  oc exec --container postgres $pod -it -- bash -c "pg_dump -d BTSDB -U postgres -Fp -c -C --if-exists  -f /var/lib/postgresql/data/backup_btsdb.sql"
  oc cp --container postgres ${pod}:/var/lib/postgresql/data/backup_btsdb.sql ${BACKUP_DIR}/postgresql/backup_btsdb.sql
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
# Take ES snapshot

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
  
  #FLINK_JOBS=$(curl -sk -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} $MANAGEMENT_URL/api/v1/processing/jobs/list)
  #FLINK_JOBS_COUNT=$(echo $FLINK_JOBS |jq '.jobs' | jq 'length')
  
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
  
  # TODO: This sometimes does not work, needs further investigation
  for ((i=0; i<$FLINK_SAVEPOINT_COUNT; i++)); do
    FLINK_SAVEPOINT_NAME=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].name")
    FLINK_SAVEPOINT_JID=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].jid")
    FLINK_SAVEPOINT_STATE=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].state")
    FLINK_SAVEPOINT_LOCATION=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].location")
    logInfo "  Flink savepoint: $FLINK_SAVEPOINT_NAME, JID: $FLINK_SAVEPOINT_JID, STATE: $FLINK_SAVEPOINT_STATE, Location: $FLINK_SAVEPOINT_LOCATION"
    logInfo "  Copying the savepoint to ${BACKUP_DIR}/flink/${FLINK_SAVEPOINT_LOCATION}..."
    oc cp --container management ${MANAGEMENT_POD}:${FLINK_SAVEPOINT_LOCATION} ${BACKUP_DIR}/flink${FLINK_SAVEPOINT_LOCATION}
  done
  echo
fi

# Create ES/OS snapshots
if [[ $CP4BA_VERSION =~ "21.0.3" ]]; then
  # ElasticSearch
  logInfo "Declaring the location of the snapshot repository for ElasticSearch..."
  ELASTICSEARCH_ROUTE=$(oc get route iaf-system-es -o jsonpath='{.spec.host}')
  ELASTICSEARCH_PASSWORD=$(oc get secret iaf-system-elasticsearch-es-default-user --no-headers --ignore-not-found -o jsonpath={.data.password} | base64 -d)
  if $useTokenForElasticsearchRoute; then
    curl -skl --header "Authorization: ${cp4batoken}" -u elasticsearch-admin:$ELASTICSEARCH_PASSWORD -XPUT "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}" --resolve "${barTokenResolveCp4ba}" -H "Content-Type: application/json" -d'{"type":"fs","settings":{"location": "/usr/share/elasticsearch/snapshots/main","compress": true}}'
  else
    curl -skl -u elasticsearch-admin:$ELASTICSEARCH_PASSWORD -XPUT "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}" -H "Content-Type: application/json" -d'{"type":"fs","settings":{"location": "/usr/share/elasticsearch/snapshots/main","compress": true}}'
  fi
  # TODO: Test if we would be able to call the APIs from within the pod
  # oc exec --container elasticsearch iaf-system-elasticsearch-es-data-0 -it -- bash -c "curl -skl -u elasticsearch-admin:$ELASTICSEARCH_PASSWORD -XPUT \"localhost:${ELASTIC_CLIENT_PORT}/_snapshot/${DATETIMESTR}\" -H \"Content-Type: application/json\" -d'{\"type\":\"fs\",\"settings\":{\"location\": \"/usr/share/elasticsearch/snapshots/main\",\"compress\": true}}'"
  logInfo "Creating snapshot backup_${DATETIMESTR}..."
  if $useTokenForElasticsearchRoute; then
    SNAPSHOT_RESULT=$(curl -skL --header "Authorization: ${cp4batoken}" -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -XPUT "https://${ELASTICSEARCH_ROUTE}/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?wait_for_completion=true&pretty=true" --resolve "${barTokenResolveCp4ba}")
  else
    SNAPSHOT_RESULT=$(curl -skL -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -XPUT "https://${ELASTICSEARCH_ROUTE}/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?wait_for_completion=true&pretty=true")
  fi
  SNAPSHOT_STATE=$(echo $SNAPSHOT_RESULT | jq -r ".snapshot.state")
  checkResult $SNAPSHOT_STATE "SUCCESS" "Snapshot state"
  
  # Snapshots are kept in the pod in directory /usr/share/elasticsearch/snapshots/main
  oc exec --container elasticsearch iaf-system-elasticsearch-es-data-0 -it -- bash -c "tar -cf /usr/share/elasticsearch/es_snapshots_main_backup_${DATETIMESTR}.tgz /usr/share/elasticsearch/snapshots/main"
  oc cp --container elasticsearch iaf-system-elasticsearch-es-data-0:/usr/share/elasticsearch/es_snapshots_main_backup_${DATETIMESTR}.tgz ${BACKUP_DIR}/es_snapshots_main_backup_${DATETIMESTR}.tgz

  # check if backup was taken successfully
  if [ -e "${BACKUP_DIR}/es_snapshots_main_backup_${DATETIMESTR}.tgz" ]; then
    logInfo "Elasticsearch backup completed successfully."
    # Clean up, delete the tar, the snapshot and the repository
    oc exec --container elasticsearch iaf-system-elasticsearch-es-data-0 -it -- bash -c "rm -f /usr/share/elasticsearch/es_snapshots_main_backup_${DATETIMESTR}.tgz"
    if $useTokenForElasticsearchRoute; then
      curl -skL --header "Authorization: ${cp4batoken}" -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -X DELETE "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?pretty" --resolve "${barTokenResolveCp4ba}"
      curl -skL --header "Authorization: ${cp4batoken}" -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -X DELETE "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}?pretty" --resolve "${barTokenResolveCp4ba}"
    else
      curl -skL -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -X DELETE "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?pretty"
      curl -skL -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -X DELETE "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}?pretty"
    fi
  else
    logError "Elasticsearch backup failed, check the logs!"
    echo
    exit 1
  fi
  echo
else # 24.0 and greater
  # OpenSearch for 24.0 and later
  logInfo "Declaring the location of the snapshot repository for OpenSearch..."
  OPENSEARCH_ROUTE=$(oc get route opensearch-route -o jsonpath='{.spec.host}')
  OPENSEARCH_PASSWORD=$(oc get secret opensearch-ibm-elasticsearch-cred-secret --no-headers --ignore-not-found -o jsonpath={.data.elastic} | base64 -d)
  # TODO: Curl might need an authoriziation token
  curl -skl -u elastic:$OPENSEARCH_PASSWORD -XPUT "https://$OPENSEARCH_ROUTE/_snapshot/${DATETIMESTR}" -H "Content-Type: application/json" -d'{"type":"fs","settings":{"location": "/workdir/snapshot_storage","compress": true}}'
  logInfo "Creating snapshot backup_${DATETIMESTR}..."
  # TODO: Curl might need an authoriziation token
  SNAPSHOT_RESULT=$(curl -skL -u elastic:${OPENSEARCH_PASSWORD} -XPUT "https://${OPENSEARCH_ROUTE}/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?wait_for_completion=true&pretty=true")
  SNAPSHOT_STATE=$(echo $SNAPSHOT_RESULT | jq -r ".snapshot.state")
  checkResult $SNAPSHOT_STATE "SUCCESS" "Snapshot state"
  echo
  # TODO: copy the snapshots from the pod, what should be copied ? Need clarification from document, Zhong Tao opened a case for this issue: https://jsw.ibm.com/browse/DBACLD-164204: Need clarification on how to copy ES/OS snapshots to another environment
  # TODO: scale down os pods
fi



##### Final scale down ##############################################################
## Remove flink job submitters
if [[ "$MANAGEMENT_POD" != "" ]]; then
  logInfo "Removing flink job submitters..."
  logInfo $(oc get jobs -o custom-columns=NAME:.metadata.name | grep bai- | grep -v bai-setup | xargs oc delete job)
  echo
fi

# Set replica size of the bts-316 deployment to 0 to prevent it gets scaled up again
logInfo "Patching cp4ba-bts..."
logInfo $(oc patch bts cp4ba-bts --type merge --patch '{"spec":{"replicas":0}}')
echo

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
kafkaIsSTS=false
kafkaReplicas=0
zookeeperIsSTS=false
zookeeperReplicas=0
logInfo "statefulSets =" $statefulSets
for s in $statefulSets; do
  if [[ "$s" == "statefulset.apps/iaf-system-kafka" ]]; then
    kafkaReplicas=$(oc get $s -o 'custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas' --no-headers --ignore-not-found | awk '{print $2}')
    sed -i.bak "s|§cp4baKafkaReplicaSize|$kafkaReplicas|g" $propertiesfile
    kafkaIsSTS=true
  elif [[ "$s" == "statefulset.apps/iaf-system-zookeeper" ]]; then
    zookeeperReplicas=$(oc get $s -o 'custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas' --no-headers --ignore-not-found | awk '{print $2}')
    sed -i.bak "s|§cp4baZookeeperReplicaSize|$zookeeperReplicas|g" $propertiesfile
    zookeeperIsSTS=true
  fi
  logInfo "Scaling stateful set =" $s
  logInfo $(oc scale $s --replicas=0)
done
echo

# Delete all remaing running pods that we know
logInfo "Deleting all remaing running CP4BA pods..."
if [[ "$kafkaIsSTS" = "false" ]]; then
  kafkapods=$(oc get pod -l=app.kubernetes.io/name=kafka --no-headers --ignore-not-found | awk '{print $1}')
  for pod in ${kafkapods[*]}
  do
    logInfo $(oc delete pod $pod)
  done
  sleep 10
fi

if [[ "$zookeeperIsSTS" = "false" ]]; then
  zookeeperpods=$(oc get pod -l=app.kubernetes.io/name=zookeeper --no-headers --ignore-not-found | awk '{print $1}')
  for pod in ${zookeeperpods[*]}
  do
    logInfo $(oc delete pod $pod)
  done
  sleep 10
fi

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

# Delete all completed pods
logInfo "Deleting completed pods..."
completedpods=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase' --no-headers --ignore-not-found | grep 'Succeeded' | awk '{print $1}')
logInfo "completed pods = " $completedpods
for i in $completedpods; do
   logInfo "deleting pod =" $i;
   logInfo $(oc delete pod $i)
done
echo

# Wait till all pods are gone
allpods=$(oc get pod --no-headers)
if [[ $allpods != "" ]]; then
  logInfo "Waiting till all pods in project $cp4baProjectName are gone before taking full backup. This would run forever, so please manually check the remaining pods and get them removed manually if needed."
  logInfo "Currently there are the following pods remaining:"
  logInfo $allpods
  GONE=false
  echo -n "  Waiting..."
  while [[ $GONE == false ]]
  do
    if [[ $allpods != "" ]]; then
      echo -n "."
      sleep 10
      allpods=$(oc get pod --no-headers)
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
logInfo "Creating 025-backup-pvs.sh..."
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
  fi
done
echo



##### Clean up ###########################################
rm ${CUR_DIR}/mongodb-backup-deployment.yaml
rm ${CUR_DIR}/mongodb-backup-deployment.yaml.bak
rm ${CUR_DIR}/mongodb-backup-pvc.yaml
rm ${CUR_DIR}/mongodb-backup-pvc.yaml.bak
rm ${CUR_DIR}/zen4-br-scripts.yaml
rm ${CUR_DIR}/zen4-br-scripts.yaml.bak
rm ${CUR_DIR}/zen4-rolebinding.yaml
rm ${CUR_DIR}/zen4-rolebinding.yaml.bak
rm ${CUR_DIR}/zen4-role.yaml
rm ${CUR_DIR}/zen4-role.yaml.bak
rm ${CUR_DIR}/zen4-sa.yaml
rm ${CUR_DIR}/zen4-sa.yaml.bak
rm ${CUR_DIR}/zen-backup-deployment.yaml
rm ${CUR_DIR}/zen-backup-deployment.yaml.bak
rm ${CUR_DIR}/zen-backup-pvc.yaml
rm ${CUR_DIR}/zen-backup-pvc.yaml.bak
rm $propertiesfile.bak



##### Finally... ###########################################
logInfo "Environment is scaled down, all resources are backed up. Next, please back up:"
logInfo "  - the content of the PVs (by running the just generated script $BACKUP_DIR/025-backup-pvs.sh on the storage server using the root account)"
logInfo "  - the databases"
logInfo "  - the binary document data of CPE"
echo
