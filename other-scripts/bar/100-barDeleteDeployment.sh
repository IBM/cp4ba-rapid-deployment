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
#    Only tested with CP4BA version: 21.0.3 IF029 and 039, dedicated common services set-up

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
#  exit 1
fi



##### Delete the deployment ##############################################################
# List all rolebindings in the namespace
ROLEBINDINGS=$(oc get rolebindings -n "$cp4baProjectName" -o jsonpath='{.items[*].metadata.name}')

# Check if there are any rolebindings
if [ -z "$ROLEBINDINGS" ]; then
  echo "No RoleBindings found in namespace $cp4baProjectName."
  exit 0
fi

# Delete each RoleBinding
echo "Deleting RoleBindings in namespace: $cp4baProjectName"
for RB in $ROLEBINDINGS; do
  echo "Deleting RoleBinding: $RB"
  oc delete rolebinding "$RB" -n "$cp4baProjectName"
done

echo "All RoleBindings in namespace $cp4baProjectName have been deleted."

echo "Retrieving the icp4a cluster instance"

CR_NAME=$(oc get icp4acluster -n "$cp4baProjectName" -o jsonpath='{.items[*].metadata.name}')

#Check if the custom resource name exists
if [ -z "$CR_NAME" ]; then
  echo "No ICP4ACluster found in namespace $cp4baProjectName."
  #exit 0
else
  # Delete the custom resource - icp4acluster
  echo "Deleting Custom Resource $CR_NAME in namespace $cp4baProjectName..."
  oc delete ICP4ACluster $CR_NAME -n $cp4baProjectName
  echo " Waiting for 5 seconds"
  sleep 5
fi


# Deleting ibm-cp4ba subscription
echo "Deleting subscription ibm-cp4a-operator "
oc delete Subscription "ibm-cp4a-operator" -n "$cp4baProjectName"

echo "Waiting for operator resources to be deleted"
sleep 5
# Deleting the ibm-cp4a-operator-catalog-group
echo "Deleting Operator group ibm-cp4a-operator-catalog-group"
oc delete operatorgroup "ibm-cp4a-operator-catalog-group" -n "$cp4baProjectName"
echo "Waiting for operator resources to be deleted"
sleep 5

# Deleting ibm-cp4ba subscription
echo "Deleting subscription ibm-cp4a-wfps-operator "
oc delete Subscription "ibm-cp4a-wfps-operator" -n "$cp4baProjectName"

echo "Waiting for operator resources to be deleted"
sleep 5



#Deleting operandbindinfo
oc delete operandbindinfo --all - n "$cp4baProjectName"
sleep 5

#Deleteing operandrequest 
oc delete operandrequest --all -n "$cp4baProjectName"
sleep 5
#Deleting operandConfig
oc delete operandconfig --all -n "$cp4baProjectName"
sleep 5
#Deleting operandregistry
oc delete operandregistry --all -n "$cp4baProjectName"
sleep 5

#Deleting Operand-deployment-lifecycle-namager subscription
#oc delete subscription "operand-deployment-lifecycle-manager-app" -n "$cp4baProjectName"

sleep 5

oc delete commonservice common-service -n "$cp4baProjectName"
oc delete csv -l operators.coreos.com/ibm-common-service-operator.$cp4baProjectName -n $cp4baProjectName
oc delete subscription -l operators.coreos.com/ibm-common-service-operator.$cp4baProjectName -n $cp4baProjectName


#Deleting namespacescope
oc delete namespacescope --all -n "$cp4baProjectName"

#Deleting Operand Deployment Lifecycle Manager operator
oc delete csv -l operators.coreos.com/ibm-odlm.$NAMESOACE -n $cp4baProjectName
oc delete subscription -l operators.coreos.com/ibm-odlm.$cp4baProjectName -n $cp4baProjectName

#Uninstall IBM NAmespaceScope operator
oc delete csv -l operators.coreos.com/ibm-namespace-scope-operator.$cp4baProjectName -n $cp4baProjectName
oc delete subscription -l operators.coreos.com/ibm-namespace-scope-operator.$cp4baProjectName -n $cp4baProjectName

#Uninstall IBM Automation Foundation Core Operator
oc delete csv -l operators.coreos.com/ibm-automation-core.$cp4baProjectName -n $cp4baProjectName
oc delete subscription -l operators.coreos.com/ibm-automation-core.$cp4baProjectName -n $cp4baProjectName


#Uninstall IBM Automation Foundation Insights Engine Operator
oc delete csv -l operators.coreos.com/ibm-automation-insightsengine.$cp4baProjectName -n $cp4baProjectName
oc delete subscription -l operators.coreos.com/ibm-automation-insightsengine.$cp4baProjectName -n $cp4baProjectName

#Uninstall IBM Automation Foundation Operator
oc delete csv -l operators.coreos.com/ibm-automation.$cp4baProjectName -n $cp4baProjectName
oc delete subscription -l operators.coreos.com/ibm-automation.$cp4baProjectName -n $cp4baProjectName

# List all ClusterServiceVersions (CSV) in the namespace
CSV_LIST=$(oc get csv -n "$cp4baProjectName" -o jsonpath='{.items[*].metadata.name}')

# Check if there are any CSVs in the namespace
if [ -z "$CSV_LIST" ]; then
  echo "No ClusterServiceVersions found in namespace: $cp4baProjectName."
  exit 0
fi

# Delete each ClusterServiceVersion
echo "Deleting ClusterServiceVersions in namespace: $cp4baProjectName..."
for CSV in $CSV_LIST; do
  echo "Deleting ClusterServiceVersion: $CSV"
  oc delete csv "$CSV" -n "$cp4baProjectName"
done

echo "All ClusterServiceVersions in namespace $cp4baProjectName have been deleted."

#Searching and deleting remaining subscriptions
# List all subscription names in the namespace
subscriptions=$(oc get subscriptions -n $cp4baProjectName -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

for sub in $subscriptions; do
  echo "Deleting subscription: $sub"
  
  #deleting subscription
  oc delete subscription $sub -n $cp4baProjectName
done

echo "All subscriptions in the $cp4baProjectName namespace have been deleted."

#Deleting all deployments
oc delete deployment --all -n $cp4baProjectName
#Deleting all jobs
oc delete job --all -n $cp4baProjectName
#Deleting all pods
oc delete pod --all -n $cp4baProjectName
#Deleting all services
oc delete svc --all -n $cp4baProjectName
#Deleting all network policies
oc delete networkpolicy --all -n $cp4baProjectName
#Deleting all PVCs
oc delete pvc --all -n $cp4baProjectName
#Deleting all service accounts
oc delete serviceaccount  --all -n $cp4baProjectName
#Deleting all roles
oc delete role --all -n $cp4baProjectName

oc delete project $cp4baProjectName


echo
