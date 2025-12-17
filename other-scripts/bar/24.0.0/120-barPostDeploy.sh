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

# This script is for finalizing the Restore (BAR) process, applying the BTS postgres license fix,
# restoring the BTS data, restoring mongo db data and restoring zen services data.
#    Only tested with CP4BA version: 21.0.3 IF029 and IF039, dedicated common services set-up

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import common utilities
source ${CUR_DIR}/common.sh

LOG_FILE="/dev/null"

INPUT_PROPS_FILENAME="001-barParameters.sh"
INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${INPUT_PROPS_FILENAME}"

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${INPUT_PROPS_FILENAME}. Reading in variables from that script."
   
   . $INPUT_PROPS_FILENAME_FULL
   
   if [ "$cp4baProjectName" == "REQUIRED" ] || [ "$barTokenUser" == "REQUIRED" ] || [ "$barTokenPass" == "REQUIRED" ] || [ "$barTokenResolveCp4ba" == "REQUIRED" ] || [ "$barCp4baHost" == "REQUIRED" ]; then
      echo "File ${INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 1
   fi

   echo "Done!"
   echo
else
   echo
   echo "File ${INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 1
fi

##### Preparation ##############################################################

# Check if jq is installed
type jq > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo
  echo "Please install jq to continue."
  echo
  exit 1
fi

# Check if yq is installed
type yq > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo
  echo "Please install yq (https://github.com/mikefarah/yq/releases) to continue."
  echo
  exit 1
fi

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

logInfo "postDeploy will use project/namespace ${cp4baProjectName}"
oc project ${cp4baProjectName} > /dev/null
logInfo "Current Project now is" $(oc project -q)

BACKUP_DIR=$(oc get cm cp4ba-backup-and-restore -n ${cp4baProjectName} -o 'jsonpath={.data.backup-dir}' --ignore-not-found)

if [[ -z $BACKUP_DIR ]]; then
   logError "Could not find configmap cp4ba-backup-and-restore."
   echo
   exit 1
fi

if [[ ! -d $BACKUP_DIR ]]; then
   logError "Backup Directory does not exist: $BACKUP_DIR"
   echo
   exit 1
fi

BACKUP_ROOT_DIRECTORY_FULL=$(dirname $BACKUP_DIR)

if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo 
else
   logError "Backup Directory ${cp4baProjectName} does not exist"
   echo
   exit 1
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/PostDeploy_$(date +'%Y%m%d_%H%M%S').log"
logInfo "Details will be logged to $LOG_FILE."
echo

logInfo "postDeploy will use backup directory $BACKUP_DIR"

# Find name of deployment
if [[ -d $BACKUP_DIR/icp4acluster.icp4a.ibm.com ]]; then
  if [[ $(ls -A $BACKUP_DIR/icp4acluster.icp4a.ibm.com | wc -l) -eq 1 ]]; then
    CR_SPEC=$BACKUP_DIR/icp4acluster.icp4a.ibm.com/$(ls -A $BACKUP_DIR/icp4acluster.icp4a.ibm.com)
  else
    logError "No or too many CRs found in backup. Exiting..."
    echo
    exit 1
  fi 
else
  logError "CR not found in backup. Exiting..."
  echo
  exit 1
fi

backupDeploymentName=$(yq eval '.metadata.name' $CR_SPEC)


function bts-cnpg() {
  local bts_deployment_name=ibm-bts-cp4ba-bts-316-deployment
  local cnpg_cluster_name=ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts

  local btsServicesStatus=$(oc get businessteamsservices cp4ba-bts -o jsonpath={.status.serviceStatus})
  local btsDeployStatus=$(oc get businessteamsservices cp4ba-bts -o jsonpath={.status.deployStatus})

  logInfo "BTS Deploy Status: $btsDeployStatus"
  logInfo "BTS Services Status: $btsServicesStatus"
  if [[ "$btsDeployStatus" != "ready" ]]; then 
    logInfo "BTS Deploy Status not ready, postgres database restore cannot be applied yet"
    return
  fi
  if [[ "$btsServicesStatus" != "ready" ]]; then
    logInfo "BTS Services Status not ready, postgres database restore cannot be applied yet"
    return
  fi

  logInfo "Executing BTS CNPG Database Restore"

  logInfo "Shutting down BTS Operator..."
  logInfo $(oc scale deploy ibm-bts-operator-controller-manager --replicas=0 -n ${cp4baProjectName})
  sleep 5
  echo

  logInfo "Determining current number of BTS replicas and scale it down..."
  local btsReplicaSize=$(oc get bts cp4ba-bts -o jsonpath={.spec.replicas})
  
  local btsReplicas=$(oc get deploy $bts_deployment_name -o 'jsonpath={.spec.replicas}')
  logInfo "BTS desired replicas $btsReplicaSize currently scaled to $btsReplicas -- scaling it down to zero..."
  logInfo $(oc patch bts cp4ba-bts --type merge --patch '{"spec":{"replicas":0}}')
  logInfo $(oc scale deploy $bts_deployment_name -n ${cp4baProjectName} --replicas=0)

  echo
  logInfo "Wait 10 seconds"
  sleep 10

  logInfo "Determining Postgres Cluster Health..."
  local cnpgHealth=$(oc get cluster $cnpg_cluster_name -o 'jsonpath={.status.phase}')

  if [[ $cnpgHealth != "Cluster in healthy state" ]]; then
    logError "BTS CNPG Cluster unhealthy: $cnpgHealth"
  else
    logInfo "Postgres Cluster is healthy."
    echo 
    local pgPrimary=$(oc get cluster $cnpg_cluster_name -o jsonpath={.status.targetPrimary})
    logInfo "Primary Postgres Pod is currently: $pgPrimary"
    echo

    logInfo "Copying Backup into Postgres Pod..."
    oc cp $BACKUP_DIR/postgresql/backup_btsdb.sql $pgPrimary:/var/lib/postgresql/data/backup_btsdb.sql -c postgres

    logInfo "Restoring Database Backup..."
    oc exec $pgPrimary -c postgres -- psql -U postgres -f /var/lib/postgresql/data/backup_btsdb.sql -L /var/lib/postgresql/data/restore_btsdb.log -a >> $LOG_FILE 2>&1
    logInfo $(oc cp $pgPrimary:/var/lib/postgresql/data/restore_btsdb.log $BACKUP_DIR/restore_btsdb.log -c postgres)
    oc exec $pgPrimary -c postgres -- rm -f /var/lib/postgresql/data/restore_btsdb.log /var/lib/postgresql/data/backup_btsdb.sql
  fi

  echo
  logInfo "Scaling up BTS again"
  local btsScaleSpec=$(printf '{"spec":{"replicas":%s}}' $btsReplicaSize)
  logInfo $(oc patch bts cp4ba-bts --type merge --patch $btsScaleSpec)
  logInfo $(oc scale deploy $bts_deployment_name -n ${cp4baProjectName} --replicas=$btsReplicas)
  sleep 5
  echo
  
  logInfo "Scaling up BTS Operator again"
  logInfo $(oc scale deploy ibm-bts-operator-controller-manager --replicas=1)

  echo
  logInfo "Waiting up to 60 seconds for BTS Operator to come up and update service status"
  logInfo $(oc wait --for=jsonpath={.status.serviceStatus}=unready businessteamsservices/cp4ba-bts --timeout=60s)

  waitServiceReady=10
  while [ $waitServiceReady -gt 0 ]; do
    btsServicesStatus=$(oc get businessteamsservices cp4ba-bts -o jsonpath={.status.serviceStatus})
    if [ "$btsServicesStatus" == "ready" ]; then
      logInfo "BTS Service Status: $btsServicesStatus"
      waitServiceReady=0
    else
      waitServiceReady=$((waitServiceReady - 1))
      if [ $waitServiceReady -gt 0 ]; then
        logInfo "BTS Service Status: $btsServicesStatus -- waiting up to 60 seconds for an update..."
	oc wait --for=jsonpath={.status.serviceStatus}=ready businessteamsservices/cp4ba-bts --timeout=60s >> $LOG_FILE 2>&1
      else
	      logInfo "BTS Service did not reach ready state, at least not yet"
      fi
    fi
  done
}


function zen-restore() {
  local zen_edb_cluster_name="zen-metastore-edb"
  logInfo "Determining Postgres Cluster Health..."
  local zen_edb_health=$(oc get cluster $zen_edb_cluster_name -o 'jsonpath={.status.phase}')

  if [[ $zen_edb_health != "Cluster in healthy state" ]]; then
    logError "Zen Metastore EDB Cluster unhealthy: $zen_edb_health"
  else
    logInfo "Postgres Cluster is healthy."
    echo 
    local zenPrimary=$(oc get cluster $zen_edb_cluster_name -o jsonpath={.status.targetPrimary})
    logInfo "Primary Postgres Pod is currently: $zenPrimary"
    echo
    
    ## Need to add this line at the top of backup_zendb.sql, this is to terminate all connections to db before restoring the data
    ## "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'zen' AND pid <> pg_backend_pid();"   
    sed -i "18i SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'zen' AND pid <> pg_backend_pid();" ${BACKUP_DIR}/postgresql/backup_zendb.sql

    logInfo "Copying Backup into Postgres Pod..."
    oc cp $BACKUP_DIR/postgresql/backup_zendb.sql $zenPrimary:/var/lib/postgresql/data/backup_zendb.sql -c postgres
    
    logInfo "Restoring Database Backup..."
    oc exec $zenPrimary -c postgres -- psql -U postgres -f /var/lib/postgresql/data/backup_zendb.sql -L /var/lib/postgresql/data/restore_zendb.log -a >> $LOG_FILE 2>&1
    logInfo $(oc cp $zenPrimary:/var/lib/postgresql/data/restore_zendb.log $BACKUP_DIR/restore_zendb.log -c postgres)
    oc exec $zenPrimary -c postgres -- rm -f /var/lib/postgresql/data/restore_zendb.log /var/lib/postgresql/data/backup_zendb.sql

  fi

}


function cs-restore() {
  local cs_cluster_name="common-service-db"
  logInfo "Determining Postgres Cluster Health..."
  local cs_health=$(oc get cluster $cs_cluster_name -o 'jsonpath={.status.phase}')

  if [[ $cs_health != "Cluster in healthy state" ]]; then
    logError "Common Service DB Cluster unhealthy: $cs_health"
  else
    logInfo "Postgres Cluster is healthy."
    echo 
    local csPrimary=$(oc get cluster $cs_cluster_name -o jsonpath={.status.targetPrimary})
    logInfo "Primary Postgres Pod is currently: $csPrimary"
    echo
    
    ## Need to add this line at the top of backup_csimdb.sql, this is to terminate all connections to db before restoring the data
    ## "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'im' AND pid <> pg_backend_pid();"
    sed -i "18i SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'im' AND pid <> pg_backend_pid();" ${BACKUP_DIR}/postgresql/backup_csimdb.sql

    logInfo "Copying Backup into Postgres Pod..."
    oc cp $BACKUP_DIR/postgresql/backup_csimdb.sql $csPrimary:/var/lib/postgresql/data/backup_csimdb.sql -c postgres

    logInfo "Restoring Database Backup..."
    oc exec $csPrimary -c postgres -- psql -U postgres -f /var/lib/postgresql/data/backup_csimdb.sql -L /var/lib/postgresql/data/restore_csimdb.log -a >> $LOG_FILE 2>&1
    logInfo $(oc cp $csPrimary:/var/lib/postgresql/data/restore_csimdb.log $BACKUP_DIR/restore_csimdb.log -c postgres)
    oc exec $csPrimary -c postgres -- rm -f /var/lib/postgresql/data/restore_csimdb.log /var/lib/postgresql/data/backup_csimdb.sql
  fi

}

function restart-common-services() {
    logInfo "Restarting the Platform Auth Service pods"
    logInfo $(oc delete pod -l app=platform-auth-service -n $cp4baProjectName)
    logInfo "Restarting the Platform Identity Management pods"
    logInfo $(oc delete pod -l app=platform-identity-management -n $cp4baProjectName)
    logInfo "Restarting the Platform Identity Provider pods"
    logInfo $(oc delete pod -l app=platform-identity-provider -n $cp4baProjectName)
    logInfo "Restarting user management pods"
    logInfo $(oc delete pod -l component=usermgmt -n $cp4baProjectName)
    logInfo "Restarting common-web-ui pods"
    logInfo $(oc delete pod -l app.kubernetes.io/name=common-web-ui -n $cp4baProjectName)
    logInfo "Restarting zen core api pods"
    logInfo $(oc delete pod -l component=zen-core-api -n $cp4baProjectName)
    logInfo "Restarting zen core pods"
    logInfo $(oc delete pod -l component=zen-core -n $cp4baProjectName)
    logInfo "Restarting zen audit pods"
    logInfo $(oc delete pod -l component=zen-audit -n $cp4baProjectName)
    logInfo "Restarting nginx pods"
    logInfo $(oc delete pod -l component=ibm-nginx -n $cp4baProjectName)
    # Restart CPE & Navigator Pods
    for pod_pattern in "cpe-deploy" "cpe-watcher" "navigator-deploy" "navigator-watcher"; do
      pods=$(oc get pods -n $cp4baProjectName --no-headers | awk -v pattern="$pod_pattern" '$1 ~ pattern {print $1}')
      if [ -n "$pods" ]; then
        logInfo "Restarting $pod_pattern pods: $pods"
        logInfo $(oc delete pod -n $cp4baProjectName $pods)
        sleep 30
        # Wait for new pods matching the pattern to be ready
        logInfo "Waiting for new $pod_pattern pods to be ready..."
        logInfo $(oc get pods -n $cp4baProjectName --no-headers | grep -i "$pod_pattern")
        new_pods=$(oc get pods -n $cp4baProjectName --no-headers | awk -v pattern="$pod_pattern" '$1 ~ pattern {print $1}')
        if [ -n "$new_pods" ]; then
          all_pods_ready=true
          for pod in $new_pods; do
            if oc wait pod/$pod -n $cp4baProjectName --for=condition=Ready --timeout=180s 2>&1; then
              logInfo "Pod $pod is ready"
            else
              logError "Pod $pod failed to become ready or timed out"
              all_pods_ready=false
            fi
          done
          
          if [ "$all_pods_ready" = true ]; then
            logInfo "$pod_pattern pods are ready"
          else
            logError "$pod_pattern pods - some pods failed to become ready"
          fi
        fi
      else
        logInfo "No $pod_pattern pods found — nothing to restart"
      fi
    done
}

postDeployTerminating=No

while [[ $postDeployTerminating == "No" ]]; do

  echo 
  echo ========================================================
  echo "Select Post Deploy task to execute:"
  echo "   1: Zen Metastore EDB Postgres Database restore"
  echo "   2: BTS Cloud Native Postgres Database restore"
  echo "   3: Restart Common Services (Mandatory)"
  echo
  echo "  99: Terminate Post Deploy Script"
  echo 
  read -p "Please provide selection: " choice
  echo

  case "$choice" in
    1)  zen-restore ;;
    2)  bts-cnpg ;;
    3)  restart-common-services ;;
    99) postDeployTerminating=Yes ;;
  esac
done

logInfo "Have a nice day"
echo
