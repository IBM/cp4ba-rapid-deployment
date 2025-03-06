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
   
   if [ $cp4baProjectName == "REQUIRED" ]; then
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

# Assisted by watsonx Code Assistant 
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

if [[ ! -e $BACKUP_DIR/CR.yaml ]]; then
  logError "Backup $(basename $BACKUP_DIR) does not contain the backup file CR.yaml, exiting"
  echo
  exit 1
fi

backupNamespace=$(yq eval '.metadata.namespace' $BACKUP_DIR/CR.yaml)
backupDeploymentName=$(yq eval '.metadata.name' $BACKUP_DIR/CR.yaml)

logInfoValue "Backup was made on project: " $backupNamespace
if [[ "$backupNamespace" != "$cp4baProjectName" ]]; then
  logError "Backup project name $backupNamespace differs from restore project name ${cp4baProjectName}, data inconsistent, exiting."
  echo
  exit 1
fi

logInfoValue "The CR from the backup used deployment name: " $backupDeploymentName

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
logInfo "Processing Secrets"

yamlFiles=()
countYamlFiles=0

# Assisted by watsonx Code Assistant 
for yaml in $BACKUP_DIR/secrets/*.yaml; do
  secretName=$(yq eval '.metadata.name' $yaml)
  secretNamespace=$(yq eval '.metadata.namespace' $yaml)
  if [[ "$secretName" != "null" ]]; then
    if [[ "$secretNamespace" != "null" && "$secretNamespace" != "$backupNamespace" ]]; then
      logWarning "Skipping Secret $secretName in file $(basename $yaml) it has a non-matching namespace: $secretNamespace"
    else 
      if oc diff -f $yaml > /dev/null 2> /dev/null; then
        logWarning "Skipping Secret $secretName in file $(basename $yaml) it is already applied"
      else
        yamlFiles+=($yaml)
	countYamlFiles=$(expr $countYamlFiles + 1)
      fi
    fi
  fi
done

if [[ "$countYamlFiles" == "0" ]]; then
	logInfo "All secrets have already been applied"
else
  echo
  echo "The script will try to apply following secrets:"

  for file in "${yamlFiles[@]}"; do
    secretName=$(yq eval '.metadata.name' $file)
    echo -e "\tSecret \x1B[1m$pvcName\x1B[0m  (File: $(basename $yaml))"
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
    logInfoValue "Defining Secret ${secretName}, running command " oc apply -f $(basename $file)
    oc apply -f $file
  done
fi

echo
echo "Processing Persistent Volume Claims"

yamlFiles=()
countYamlFiles=0

# Assisted by watsonx Code Assistant 
for yaml in $BACKUP_DIR/pvc/*.yaml; do
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
          if oc diff -f $yaml > /dev/null 2> /dev/null; then
            logWarning "Skipping Persistent Volume Claim $pvcName in file $(basename $yaml) it is already defined"
          else
            yamlFiles+=($yaml)
            countYamlFiles=$(expr $countYamlFiles + 1)
          fi
        else
          logWarning "Skipping Persistent Volume Claim $pvcName in file $(basename $yaml) it refers to storage class $pvcStorageClass which does not exist."
        fi
      fi
    fi
  fi
done

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
    oc apply -f $file
  done
fi

      







