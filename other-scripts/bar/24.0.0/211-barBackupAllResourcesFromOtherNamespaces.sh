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
   
   echo "Done!"
else
   echo
   echo "File ${INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 1
fi

BACKUP_ROOT_DIRECTORY_FULL="${CUR_DIR}/${cp4baProjectName}"
if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   true
else
   mkdir "$BACKUP_ROOT_DIRECTORY_FULL"
fi

OTHER_PROJECTS_BACKUP_ROOT_DIRECTORY_FULL="$BACKUP_ROOT_DIRECTORY_FULL/otherProjects"
if [[ -d $OTHER_PROJECTS_BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo
else
   echo
   mkdir "$OTHER_PROJECTS_BACKUP_ROOT_DIRECTORY_FULL"
fi

LOG_FILE="$OTHER_PROJECTS_BACKUP_ROOT_DIRECTORY_FULL/Backup_$DATETIMESTR.log"
logInfo "Details will be logged to $LOG_FILE."
echo

echo -e "\x1B[1mThis script backs up namespace kube-public and cs-control for compairson while the restore tests. \n \x1B[0m"

printf "Do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
   echo
   logInfo "Ok, backing up other namespaces..."
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



##### Backup kube-public ##############################################################
## Switch to kube-public project
project=$(oc project --short)
logInfo "project =" $project
if [[ "$project" != "kube-public" ]]; then
   logInfo "Switching to project kube-public..."
   logInfo $(oc project kube-public)
fi
echo

## Create backup directory
logInfo "Creating backup directory..."
BACKUP_DIR=$OTHER_PROJECTS_BACKUP_ROOT_DIRECTORY_FULL/backup_kube-public_${DATETIMESTR}
mkdir -p $BACKUP_DIR
echo

## Backup
logInfo "Collecting resources that need to be backed up..."
allResources=$(oc api-resources --verbs=list --namespaced=true -o name | xargs -n 1 oc get --show-kind --ignore-not-found -n kube-public -o name)
echo
for i in $allResources; do
   # Get the kind and the name
   kind=$(echo $i | grep -oP '.*(?=/)')
   name=$(echo $i | grep -oP '(?<=/).*')
   
   logInfo "Backing up resource =" $i
   RESOURCE_BACKUP_DIR=$BACKUP_DIR/$kind
   if [[ !(-d $RESOURCE_BACKUP_DIR) ]]; then
     mkdir -p $RESOURCE_BACKUP_DIR
   fi
   
   oc get $kind $name -o yaml > $RESOURCE_BACKUP_DIR/$name.yaml
done
echo



##### Backup cs-control ##############################################################
## Switch to cs-control project
project=$(oc project --short)
logInfo "project =" $project
if [[ "$project" != "cs-control" ]]; then
   logInfo "Switching to project cs-control..."
   logInfo $(oc project cs-control)
fi
echo

## Create backup directory
logInfo "Creating backup directory..."
BACKUP_DIR=$OTHER_PROJECTS_BACKUP_ROOT_DIRECTORY_FULL/backup_cs-control_${DATETIMESTR}
mkdir -p $BACKUP_DIR
echo

## Backup
logInfo "Collecting resources that need to be backed up..."
allResources=$(oc api-resources --verbs=list --namespaced=true -o name | xargs -n 1 oc get --show-kind --ignore-not-found -n cs-control -o name)
echo
for i in $allResources; do
   # Get the kind and the name
   kind=$(echo $i | grep -oP '.*(?=/)')
   name=$(echo $i | grep -oP '(?<=/).*')
   
   logInfo "Backing up resource =" $i
   RESOURCE_BACKUP_DIR=$BACKUP_DIR/$kind
   if [[ !(-d $RESOURCE_BACKUP_DIR) ]]; then
     mkdir -p $RESOURCE_BACKUP_DIR
   fi
   
   oc get $kind $name -o yaml > $RESOURCE_BACKUP_DIR/$name.yaml
done
echo



##### Backup openshift-marketplace ##############################################################
## Switch to openshift-marketplace project
project=$(oc project --short)
logInfo "project =" $project
if [[ "$project" != "openshift-marketplace" ]]; then
   logInfo "Switching to project openshift-marketplace..."
   logInfo $(oc project openshift-marketplace)
fi
echo

## Create backup directory
logInfo "Creating backup directory..."
BACKUP_DIR=$OTHER_PROJECTS_BACKUP_ROOT_DIRECTORY_FULL/backup_openshift-marketplace_${DATETIMESTR}
mkdir -p $BACKUP_DIR
echo

## Backup
logInfo "Collecting resources that need to be backed up..."
allResources=$(oc api-resources --verbs=list --namespaced=true -o name | xargs -n 1 oc get --show-kind --ignore-not-found -n openshift-marketplace -o name)
echo
for i in $allResources; do
   # Get the kind and the name
   kind=$(echo $i | grep -oP '.*(?=/)')
   name=$(echo $i | grep -oP '(?<=/).*')
   
   logInfo "Backing up resource =" $i
   RESOURCE_BACKUP_DIR=$BACKUP_DIR/$kind
   if [[ !(-d $RESOURCE_BACKUP_DIR) ]]; then
     mkdir -p $RESOURCE_BACKUP_DIR
   fi
   
   oc get $kind $name -o yaml > $RESOURCE_BACKUP_DIR/$name.yaml
done
echo
