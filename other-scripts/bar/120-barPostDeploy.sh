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


function bts-license() {
  local cnpg_cluster_name=ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts

  local licenseValid=$(oc get cluster $cnpg_cluster_name -o jsonpath={.status.licenseStatus.valid})

  logInfo "License Status of BTS Postgres: $licenseValid"
  if [[ "$licenseValid" == "false" || "$licenseValid" == "False" ]]; then
    logInfo "Applying License Fix"
    logInfo $(oc annotate secret postgresql-operator-controller-manager-config  ibm-bts/skip-updates="true")
    logInfo $(oc get job create-postgres-license-config -o yaml | \
      sed -e 's/operator.ibm.com\/opreq-control: "true"/operator.ibm.com\/opreq-control: "false"/' \
          -e 's|\(image: \).*|\1"cp.icr.io/cp/cpd/edb-postgres-license-provider@sha256:c1670e7dd93c1e65a6659ece644e44aa5c2150809ac1089e2fd6be37dceae4ce"|' \
          -e '/controller-uid:/d' | \
      oc replace --force -f -)
    echo
    logInfo "Waiting for create-postgres-license-config job to be completed"
    logInfo $(oc wait --for=condition=complete job/create-postgres-license-config)
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

function mongoRestore()
{
  # Prime templates 
  logInfo "Priming resources to restore MongoDB"
  cp ${CUR_DIR}/templates/mongodb-backup-pvc.template.yaml ${CUR_DIR}/mongodb-backup-pvc.yaml
  cp ${CUR_DIR}/templates/mongodb-backup-deployment.template.yaml ${CUR_DIR}/mongodb-backup-deployment.yaml

  sed -i "s|§cp4baProjectNamespace|$cp4baProjectName|g; s|§pvcStorageClass|$pvcStorageClassName|g" ${CUR_DIR}/mongodb-backup-pvc.yaml
  sed -i "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/mongodb-backup-deployment.yaml

  # Create resources necessary to restore MongoDB 
  logInfo $(oc apply -f ${CUR_DIR}/mongodb-backup-pvc.yaml)
  logInfo $(oc apply -f ${CUR_DIR}/mongodb-backup-deployment.yaml)

  # Wait indefinitely for deployment to be Available (pod Ready)
  logInfo $(oc wait -f ${CUR_DIR}/mongodb-backup-deployment.yaml --for=condition=Available --timeout=-1s)
  echo

  mongodbpods=$(oc get pod -l=foundationservices.cloudpak.ibm.com=mongo-data --no-headers --ignore-not-found | awk '{print $1}' | sort)

  for pod in ${mongodbpods[*]}
  do
    logInfo "Restoring MongoDB using pod ${pod}..."
    oc cp ${BACKUP_DIR}/mongodb/mongobackup.tar $pod:/dump/mongobackup.tar
    # prep certs files that will be used to restore the backup
    oc exec $pod -it -- bash -c 'cat /cred/mongo-certs/tls.crt /cred/mongo-certs/tls.key > /work-dir/mongo.pem; cat /cred/cluster-ca/tls.crt /cred/cluster-ca/tls.key > /work-dir/ca.pem'
    # extract mongo backup
    oc exec $pod -it -- bash -c 'cd /dump && tar -xvf mongobackup.tar'
    # run the actual restore
    oc exec $pod -it -- bash -c 'mongorestore --db platform-db --host rs0/icp-mongodb-0.icp-mongodb.$NAMESPACE.svc.cluster.local,icp-mongodb-1.icp-mongodb.$NAMESPACE.svc.cluster.local,icp-mongodb-2.icp-mongodb.$NAMESPACE.svc.cluster.local --port $MONGODB_SERVICE_PORT --username $ADMIN_USER --password $ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /work-dir/ca.pem --sslPEMKeyFile /work-dir/mongo.pem /dump/dump/platform-db --drop'
    break
  done
  echo

  # Restore secrets with apikeys that are overwritten during the installation
  # This is required because these are registered in the MongoDB that has
  # just been restored. Without these cp-console route will not work.
  
  logInfo "Restoring secrets..."
  # oc delete secret ibm-iam-bindinfo-zen-serviceid-apikey-secret
  # oc apply -f ${BACKUP_DIR}/secret/ibm-iam-bindinfo-zen-serviceid-apikey-secret.yaml
  file=${BACKUP_DIR}/secret/ibm-iam-bindinfo-zen-serviceid-apikey-secret.yaml
  logInfo $(yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences)' $file | oc apply -f - -n $cp4baProjectName --overwrite=true)

  # oc delete secret zen-serviceid-apikey-secret
  # oc apply -f ${BACKUP_DIR}/secret/zen-serviceid-apikey-secret.yaml
  file=${BACKUP_DIR}/secret/zen-serviceid-apikey-secret.yaml
  logInfo $(yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences)' $file | oc apply -f - -n $cp4baProjectName --overwrite=true)

  # oc delete secret icp-serviceid-apikey-secret
  # oc apply -f ${BACKUP_DIR}/secret/icp-serviceid-apikey-secret.yaml
  file=${BACKUP_DIR}/secret/icp-serviceid-apikey-secret.yaml
  logInfo $(yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences)' $file | oc apply -f - -n $cp4baProjectName --overwrite=true)
  echo
  
  #restart pods that require restarting 
  logInfo "Restarting required pods..."
  logInfo $(oc delete pod --selector='name=ibm-iam-operator')
  logInfo $(oc delete pod --selector='app=secret-watcher')
  logInfo $(oc delete pod --selector='component=usermgmt')
  
  logInfo "Waiting till pods are back..."
  logInfo $(oc wait -f ${BACKUP_DIR}/deployment.apps/ibm-iam-operator.yaml --for=condition=Available --timeout=-1s)
  logInfo $(oc wait -f ${BACKUP_DIR}/deployment.apps/secret-watcher.yaml --for=condition=Available --timeout=-1s)
  logInfo $(oc wait -f ${BACKUP_DIR}/deployment.apps/usermgmt.yaml --for=condition=Available --timeout=-1s)
  echo
  
  # clean up
  logInfo "Cleaning up..."
  logInfo $(oc delete -f ${CUR_DIR}/mongodb-backup-deployment.yaml)
  logInfo $(oc delete -f ${CUR_DIR}/mongodb-backup-pvc.yaml)

  rm -f ${CUR_DIR}/mongodb-backup-deployment.yaml
  rm -f ${CUR_DIR}/mongodb-backup-pvc.yaml
  echo
  
  logInfo "MongoDB restore completed."
  logWarning "NEXT ACTION: You must restore Zen Services to properly access the CloudPak"
}

function restoreZen()
{
  ## Restore Zen Services Backup
  # Prime templates 
  logInfo "Priming resources to restore Zen Services"
  cp ${CUR_DIR}/templates/zen-backup-pvc.template.yaml ${CUR_DIR}/zen-backup-pvc.yaml
  cp ${CUR_DIR}/templates/zen4-br-scripts.template.yaml ${CUR_DIR}/zen4-br-scripts.yaml
  cp ${CUR_DIR}/templates/zen4-sa.template.yaml ${CUR_DIR}/zen4-sa.yaml
  cp ${CUR_DIR}/templates/zen4-role.template.yaml ${CUR_DIR}/zen4-role.yaml
  cp ${CUR_DIR}/templates/zen4-rolebinding.template.yaml ${CUR_DIR}/zen4-rolebinding.yaml
  cp ${CUR_DIR}/templates/zen-backup-deployment.template.yaml ${CUR_DIR}/zen-backup-deployment.yaml

  sed -i "s|§cp4baProjectNamespace|$cp4baProjectName|g; s|§pvcStorageClass|$pvcStorageClassName|g" ${CUR_DIR}/zen-backup-pvc.yaml
  sed -i "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen4-br-scripts.yaml
  sed -i "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen4-sa.yaml
  sed -i "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen4-role.yaml
  sed -i "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen4-rolebinding.yaml
  sed -i "s|§cp4baProjectNamespace|$cp4baProjectName|g" ${CUR_DIR}/zen-backup-deployment.yaml

  # Create resources necessary to restore Zen Services
  logInfo $(oc apply -f ${CUR_DIR}/zen-backup-pvc.yaml)
  logInfo $(oc apply -f ${CUR_DIR}/zen4-br-scripts.yaml)
  logInfo $(oc apply -f ${CUR_DIR}/zen4-sa.yaml)
  logInfo $(oc apply -f ${CUR_DIR}/zen4-role.yaml)
  logInfo $(oc apply -f ${CUR_DIR}/zen4-rolebinding.yaml)
  logInfo $(oc apply -f ${CUR_DIR}/zen-backup-deployment.yaml)

  # Wait indefinitely for deployment to be Available (pod Ready)
  logInfo $(oc wait -f ${CUR_DIR}/zen-backup-deployment.yaml --for=condition=Available --timeout=-1s)
  echo
  
  # Grab the values from the new cpd-oidcclient-secret and update zenbackup data with it
  # This is required because the cpd-oidcclient-secret 
  newClientSecret=$(oc extract secret/cpd-oidcclient-secret --to=- 2>&1 | grep -A1 CLIENT_SECRET | grep -v CLIENT_SECRET)
  newClientID=$(oc extract secret/cpd-oidcclient-secret --to=- 2>&1 | grep -A1 CLIENT_ID | grep -v CLIENT_ID)
  
  oldClientSecret=$(yq eval '(.data)' ${BACKUP_DIR}/secret/cpd-oidcclient-secret.yaml | grep CLIENT_SECRET | awk '{print $2'} | base64 -d)
  oldClientID=$(yq eval '(.data)' ${BACKUP_DIR}/secret/cpd-oidcclient-secret.yaml | grep CLIENT_ID | awk '{print $2'} | base64 -d)
  
  if [[  "$newClientSecret" == "" || "$newClientID" == "" || "$oldClientSecret" == "" || "$oldClientID" == "" ]]; then
   logError "Unable to retrieve new and old values for cpd-oidcclient-secret."
   logError "Client secret from current install: " $newClientSecret
   logError "Client ID from current install: " $newClientID
   logError "Client secret from backup: " $oldClientSecret
   logError "Client ID from backup: " $oldClientID
   echo
   exit 1
  fi

  zenbkpods=$(oc get pod -l=foundationservices.cloudpak.ibm.com=zen-data --no-headers --ignore-not-found | awk '{print $1}')

  for pod in ${zenbkpods[*]}
  do
    logInfo "Restoring Zen Services using pod ${pod}..."
    oc cp ${BACKUP_DIR}/zenbackup/zen-metastoredb-backup.tar $pod:/user-home/zen-metastoredb-backup.tar
    oc exec $pod -it -- bash -c "cd /user-home && tar -xvf zen-metastoredb-backup.tar"

    # create sed script to switch new cpd oidc info 
    oc exec $pod -it -- bash -c "cd /user-home && echo s/$oldClientSecret/$newClientSecret/g>switch.sed && echo s/$oldClientID/$newClientID/g>>switch.sed && cat switch.sed"
    oc exec $pod -it -- bash -c "cd /user-home && sed -i -f switch.sed zen-metastoredb-backup/oidc/oidcConfig.json"
   
    # restore zen services
    oc exec $pod -it -- bash -c "/zen4/zen4-br.sh $cp4baProjectName false"
    break
  done
  echo
  
  # clean up    
  logInfo "Cleaning up..."
  logInfo $(oc delete -f ${CUR_DIR}/zen-backup-deployment.yaml)
  logInfo $(oc delete -f ${CUR_DIR}/zen4-rolebinding.yaml)
  logInfo $(oc delete -f ${CUR_DIR}/zen4-role.yaml)
  logInfo $(oc delete -f ${CUR_DIR}/zen4-sa.yaml)
  logInfo $(oc delete -f ${CUR_DIR}/zen4-br-scripts.yaml)
  logInfo $(oc delete -f ${CUR_DIR}/zen-backup-pvc.yaml)
  echo
  
  rm -f ${CUR_DIR}/zen-backup-deployment.yaml
  rm -f ${CUR_DIR}/zen4-rolebinding.yaml
  rm -f ${CUR_DIR}/zen4-role.yaml
  rm -f ${CUR_DIR}/zen4-sa.yaml
  rm -f ${CUR_DIR}/zen4-br-scripts.yaml
  rm -f ${CUR_DIR}/zen-backup-pvc.yaml
  
  logInfo "Zen Services restore completed."
}
postDeployTerminating=No

while [[ $postDeployTerminating == "No" ]]; do

  echo 
  echo ========================================================
  echo "Select Post Deploy task to execute:"
  echo "   1: BTS Postgres License Fix"
  echo "   2: BTS Cloud Native Postgres Database restore"
  echo "   3: MongoDB restore (must restore before Zen Services)"
  echo "   4: Zen Services restore (must restore after MongoDB)"
  echo
  echo "  99: Terminate Post Deploy Script"
  echo 
  read -p "Please provide selection: " choice
  echo

  case "$choice" in
    1)  bts-license ;;
    2)  bts-cnpg ;;
    3)  mongoRestore ;;
    4)  restoreZen ;;
    99) postDeployTerminating=Yes ;;
  esac
done

logInfo "Have a nice day"
echo
