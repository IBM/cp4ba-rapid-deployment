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


function bts-license() {
  local cnpg_cluster_name=ibm-bts-cnpg-ibm-cp4ba-dev-cp4ba-bts

  local licenseValid=$(oc get cluster $cnpg_cluster_name -o jsonpath={.status.licenseStatus.valid})

  logInfo "License Status of BTS Postgres: $licenseValid"
  if [[ "$licenseValid" == "false" || "$licenseValid" == "False" ]]; then
    logInfo "Applying License Fix"
    oc annotate secret postgresql-operator-controller-manager-config  ibm-bts/skip-updates="true"
    oc get job create-postgres-license-config -o yaml | \
      sed -e 's/operator.ibm.com\/opreq-control: "true"/operator.ibm.com\/opreq-control: "false"/' \
          -e 's|\(image: \).*|\1"cp.icr.io/cp/cpd/edb-postgres-license-provider@sha256:c1670e7dd93c1e65a6659ece644e44aa5c2150809ac1089e2fd6be37dceae4ce"|' \
          -e '/controller-uid:/d' | \
    oc replace --force -f - 
    echo
    logInfo "Waiting for create-postgres-license-config job to be completed"
    oc wait --for=condition=complete job/create-postgres-license-config
    echo

    waitCounter=10
    while [ $waitCounter -gt 0 ]; do
      licenseValid=$(oc get cluster $cnpg_cluster_name -o jsonpath={.status.licenseStatus.valid})
      if [[ "$licenseValid" == "false" || "$licenseValid" == "False" ]]; then
	waitCounter=$((waitCounter - 1))
        if [ $waitCounter -gt 0 ]; then
          logInfo "License not yet valid... waiting 10 seconds"
          sleep 10
	else
          logInfo "License did not get valid..."
	  return
	fi
      else
	logInfo "License is now valid"
	waitCounter=0
      fi
    done
  fi
}

function bts-cnpg() {
  local bts_deployment_name=ibm-bts-cp4ba-bts-316-deployment
  local cnpg_cluster_name=ibm-bts-cnpg-ibm-cp4ba-dev-cp4ba-bts

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
  oc scale deploy ibm-bts-operator-controller-manager --replicas=0 -n ${cp4baProjectName}
  sleep 5
  echo

  logInfo "Determing current number of BTS replicas..."
  local btsReplicas=$(oc get deploy $bts_deployment_name -o 'jsonpath={.spec.replicas}')
  logInfo "BTS currently scaled to $btsReplicas -- scaling it down to zero..."
  oc scale deploy $bts_deployment_name -n ${cp4baProjectName} --replicas=0

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
    local pgPrimary=$(oc get cluster ibm-bts-cnpg-ibm-cp4ba-dev-cp4ba-bts -o jsonpath={.status.targetPrimary})
    logInfo "Primary Postgres Pod is currently: $pgPrimary"
    echo

    logInfo "Copying Backup into Postgres Pod..."
    oc cp $BACKUP_DIR/postgresql/backup_btsdb.sql $pgPrimary:/var/lib/postgresql/data/backup_btsdb.sql -c postgres

    logInfo "Restoring Database Backup..."
    oc exec $pgPrimary -c postgres -- psql -U postgres -f /var/lib/postgresql/data/backup_btsdb.sql -L /var/lib/postgresql/data/restore_btsdb.log -a >> $LOG_FILE 2>&1
    oc cp $pgPrimary:/var/lib/postgresql/data/restore_btsdb.log restore_btsdb.log -c postgres
    oc exec $pgPrimary -c postgres -- rm -f /var/lib/postgresql/data/restore_btsdb.log /var/lib/postgresql/data/backup_btsdb.sql
  fi

  echo
  logInfo "Scaling up BTS again"
  oc scale deploy $bts_deployment_name -n ${cp4baProjectName} --replicas=$btsReplicas
  sleep 5

  echo
  logInfo "Scaling up BTS Operator again"
  oc scale deploy ibm-bts-operator-controller-manager --replicas=1

  echo
  logInfo "Waiting up to 60 seconds for Operator to come up and update service status"
  oc wait --for=jsonpath={.status.serviceStatus}=unready businessteamsservices/cp4ba-bts --timeout=60s

  waitServiceReady=10
  while [ $waitServiceReady -gt 0 ]; do
    btsServicesStatus=$(oc get businessteamsservices cp4ba-bts -o jsonpath={.status.serviceStatus})
    if [ "$btsServicesStatus" == "ready" ]; then
      logInfo "BTS Serives Status: $btsServicesStatus"
      waitServiceReady=0
    else
      waitServiceReady=$((waitServiceReady - 1))
      if [ $waitServiceReady -gt 0 ]; then
        logInfo "BTS Serives Status: $btsServicesStatus -- waiting up to 60 seconds for an update..."
	oc wait --for=jsonpath={.status.serviceStatus}=ready businessteamsservices/cp4ba-bts --timeout=60s
      else
	logInfo "BTS Service didnt reach ready state, at least not yet"
      fi
    fi
  done
     
}


postDeployTerminating=No

while [[ $postDeployTerminating == "No" ]]; do

  echo 
  echo ================================================
  echo "Select Post Deploy task to execute"
  echo "1: BTS Postgres License Fix"
  echo "2: BTS Cloud Native Postgres Database restore"
  echo
  echo "99: Terminate Post Deploy Script"
  echo 
  read -p "Please Provide selection: " choice
  echo

  case "$choice" in
    1)  bts-license ;;
    2)  bts-cnpg ;;
    99) postDeployTerminating=Yes ;;
  esac
done

logInfo "Have a nice day"
