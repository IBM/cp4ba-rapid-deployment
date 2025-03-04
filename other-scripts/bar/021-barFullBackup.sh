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

# This script is for performing a full backup of the given namespace, it backs up all resources in the namespace.
#    Only tested with CP4BA version: 21.0.3 IF034, dedicated common services set-up

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
echo

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   echo "Found ${INPUT_PROPS_FILENAME}. Reading in variables from that script."
   
   . $INPUT_PROPS_FILENAME_FULL
   
   if [ $cp4baProjectName == "REQUIRED" ]; then
      echo "File ${INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 1
   fi

   echo "Done!"
else
   echo "File ${INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 1
fi
echo

echo -e "\x1B[1mThis script will backup the CP4BA environment deployed in ${cp4baProjectName}.\n \x1B[0m"

printf "Do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
   echo
   echo -e "Backing up CP4BA deployment in namespace ${cp4baProjectName}..."
   ;;
*)
   echo
   echo -e "Exiting..."
   echo
   exit 0
   ;;
esac

BACKUP_ROOT_DIRECTORY_FULL="${CUR_DIR}/${cp4baProjectName}"
if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo
else
   echo
   mkdir -p $BACKUP_ROOT_DIRECTORY_FULL
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/Backup_${DATETIMESTR}.log"
logInfo "Details will be logged to $LOG_FILE."
echo



##### Preparation ##############################################################
# Verify OCP Connecction
logInfo "Verifying OC CLI is connected to the OCP cluster..."
WHOAMI=$(oc whoami)
logInfo "WHOAMI =" $WHOAMI

if [[ "$WHOAMI" == "" ]]; then
   logError "OC CLI is NOT connected to the OCP cluster. Please log in first with an admin user to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
   echo
   exit 1
fi
echo

# switch to CP4BA project
project=$(oc project --short)
logInfo "project =" $project
if [[ "$project" != "$cp4baProjectName" ]]; then
   logInfo "Switching to project ${cp4baProjectName}..."
   logInfo $(oc project $cp4baProjectName)
fi
echo

# Create backup directory
logInfo "Creating backup directory..."
BACKUP_DIR=$BACKUP_ROOT_DIRECTORY_FULL/backup_${DATETIMESTR}
mkdir -p $BACKUP_DIR

# Get CP4BA depoyment name
CP4BA_NAME=$(oc get ICP4ACluster -o name |cut -d "/" -f 2)
logInfo "CP4BA deployment name: $CP4BA_NAME"

# Get CP4BA version
CP4BA_VERSION=$(oc get ICP4ACluster $CP4BA_NAME -o 'custom-columns=NAME:.metadata.name,VERSION:.spec.appVersion' --no-headers | awk '{print $2}')
logInfo "Found CP4BA version: $CP4BA_VERSION"
echo

##### Backup uid definition ####################################################
NAMESPACE_UID=$(oc describe project $cp4baProjectName | grep uid-range | cut -d"=" -f2 | cut -d"/" -f1)
logInfo "Namespace $cp4baProjectName uid: $NAMESPACE_UID"
echo $NAMESPACE_UID > ${BACKUP_DIR}/namespace_uid

##### Backup BTS PostgreSQL Database ###########################################
btscnpgpods=$(oc get pod -l=app.kubernetes.io/name=ibm-bts-cp4ba-bts --no-headers --ignore-not-found | awk '{print $1}')
for pod in ${btscnpgpods[*]}
do
  if [[ "$pod" = "ibm-bts-cnpg-"$cp4baProjectName"-cp4ba-bts-1" ]]; then
    logInfo "Backing up BTS PostgreSQL Database..."
    oc exec --container postgres ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts-1 -it -- bash -c "pg_dump -d BTSDB -U postgres -Fp -c -C --if-exists  -f /var/lib/postgresql/data/backup_btsdb.sql"
    oc cp --container postgres ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts-1:/var/lib/postgresql/data/backup_btsdb.sql ${BACKUP_DIR}/postgresql/backup_btsdb.sql
    oc exec --container postgres ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts-1 -it -- bash -c "rm -f /var/lib/postgresql/data/backup_btsdb.sql"
    
    # After the backup, we also can delete this pod
    logInfo "Scaling down last BTS PostgreSQL Database pod..."
    logInfo $(oc delete pod "ibm-bts-cnpg-"$cp4baProjectName"-cp4ba-bts-1")
    echo
  fi
done

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
  FLINK_SAVEPOINT_RESULTS=$(curl -X POST -sk -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} "${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints?cancel-job=true")
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
  
  # Remove the Flink job submitters
  logInfo "Removing flink job submitters..."
  oc get jobs -o custom-columns=NAME:.metadata.name | grep bai- | grep -v bai-setup | xargs oc delete job
  echo
  
  # After the backup, we also can delete these pods
  logInfo "Scaling down insights-engine pods..."
  logInfo $(oc scale deployment.apps/iaf-insights-engine-management --replicas=0);
  sleep 5
  sts=$(oc get statefulset.apps/iaf-system-kafka -o name --ignore-not-found)
  if [[ "$sts" = "" ]]; then
    logInfo $(oc delete pod iaf-system-kafka-0)
  else
    logInfo $(oc scale statefulset.apps/iaf-system-kafka --replicas=0);
  fi
  sleep 5
  sts=$(oc get statefulset.apps/iaf-system-zookeeper -o name --ignore-not-found)
  if [[ "$sts" = "" ]]; then
    logInfo $(oc delete pod iaf-system-zookeeper-0)
  else
    logInfo $(oc scale statefulset.apps/iaf-system-zookeeper --replicas=0);
  fi
  echo
  sleep 5
fi

# Create ES/OS snapshots
if [[ $CP4BA_VERSION =~ "24.0" ]]; then
  # OpenSearch for 24.0 and later
  logInfo "Declaring the location of the snapshot repository for OpenSearch..."
  OPENSEARCH_ROUTE=$(oc get route opensearch-route -o jsonpath='{.spec.host}')
  OPENSEARCH_PASSWORD=$(oc get secret opensearch-ibm-elasticsearch-cred-secret --no-headers --ignore-not-found -o jsonpath={.data.elastic} | base64 -d)
  curl -skl -u elastic:$OPENSEARCH_PASSWORD -XPUT "https://$OPENSEARCH_ROUTE/_snapshot/${DATETIMESTR}" -H "Content-Type: application/json" -d'{"type":"fs","settings":{"location": "/workdir/snapshot_storage","compress": true}}'
  logInfo "Creating snapshot backup_${DATETIMESTR}..."
  SNAPSHOT_RESULT=$(curl -skL -u elastic:${OPENSEARCH_PASSWORD} -XPUT "https://${OPENSEARCH_ROUTE}/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?wait_for_completion=true&pretty=true")
  SNAPSHOT_STATE=$(echo $SNAPSHOT_RESULT | jq -r ".snapshot.state")
  checkResult $SNAPSHOT_STATE "SUCCESS" "Snapshot state"
  echo
  # TODO: copy the snapshots from the pod, what should be copied ? Need clarification from document, Zhong Tao opened a case for this issue: https://jsw.ibm.com/browse/DBACLD-164204: Need clarification on how to copy ES/OS snapshots to another environment
  # TODO: scale down es pods
else
  # ElasticSearch
  logInfo "Declaring the location of the snapshot repository for ElasticSearch..."
  ELASTICSEARCH_ROUTE=$(oc get route iaf-system-es -o jsonpath='{.spec.host}')
  ELASTICSEARCH_PASSWORD=$(oc get secret iaf-system-elasticsearch-es-default-user --no-headers --ignore-not-found -o jsonpath={.data.password} | base64 -d)
  curl -skl -u elasticsearch-admin:$ELASTICSEARCH_PASSWORD -XPUT "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}" -H "Content-Type: application/json" -d'{"type":"fs","settings":{"location": "/usr/share/elasticsearch/snapshots/main","compress": true}}'
  # TODO: Test if we would be able to call the APIs from within the pod
  # oc exec --container elasticsearch iaf-system-elasticsearch-es-data-0 -it -- bash -c "curl -skl -u elasticsearch-admin:$ELASTICSEARCH_PASSWORD -XPUT \"localhost:${ELASTIC_CLIENT_PORT}/_snapshot/${DATETIMESTR}\" -H \"Content-Type: application/json\" -d'{\"type\":\"fs\",\"settings\":{\"location\": \"/usr/share/elasticsearch/snapshots/main\",\"compress\": true}}'"
  logInfo "Creating snapshot backup_${DATETIMESTR}..."
  SNAPSHOT_RESULT=$(curl -skL -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -XPUT "https://${ELASTICSEARCH_ROUTE}/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?wait_for_completion=true&pretty=true")
  SNAPSHOT_STATE=$(echo $SNAPSHOT_RESULT | jq -r ".snapshot.state")
  checkResult $SNAPSHOT_STATE "SUCCESS" "Snapshot state"
  echo
  
  # Snapshots are kept in the pod in directory /usr/share/elasticsearch/snapshots/main
  # TODO: Next commands produce some console output that we might want to get rid of
  oc exec --container elasticsearch iaf-system-elasticsearch-es-data-0 -it -- bash -c "tar -cvf /usr/share/elasticsearch/es_snapshots_main_backup_${DATETIMESTR}.tgz /usr/share/elasticsearch/snapshots/main"
  oc cp --container elasticsearch iaf-system-elasticsearch-es-data-0:/usr/share/elasticsearch/es_snapshots_main_backup_${DATETIMESTR}.tgz ${BACKUP_DIR}/es_snapshots_main_backup_${DATETIMESTR}.tgz
  # Delete the tar, the snapshot and the repository
  oc exec --container elasticsearch iaf-system-elasticsearch-es-data-0 -it -- bash -c "rm -f /usr/share/elasticsearch/es_snapshots_main_backup_${DATETIMESTR}.tgz"
  curl -skL -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -X DELETE "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?pretty"
  curl -skL -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -X DELETE "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}?pretty"
  
  # After the backup, we also can delete these pods
  logInfo "Scaling down es pods..."
  logInfo $(oc scale statefulset.apps/iaf-system-elasticsearch-es-data --replicas=0);
  echo
  sleep 5
fi

# TODO: We have to check if this could stay as is...we maybe want to wait here, till admin has removed the other pods, otherwise the backup will be incomplete / distributed onto multiple backups
# Wait till all pods are gone
for ((i=0; i<13; i++)); do
   remainingPods=$(oc get pods --no-headers -o name)
   if [[ $(oc get pods --no-headers -o name) = "" ]]; then
     break
   else
     if [[ $i = 12 ]]; then
       logError "Remaining pods detected. Please check. Exiting WITHOUT full backup!!!"
       echo
       exit 1
     fi
     sleep 10
   fi
done

# Now that those backups are done, and all remaining pods are gone, we can take a full backup of all resources in the namespace
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



logInfo "All resources are backed up. Next, please back up:"
logInfo "  - the databases"
logInfo "  - the content of the PVs"
logInfo "  - the binary document data of CPE"
logInfo "Once those backups are complete, pls. scale up the deployment again."
echo
