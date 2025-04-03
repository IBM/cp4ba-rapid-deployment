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

# This script is for preparing the Restore (BAR) process, creating the cp4ba namespace,
# restoring the persistent volumes and persistent volume claims, and creating the secrets.
#    Only tested with CP4BA version: 21.0.3 IF034, dedicated common services set-up

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
  echo "Please install jq to continue."
  exit 1
fi

# Check if yq is installed
type yq > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo "Please install yq (https://github.com/mikefarah/yq/releases) to continue."
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
logInfo "Current Project now is " $(oc project -q)

BACKUP_DIR=$(oc get cm cp4ba-backup-and-restore -n ${cp4baProjectName} -o 'jsonpath={.data.backup-dir}' --ignore-not-found)

if [[ -z $BACKUP_DIR ]]; then
   logError "Could not find configmap cp4ba-backup-and-restore."
   exit 1
fi

if [[ ! -d $BACKUP_DIR ]]; then
   logError "Backup Directory does not exist: $BACKUP_DIR"
   exit 1
fi

BACKUP_ROOT_DIRECTORY_FULL=$(dirname $BACKUP_DIR)

if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo 
else
   # I think that cannot happen, but ok.
   logError "Backup Directory ${cp4baProjectName} does not exist"
   exit 1
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/postDeploy_$(date +'%Y%m%d_%H%M%S').log"
logInfo "Details will be logged to $LOG_FILE."
echo

logInfo "postDeploy will use backup directory $BACKUP_DIR"


function bts-cnpg() {
  local bts_deployment_name=ibm-bts-cp4ba-bts-316-deployment
  local cnpg_cluster_name=ibm-bts-cnpg-ibm-cp4ba-dev-cp4ba-bts

  logInfo "Executing BTS CNPG Post Deployment"

  logInfo "Shutting down BTS Operator..."
  oc scale deploy ibm-bts-operator-controller-manager --replicas=0 -n ${cp4baProjectName}
  sleep 5
  echo

  logInfo "Determing current number of BTS replicas..."
  local btsReplicas=$(oc get deploy $bts_deployment_name -o 'jsonpath={.spec.replicas}')
  logInfo "BTS currently scaled to $btsReplicas -- scaling it down to zero..."
  oc scale deploy $bts_deployment_name -n ${cp4baProjectName} --replicas=0
  sleep 10

  logInfo "Determining Postgres Cluster Health..."
  local cnpgHealth=$(oc get cluster $cnpg_cluster_name -o 'jsonpath={.status.phase}')

  if [[ $cnpgHealth != "Cluster in healthy state" ]]; then
    logError "BTS CNPG Cluster unhealthy: $cnpgHealth"
  else
    logInfo "Postgres Cluster is healthy."
    echo 
    local pgPrimary=$(oc get cluster ibm-bts-cnpg-ibm-cp4ba-dev-cp4ba-bts -o jsonpath={.status.targetPrimary})
    logInfo "Primary Postgres Pod is currently: $pgPrimary"
    echo

    logInfo "Copying Backup into Postgres Pod..."
    oc cp $BACKUP_DIR/postgresql/backup_btsdb.sql $pgPrimary:/var/lib/postgresql/data/backup_btsdb.sql -c postgres

    logInfo "Restoring Database Backup..."
    oc exec $pgPrimary -- psql -U postgres -f /var/lib/postgresql/data/backup_btsdb.sql -L /var/lib/postgresql/data/restore_btsdb.log -a >> $LOG_FILE 2>&1
    oc cp $pgPrimary:/var/lib/postgresql/data/restore_btsdb.log restore_btsdb.log
    oc exec $pgPrimary -- rm -f /var/lib/postgresql/data/restore_btsdb.log /var/lib/postgresql/data/backup_btsdb.sql
  fi
  
  logInfo "Scaling up BTS again"
  oc scale deploy $bts_deployment_name -n ${cp4baProjectName} --replicas=$btsReplicas
  sleep 5

  logInfo "Scaling up BTS Operator again"
  oc scale deploy ibm-bts-operator-controller-manager --replicas=1
}


postDeployTerminating=No

while [[ $postDeployTerminating == "No" ]]; do

  echo 
  echo ================================================
  echo "Select Post Deploy task to execute"
  echo "1: BTS Cloud Native Postgres Database restore"
  echo
  echo "99: Terminate Post Deploy Script"
  echo 
  read -p "Please Provide selection: " choice

  case "$choice" in
    1)  bts-cnpg ;;
    99) postDeployTerminating=Yes ;;
  esac
done

logInfo "Have a nice day"
