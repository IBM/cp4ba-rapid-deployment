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





echo "Creating CR for restore..."
yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.generation, .metadata.resourceVersion, .metadata.uid)' $CR_SPEC > $BACKUP_DIR/$(basename $CR_SPEC)
yq eval 'del(.status)' -i $BACKUP_DIR/$(basename $CR_SPEC)
echo

echo "CR_SPEC=" $CR_SPEC
echo "Basename=" $(basename $CR_SPEC)
fileName=$BACKUP_DIR/$(basename $CR_SPEC)
echo "FileName= " $fileName
echo

echo "Removing all lines containing null or empty string"
pattern1="null"
pattern2="\"\""
pattern3="sc_run_as_user"
while IFS="" read -r p || [ -n "$p" ]
do
  line=$(printf '%s\n' "$p")
  if [[ ! $line =~ $pattern2 ]]; then
    if [[ $line =~ $pattern3 ]]; then
      echo "$line" >> myclusterNew.yaml
    else
      if [[ ! $line =~ $pattern1 ]]; then
        echo "$line" >> myclusterNew.yaml
      fi
    fi
  fi
done < $fileName

# Now, filter out potential nulls
csrfreferrer=$(yq '.spec.bastudio_configuration.csrf_referrer' myclusterNew.yaml)
if [[ "$csrfreferrer" == "" ]]; then
  echo "Deleting csrf_referrer"
  yq eval 'del(.spec.bastudio_configuration.csrf_referrer)' -i myclusterNew.yaml
fi

# yq '(
#  .. | # recurse through all the nodes
#  select(.) # filter out nulls
#) as $i ireduce({};  # using that set of nodes, create a new result map
#  setpath($i | path; $i) # and put in each node, using its original path
#)' myclusterNew.yaml
