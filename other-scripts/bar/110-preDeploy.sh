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

logInfo "preDeploy will use project/namespace ${cp4baProjectName}"

BACKUP_ROOT_DIRECTORY_FULL="${CUR_DIR}/${cp4baProjectName}"
if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo 
else
   logError "Backup Directory ${cp4baProjectName} does not exist"
   exit 1
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/preDeploy_$(date +'%Y%m%d_%H%M%S').log"
logInfo "Details will be logged to $LOG_FILE."
echo

# $1 PVC name to check
# $2 CR NAME
function restore_this_pvc() {
  local pvcname=$1
  local crname=$2
  local sedexpr=$(printf 's/%s/CRNAME/g' $crname)
  local pvcname=$(echo ${pvcname} | sed $sedexpr)
  if [[ $pvcname == cmis-cfgstore ]]; then return 0; fi
  if [[ $pvcname == cpe-bootstrapstore ]]; then return 0; fi 
  if [[ $pvcname == cpe-cfgstore  ]]; then return 0; fi
  if [[ $pvcname == cpe-filestore  ]]; then return 0; fi
  if [[ $pvcname == cpe-icmrulesstore  ]]; then return 0; fi
  if [[ $pvcname == cpe-textextstore   ]]; then return 0; fi
  if [[ $pvcname == css-cfgstore  ]]; then return 0; fi
  if [[ $pvcname == css-customstore  ]]; then return 0; fi
  if [[ $pvcname == css-indexstore  ]]; then return 0; fi
  if [[ $pvcname == icn-asperastore  ]]; then return 0; fi
  if [[ $pvcname == icn-cfgstore  ]]; then return 0; fi
  if [[ $pvcname == icn-pluginstore  ]]; then return 0; fi
  if [[ $pvcname == jms-pvc-CRNAME-bastudio-deployment-0  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-bai-pvc  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-bastudio-dump-pvc  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-bastudio-index-pvc  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-dba-rr-pvc  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-pbkae-file-pvc  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-workflow-authoring-baw-dump-storage-pvc  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-workflow-authoring-baw-file-storage-pvc  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-workflow-authoring-baw-index-storage-pvc  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-workflow-authoring-baw-jms-data-vc-CRNAME-workflow-authoring-baw-jms-0  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-workspace-aaeae-file-pvc  ]]; then return 0; fi
  if [[ $pvcname == user-home-pvc ]]; then return 0; fi

  # If the name appears in the CR, then it is also part of what is needed.
  if grep $pvcname $BACKUP_DIR/CR.yaml > /dev/null 2>/dev/null; then return 0; fi

  return 1
}

# $1 PVC name to check
# $2 CR NAME
function restore_this_secret() {
  local secretname=$1
  local crname=$2
  local sedexpr=$(printf 's/%s/CRNAME/g' $crname)
  local secretname=$(echo ${secretname} | sed $sedexpr)

  if [[ $secretname == admin.registrykey  ]]; then return 0; fi
  if [[ $secretname == admin-user-details  ]]; then return 0; fi
  if [[ $secretname == external-tls-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-adp-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-ban-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-bawaut-admin-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-bawaut-server-db-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-entitlement-key  ]]; then return 0; fi
  if [[ $secretname == ibm-fncm-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-pfs-admin-secret  ]]; then return 0; fi
  if [[ $secretname == icp4adeploy-bas-admin-secret  ]]; then return 0; fi
  if [[ $secretname == icp4adeploy-workspace-aae-app-engine-admin-secret  ]]; then return 0; fi
  if [[ $secretname == icp4a-root-ca  ]]; then return 0; fi
  if [[ $secretname == icp4a-shared-encryption-key  ]]; then return 0; fi
  if [[ $secretname == ldap-bind-secret  ]]; then return 0; fi

  # If the name appears in the CR, then it is also part of what is needed.
  if grep $secretname $BACKUP_DIR/CR.yaml > /dev/null 2>/dev/null; then return 0; fi

  return 1
}

# Check if directory is empty
if [ "$(ls -A $BACKUP_ROOT_DIRECTORY_FULL)" ]; then
  # If directory is not empty, list subdirectories
  echo "Available backups:"
  count=0
  echo
  for dir in $BACKUP_ROOT_DIRECTORY_FULL/backup_*; do
    if [ -d "$dir" ]; then
      count=$(expr $count + 1)
      echo "$count:    $(basename $dir)"
    fi
  done

  # Prompt user to select a subdirectory
  read -p "Enter the number of the subdirectory to choose: " choice
  echo
  if [ -z "$choice" ]; then
    logError "No choice made, exiting."
    exit 1
  fi

  # Check if choice is a number
  if ! [[ $choice =~ ^[0-9]+$ ]]; then
    logError "Choice must be a number, exiting."
    exit 1
  fi

  # Check if choice is within range
  if [ $choice -lt 1 ] || [ $choice -gt $count ]; then
    logError "Choice is out of range, exiting"
    exit 1
  fi

  # Get the selected subdirectory
  count=0
  for dir in $BACKUP_ROOT_DIRECTORY_FULL/backup_*; do
    if [ -d "$dir" ]; then
      count=$(expr $count + 1)
      if [ "$count" == "$choice" ]; then
        BACKUP_DIR="$BACKUP_ROOT_DIRECTORY_FULL/$(basename $dir)"
      fi
    fi
  done
else
  logError "No Backups found for project ${cp4baProjectName}"
  echo
  exit 1
fi

logInfo "preDeploy will use backup directory $BACKUP_DIR"

if [[ -d $BACKUP_DIR/icp4acluster.icp4a.ibm.com ]]; then
  if [[ $(ls -A $BACKUP_DIR/icp4acluster.icp4a.ibm.com | wc -l) -eq 1 ]]; then
    CR_SPEC=$BACKUP_DIR/icp4acluster.icp4a.ibm.com/$(ls -A $BACKUP_DIR/icp4acluster.icp4a.ibm.com)
  fi
fi

# Note that below check will not succeed, if more than one CR was found. This is intended.
if [[ ! -e $CR_SPEC ]]; then
  logError "Could not find the CR in the backup directory $BACKUP_DIR"
  echo
  exit 1
fi

backupNamespace=$(yq eval '.metadata.namespace' $CR_SPEC)
backupDeploymentName=$(yq eval '.metadata.name' $CR_SPEC)
backupAppVersion=$(yq eval '.spec.appVersion' $CR_SPEC)

logInfoValue "Backup was made on project: " $backupNamespace
if [[ "$backupNamespace" != "$cp4baProjectName" ]]; then
  logError "Backup project name $backupNamespace differs from restore project name ${cp4baProjectName}, data inconsistent, exiting."
  echo
  exit 1
fi

logInfoValue "The CR from the backup used deployment name: " $backupDeploymentName
logInfoValue "The CR specification is for CP4BA Version: " $backupAppVersion

sed 's/#[^\n]*//g' $CR_SPEC | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid)' > $BACKUP_DIR/CR.yaml


logInfo "Verifying OC CLI is connected to the OCP cluster..."
WHOAMI=$(oc whoami)
logInfo "WHOAMI =" $WHOAMI

if [[ "$WHOAMI" == "" ]]; then
  logError "OC CLI is NOT connected to the OCP cluster. Please log in first with an admin user to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
  echo
  exit 1
fi
echo

if oc get project $backupNamespace  > /dev/null 2>&1; then
  logWarning "Backup Namespace is already existing"
  logInfoValue "Running command " oc project $backupNamespace
  oc project $backupNamespace > $LOG_FILE
else
  if [[ "$(oc auth can-i create project 2>/dev/null)" == "yes" ]]; then
    logInfo "Project $backupNamespace is not yet existing, but needs to be created."
    echo
    read -p "Press Return to continue, CTRL-C to abort" choice
    echo
    logInfoValue "Running command " oc new-project $backupNamespace
    oc new-project $backupNamespace >> $LOG_FILE
  else
    logError "Project $backupNamespace is not yet existing, but logged on user $(oc whoami) has not enough rights to create it. Exiting..."
  echo
    exit 1
  fi
fi

echo
if [ -d $BACKUP_DIR/secret ]; then
  logInfo "Processing Secrets ($(ls -A $BACKUP_DIR/secret | wc -l))"
else
  logInfo "Processing Secrets (none)"
fi

yamlFiles=()
countYamlFiles=0

for yaml in $BACKUP_DIR/secret/*.yaml; do
  secretName=$(yq eval '.metadata.name' $yaml)
  secretNamespace=$(yq eval '.metadata.namespace' $yaml)
  if [[ "$secretName" != "null" ]]; then
    if [[ "$secretNamespace" != "null" && "$secretNamespace" != "$backupNamespace" ]]; then
      logWarning "Skipping Secret $secretName in file $(basename $yaml) it has a non-matching namespace: $secretNamespace"
    else 
      if restore_this_secret $secretName $backupDeploymentName; then
        yamlFiles+=($yaml)
        countYamlFiles=$(expr $countYamlFiles + 1)
      fi
    fi
  fi
  echo -n "."
done

echo

if [[ "$countYamlFiles" == "0" ]]; then
	logInfo "All secrets have already been applied"
else
  echo
  echo "The script will try to apply following secrets:"

  for file in "${yamlFiles[@]}"; do
    secretName=$(yq eval '.metadata.name' $file)
    echo -e "\tSecret \x1B[1m$secretName\x1B[0m  (File: $(basename $file))"
  done

  echo
  printf "OK to apply these secret definitions? (Yes/No, default Yes): "
  read -rp "" ans
  case "$ans" in
  "n"|"N"|"no"|"No"|"NO")
     echo
     echo -e "Exiting..."
     echo
     exit 0
     ;;
  *)
     echo
     echo -e "OK..."
     ;;
  esac

  for file in "${yamlFiles[@]}"; do
    secretName=$(yq eval '.metadata.name' $file)
    logInfoValue "Defining Secret " ${secretName}
    yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid)' $file | oc apply -f - -n $backupNamespace
  done
fi

echo

if [ -d $BACKUP_DIR/persistentvolumeclaim ]; then
  logInfo "Processing Persistent Volume Claims ($(ls -A $BACKUP_DIR/persistentvolumeclaim | wc -l))"
else
  logInfo "Processing Persistent Volume Claims (none)"
fi

yamlFiles=()
countYamlFiles=0

for yaml in $BACKUP_DIR/persistentvolumeclaim/*.yaml; do
  pvcName=$(yq eval '.metadata.name' $yaml)
  pvcNamespace=$(yq eval '.metadata.namespace' $yaml)
  pvcStorageClass=$(yq eval '.spec.storageClassName' $yaml)

  if [[ "$pvcName" != "null" ]]; then
    if [[ "$pvcNamespace" != "null" && "$pvcNamespace" != "$backupNamespace" ]]; then
      logWarning "Skipping Persistent Volume Claim $pvcName in file $(basename $yaml) it has a non-matching namespace: $secretNamespace"
    else     
      if [[ "$pvcStorageClass" == "null" ]]; then
        logWarning "Skipping Persistent Volume Claim $pvcName in file $(basename $yaml) it does not reference a storage class"
      else
        if oc get storageclass "$pvcStorageClass" > /dev/null 2> /dev/null; then
          if restore_this_pvc $pvcName $backupDeploymentName; then
            yamlFiles+=($yaml)
            countYamlFiles=$(expr $countYamlFiles + 1)
          fi
        else
          logWarning "Skipping Persistent Volume Claim $pvcName in file $(basename $yaml) as it refers to storage class $pvcStorageClass which does not exist."
        fi
      fi
    fi
  fi
  echo -n "."
done

echo

if [[ "$countYamlFiles" == "0" ]]; then
	logInfo "All Persistent Volume Claims have already been applied"
else

  echo
  echo "The script will try to apply following Persistent Volume Claims (PVC):"

  for file in "${yamlFiles[@]}"; do
    pvcName=$(yq eval '.metadata.name' $file)
    echo -e "\tPVC \x1B[1m$pvcName\x1B[0m  (File: $(basename $yaml))"
  done
  echo
  printf "OK to apply these PVC definitions? (Yes/No, default Yes): "
  read -rp "" ans
  case "$ans" in
  "n"|"N"|"no"|"No"|"NO")
     echo
     echo -e "Exiting..."
     echo
     exit 0
     ;;
  *)
     echo
     echo -e "OK..."
     ;;
  esac
  
  for file in "${yamlFiles[@]}"; do
    pvcName=$(yq eval '.metadata.name' $file)
    logInfoValue "Defining PVC " ${pvcName}
    yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.finalizers, .status, .spec.volumeName)' $file | oc apply -f -
  done
fi

      







