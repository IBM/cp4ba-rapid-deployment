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
   logInfo "Switching to project ${cp4baProjectName}..."
   logInfo $(oc project $cp4baProjectName)
fi
echo

## Get CP4BA deployment name
CP4BA_NAME=$(oc get ICP4ACluster -o name |cut -d "/" -f 2)
logInfo "CP4BA deployment name: $CP4BA_NAME"
echo

## Get CP4BA version
CP4BA_VERSION=$(oc get ICP4ACluster $CP4BA_NAME -o 'custom-columns=NAME:.metadata.name,VERSION:.spec.appVersion' --no-headers | awk '{print $2}')
logInfo "Found CP4BA version: $CP4BA_VERSION"
echo


MAJOR_CP4BA_VERSION=$(cut -c 1-6 <<< $CP4BA_VERSION)
if [[ $MAJOR_CP4BA_VERSION != "21.0.3" ]]; then
  logError "  CP4BA version not supported!"
  echo
  exit 1
fi

######Function#######
patch_finalizers(){
 RESOURCES=$(oc get $1 -n $2 -o json | jq -r '.items[]|select(.metadata.finalizers != null)|.kind +"/"+.metadata.name')

for i in $RESOURCES; do
  KIND=$(echo $i | cut -d '/' -f1)
  NAME=$(echo $i | cut -d '/' -f2)
  
  logInfo "Removing finalizers from $KIND/$NAME..."
  oc patch $KIND $NAME -n $2 --type=merge -p '{"metadata":{"finalizers":[]}}'
  logInfo "Deleting the Resource by $NAME"
  logInfo $(oc delete ${KIND} ${NAME} -n ${2} --ignore-not-found=true)
done
}

##### Delete the deployment ##############################################################
logInfo "Retrieving the icp4a cluster instance"
CR_NAME=$(oc get icp4acluster -n "$cp4baProjectName" -o jsonpath='{.items[*].metadata.name}' --ignore-not-found=true)

#Check if the custom resource name exists
if [ -z "$CR_NAME" ]; then
  logInfo "No ICP4ACluster found in namespace $cp4baProjectName."
  echo
#  exit 1
else
  # Delete the custom resource - icp4acluster
  logInfo "Deleting Custom Resource $CR_NAME in namespace $cp4baProjectName..."
  logInfo $(oc delete ICP4ACluster "$CR_NAME" -n "$cp4baProjectName")
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

# Deleting ibm-cp4ba subscription
SUB_NAME=$(oc get subscription "ibm-cp4a-operator" -n "$cp4baProjectName" --ignore-not-found=true)
if [ -z "$SUB_NAME" ]; then
  logInfo "ibm-cp4a subscription not found"
else
  logInfo "Deleting subscription ibm-cp4a-operator "
  logInfo $(oc delete Subscription "ibm-cp4a-operator" -n "$cp4baProjectName")
  logInfo "Waiting for ibm-cp4a-operator resources to be deleted"
  sleep 15
fi

# Deleting the ibm-cp4a-operator-catalog-group
OG_NAME=$(oc get operatorgroup "ibm-cp4a-operator-catalog-group" -n "$cp4baProjectName" --ignore-not-found=true)
if [ -z "$OG_NAME" ]; then
  logInfo "ibm-cp4a-operator-catalog-group is not found"
else
  logInfo "Deleting Operator group ibm-cp4a-operator-catalog-group"
  logInfo $(oc delete operatorgroup "ibm-cp4a-operator-catalog-group" -n "$cp4baProjectName")
  logInfo "Waiting for ibm-cp4a-operator-catalog-group resources to be deleted"
  sleep 15
fi

# Deleting ibm-cp4ba workflow subscription
SUB_NAME=$(oc get Subscription "ibm-cp4a-wfps-operator" -n "$cp4baProjectName" --ignore-not-found=true)
if [ -z "$SUB_NAME" ]; then
  logInfo "ibm-cp4a-wfps-operator not found"
else
  logInfo "Deleting subscription ibm-cp4a-wfps-operator "
  logInfo $(oc delete Subscription "ibm-cp4a-wfps-operator" -n "$cp4baProjectName")
  logInfo "Waiting for WFPS operator resources to be deleted"
  sleep 15
fi
echo

logInfo "Deleting operandbindinfo"
patch_finalizers "operandbindinfo" "$cp4baProjectName"
logInfo $(oc delete operandbindinfo --all -n "$cp4baProjectName")
sleep 5
logInfo "Deleting operandrequest" 
patch_finalizers "operandrequest" "$cp4baProjectName"
logInfo $(oc delete operandrequest --all -n "$cp4baProjectName")
sleep 5
logInfo "Deleting operandconfig"
patch_finalizers "operandconfig" "$cp4baProjectName"
logInfo $(oc delete operandconfig --all -n "$cp4baProjectName")
sleep 5
logInfo "Deleting operandregistry"
patch_finalizers "operandregistry" "$cp4baProjectName"
logInfo $(oc delete operandregistry --all -n "$cp4baProjectName")
sleep 5
echo

logInfo "Deleting Common service, CSV and subscription"
logInfo $(oc delete commonservice common-service -n "$cp4baProjectName" --ignore-not-found=true)
logInfo $(oc delete csv -l operators.coreos.com/ibm-common-service-operator.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)
logInfo $(oc delete subscription -l operators.coreos.com/ibm-common-service-operator.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)
echo

logInfo "Deleting namespacescope"
patch_finalizers "namespacescope" "$cp4baProjectName"
logInfo $(oc delete namespacescope --all -n "$cp4baProjectName")

logInfo "Deleting Operand Deployment Lifecycle Manager operator"
logInfo $(oc delete csv -l operators.coreos.com/ibm-odlm.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)
logInfo $(oc delete subscription -l operators.coreos.com/ibm-odlm.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)

logInfo "Uninstall IBM NAmespaceScope operator"
logInfo $(oc delete csv -l operators.coreos.com/ibm-namespace-scope-operator.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)
logInfo $(oc delete subscription -l operators.coreos.com/ibm-namespace-scope-operator.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)
echo

logInfo "Uninstall IBM Automation Foundation Core Operator"
logInfo $(oc delete csv -l operators.coreos.com/ibm-automation-core.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)
logInfo $(oc delete subscription -l operators.coreos.com/ibm-automation-core.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)

logInfo "Uninstall IBM Automation Foundation Insights Engine Operator"
logInfo $(oc delete csv -l operators.coreos.com/ibm-automation-insightsengine.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)
logInfo $(oc delete subscription -l operators.coreos.com/ibm-automation-insightsengine.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)

logInfo "Uninstall IBM Automation Foundation Operator"
logInfo $(oc delete csv -l operators.coreos.com/ibm-automation.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)
logInfo $(oc delete subscription -l operators.coreos.com/ibm-automation.$cp4baProjectName -n $cp4baProjectName --ignore-not-found=true)
echo

logInfo "List all ClusterServiceVersions (CSV) in the namespace"
CSV_LIST=$(oc get csv -n "$cp4baProjectName" -o jsonpath='{.items[*].metadata.name}' --ignore-not-found=true)
# Check if there are any CSVs in the namespace
if [ -z "$CSV_LIST" ]; then
  logInfo "No ClusterServiceVersions found in namespace: $cp4baProjectName."
else
  logInfo "Delete each ClusterServiceVersion"
  logInfo "Deleting ClusterServiceVersions in namespace: $cp4baProjectName..."
  for CSV in $CSV_LIST; do
    logInfo "Deleting ClusterServiceVersion: $CSV"
    logInfo $(oc delete csv "$CSV" -n "$cp4baProjectName")
  done
  logInfo "All ClusterServiceVersions in namespace $cp4baProjectName have been deleted."
fi

#Searching and deleting remaining subscriptions
# List all subscription names in the namespace
subscriptions=$(oc get subscriptions -n $cp4baProjectName -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --ignore-not-found=true)
for sub in $subscriptions; do
  logInfo "Deleting subscription: $sub"
  
  #deleting subscription
  logInfo $(oc delete subscription $sub -n $cp4baProjectName)
done
echo

logInfo "Deleting all deployments"
logInfo $(oc delete deployment --all -n $cp4baProjectName)
logInfo "Deleting all jobs"
logInfo $(oc delete job --all -n $cp4baProjectName)
logInfo "Deleting all pods"
logInfo $(oc delete pod --all -n $cp4baProjectName)
logInfo "Deleting all services"
logInfo $(oc delete svc --all -n $cp4baProjectName)
logInfo "Deleting all network policies"
logInfo $(oc delete networkpolicy --all -n $cp4baProjectName)
logInfo "Deleting all PVCs"
logInfo $(oc delete pvc --all -n $cp4baProjectName)
logInfo "Deleting all service accounts"
logInfo $(oc delete serviceaccount  --all -n $cp4baProjectName)
logInfo "Deleting all roles"
logInfo $(oc delete role --all -n $cp4baProjectName)
echo

# List all rolebindings in the namespace
ROLEBINDINGS=$(oc get rolebindings -n "$cp4baProjectName" -o jsonpath='{.items[*].metadata.name}' --ignore-not-found=true)
# Check if there are any rolebindings
if [ -z "$ROLEBINDINGS" ]; then
  logInfo "No RoleBindings found in namespace $cp4baProjectName."
else
  # Delete each RoleBinding
  logInfo "Deleting RoleBindings in namespace: $cp4baProjectName"
  for RB in $ROLEBINDINGS; do
    if [[ $RB != "admin" && $RB != "edit" ]]; then
      logInfo "Deleting RoleBinding: $RB"
      logInfo $(oc delete rolebinding "$RB" -n "$cp4baProjectName")
    fi
  done
fi

patch_finalizers "rolebinding" "$cp4baProjectName"


for i in $(oc api-resources --verbs=list --namespaced=true -o name | xargs -n 1 oc get --ignore-not-found -n ${cp4baProjectName} -o json | jq -r '.items[] | select(.metadata.finalizers != null) | .kind + "/" + .metadata.name'); do
   # Get the kind and the name
   if [[ "$i" == Cartridge* ]]; then
     continue
   fi
   KIND=$(echo $i | cut -d '/' -f1)
   NAME=$(echo $i | cut -d '/' -f2)
   echo "KIND->"$KIND
   echo "Name->"$NAME
   logInfo $(oc patch ${KIND} ${NAME} -n "${cp4baProjectName}" --type=merge -p'{"metadata":{"finalizers":[]}}')
   logInfo $(oc delete "${KIND}" ${NAME} -n "${cp4baProjectName}" --ignore-not-found=true)
done

for i in $(oc api-resources --verbs=list --namespaced=true -o name | xargs -n 1 oc get --show-kind --ignore-not-found -n $cp4baProjectName -o name); do
   # Get the kind and the name
   KIND=$(echo $i | grep -oP '.*(?=/)')
   NAME=$(echo $i | grep -oP '(?<=/).*')  
   echo "KIND->"$KIND
   echo "Name->"$NAME
   logInfo $(oc patch ${KIND} ${NAME} -n "${cp4baProjectName}" --type=merge -p'{"metadata":{"finalizers":[]}}')
   logInfo $(oc delete "${KIND}" ${NAME} -n "${cp4baProjectName}" --ignore-not-found=true)
done

logInfo "Finally, deleting the namespace $cp4baProjectName"
oc delete project $cp4baProjectName
logInfo "Wait until namespace $cp4baProjectName is completely deleted."
count=0
while true; do
  EXISTS=$(oc get project "$cp4baProjectName" --ignore-not-found=true)
  if [ -z "$EXISTS" ]; then
     logInfo "Namespace $cp4baProjectName deletion successful."
     break
  else
     ((count += 1))
     if ((count <= 10)); then
       logInfo "Waiting for namespace $cp4baProjectName to be terminated.  ... Rechecking in  10 seconds"
       sleep 10
     else
       logError "Deleting namespace $cp4baProjectName is taking too long and giving up"
       logError $(oc get project "$cp4baProjectName" -o yaml)
       echo
       exit 1
     fi
  fi
done
echo


