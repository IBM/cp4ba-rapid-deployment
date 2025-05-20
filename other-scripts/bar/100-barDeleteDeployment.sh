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

# This script is for preparing a restore of the given namespace. It will delete all CP4BA components in the given namespace.
#    Only tested with CP4BA version: 21.0.3 IF029 and IF039, dedicated common services set-up

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
   echo
else
   echo
   mkdir "$BACKUP_ROOT_DIRECTORY_FULL"
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/DeleteDeployment_$DATETIMESTR.log"
logInfo "Details will be logged to $LOG_FILE."
echo

echo -e "\x1B[1mThis script deletes the CP4BA deployment in namespace ${cp4baProjectName} including the project. This is the first step when you want to restore a previously taken backup. \n \x1B[0m"

printf "Do you want to continue DELETING the CP4BA deployment in namespace ${cp4baProjectName}? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
   echo
   logInfo "Ok, deleting the CP4BA deployment in namespace ${cp4baProjectName}..."
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
  if oc get project $cp4baProjectName  > /dev/null 2>&1; then
    logInfo "Switching to project ${cp4baProjectName}..."
    logInfo $(oc project $cp4baProjectName)
  else
    logError "Project ${cp4baProjectName} does not exist. Exiting..."
    echo
    exit 1
  fi
fi
echo

## Look for CP4BA deployments
CP4BA_DELPOYMENTS=$(oc get ICP4ACluster -o name)
CP4BA_DELPOYMENTS_NAMES=
CP4BA_DELPOYMENTS_COUNT=0
for d in $CP4BA_DELPOYMENTS; do
  CP4BA_DELPOYMENTS_COUNT=$((CP4BA_DELPOYMENTS_COUNT+1))
  if [[ $CP4BA_DELPOYMENTS_COUNT == 1 ]]; then
    CP4BA_DELPOYMENTS_NAMES=$(echo $d | cut -d "/" -f2)
  else
    CP4BA_DELPOYMENTS_NAMES=$CP4BA_DELPOYMENTS_NAMES", "$(echo $d | cut -d "/" -f2)
  fi
done

if [[ $CP4BA_DELPOYMENTS_COUNT == 0 ]]; then
  logWarning "No CP4BA Deployment found!"
  echo
  printf "Do you want to continue DELETING namespace ${cp4baProjectName}? (Yes/No, default: No): "
  read -rp "" ans
  case "$ans" in
  "y"|"Y"|"yes"|"Yes"|"YES")
     echo
     logInfo "Ok, deleting namespace ${cp4baProjectName}..."
     echo
     ;;
  *)
     echo
     logInfo "Exiting..."
     echo
     exit 0
     ;;
  esac
elif [[ $CP4BA_DELPOYMENTS_COUNT > 1 ]]; then
  logWarning "Multiple CP4BA Deployments found:" $CP4BA_DELPOYMENTS_NAMES
  echo
  printf "Do you want to continue DELETING all CP4BA deployments ($CP4BA_DELPOYMENTS_NAMES) in namespace ${cp4baProjectName} including the namespace? (Yes/No, default: No): "
  read -rp "" ans
  case "$ans" in
  "y"|"Y"|"yes"|"Yes"|"YES")
     echo
     logInfo "Ok, deleting all CP4BA deployments ($CP4BA_DELPOYMENTS_NAMES) in namespace ${cp4baProjectName} including the namespace..."
     echo
     ;;
  *)
     echo
     logInfo "Exiting..."
     echo
     exit 0
     ;;
  esac
else
  CP4BA_NAME=$(oc get ICP4ACluster -o name |cut -d "/" -f 2)
  logInfo "CP4BA deployment name: $CP4BA_NAME"
  echo
fi

if [[ $CP4BA_DELPOYMENTS_COUNT > 0 ]]; then
  for d in $CP4BA_DELPOYMENTS; do
    # Delete the custom resource - icp4acluster
    CR_NAME=$(echo $d | cut -d "/" -f2)
    logInfo "Deleting Custom Resource $CR_NAME in namespace $cp4baProjectName..."
    logInfo $(oc delete ICP4ACluster "$CR_NAME" -n "$cp4baProjectName" --timeout=10s)
  done
  
  logInfo "   Waiting for 180 seconds..."
  sleep 180
  while true; do
    # Check if the pod exists
    STATUS=$(oc get pod -n $cp4baProjectName | egrep "ibm-zen-operator|ibm-commonui-operator")
    
    if [ -z "$STATUS" ]; then
      logInfo "   ibm-zen-operator and ibm-commonui-operator pods are deleted, waiting for another 30 seconds to stablize..."
      echo
      sleep 30 
      break
    else
      logInfo "   Checking after 5 seconds..."
      # Wait for a few seconds before re-checking
      sleep 5
    fi
  done
fi

logInfo "Deleting the namespace $cp4baProjectName..."
logInfo $(oc delete project $cp4baProjectName --timeout=10s)
logInfo "Wait until namespace $cp4baProjectName is completely deleted..."
count=0
attempts=0
while true; do
  EXISTS=$(oc get project "$cp4baProjectName" --ignore-not-found=true)
  if [ -z "$EXISTS" ]; then
     logInfo "Namespace $cp4baProjectName deletion successful."
     break
  else
     ((count += 1))
     ((attempts += 1))
     if ((count <= 6)); then
       logInfo "  Waiting for namespace $cp4baProjectName to be terminated. Rechecking in 10 seconds..."
       sleep 10
     else
       logWarning "  Deleting namespace $cp4baProjectName is taking too long. Patching all remaining finalizers..."
       # for i in $(oc api-resources --verbs=list --namespaced=true -o name | xargs -n 1 oc get --show-kind --ignore-not-found -n $cp4baProjectName -o name); do
       for i in $(oc api-resources --verbs=list --namespaced=true -o name | xargs -n 1 oc get --ignore-not-found -n ${cp4baProjectName} -o json | jq -r '.items[] | select(.metadata.finalizers != null) | .kind + "/" + .metadata.name'); do
         # Get the kind and the name
         KIND=$(echo $i | grep -oP '.*(?=/)')
         NAME=$(echo $i | grep -oP '(?<=/).*')
         # check if still exists
         # RESOURCE_EXISTS=$(oc get ${KIND} ${NAME} --ignore-not-found=true)
         # if [[ -z "$RESOURCE_EXISTS" ]]; then
           logInfo "  "$(oc patch ${KIND} ${NAME} -n "${cp4baProjectName}" --type=merge -p'{"metadata":{"finalizers":[]}}')
         # fi
       done
       if ((attempts <= 14)); then
         count=3
       else
         logError "Namespace $cp4baProjectName can't be deleted by this script."
         break
       fi
     fi
  fi
done
echo
