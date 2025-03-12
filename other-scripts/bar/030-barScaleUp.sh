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

# This script is for scaling up the CP4BA deployment after you took a backup as part of the Backup And Restore (BAR) process.
# It will scale up all CP4BA components in the given namespace.
#    Only tested with CP4BA version: 21.0.3 IF034, dedicated common services set-up

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import common utilities
source ${CUR_DIR}/common.sh

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

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/ScaleUpAfterBackup_$(date +'%Y%m%d_%H%M%S').log"
logInfo "Details will be logged to $LOG_FILE."

echo
echo -e "\x1B[1mThis script scales up namespace ${cp4baProjectName} after you took a backup. It scales up all needed pods. \n \x1B[0m"

printf "Have you completed taking the required backups and do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
   echo
   logInfo "Ok, scaling up the CP4BA deployment in namespace ${cp4baProjectName}..."
   echo
   ;;
*)
   echo
   logInfo "Exiting..."
   echo
   exit 0
   ;;
esac

logInfo "Verifying OC CLI is connected to the OCP cluster..."
WHOAMI=$(oc whoami)
logInfo "WHOAMI =" $WHOAMI

if [[ "$WHOAMI" == "" ]]; then
   logError "OC CLI is NOT connected to the OCP cluster. Please log in first with an admin user to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
   echo
   exit 1
fi
echo

project=$(oc project --short)
logInfo "project =" $project
if [[ "$project" != "$cp4baProjectName" ]]; then
   logInfo "Switching to project ${cp4baProjectName}..."
   logInfo $(oc project $cp4baProjectName)
fi
echo

propertiesfile=$BACKUP_ROOT_DIRECTORY_FULL/properties.sh
if [[ -f $propertiesfile ]]; then
  logInfo "Properties file $propertiesfile found. Using it to scale up."
  . $propertiesfile
  logInfo "Done!"
else
  logError "Properties file $propertiesfile NOT found. It is required to properly scale up the CP4BA deployment. It got created when you scaled down the deployment. Please restore it before you can proceed."
  echo
  exit 1
fi
echo

if [[ "$cp4baProjectName" != "$cp4baProjectNamespace" ]]; then
  logError "Properties file is NOT for the given project namespace. Expected project: $cp4baProjectName Properties file is for project: $cp4baProjectNamespace"
  echo
  exit 1
else
  logInfo "Properties file is for the given project namespace. Continuing..."
fi
echo



# First, scale up all operators
logInfo "Scaling up all operators..."
logInfo $(oc scale deploy ibm-cp4a-operator --replicas=1)
logInfo $(oc scale deploy ibm-cp4a-wfps-operator-controller-manager --replicas=1)
logInfo $(oc scale deploy iaf-core-operator-controller-manager --replicas=1)
logInfo $(oc scale deploy iaf-eventprocessing-operator-controller-manager --replicas=1)
logInfo $(oc scale deploy iaf-flink-operator-controller-manager --replicas=1)
logInfo $(oc scale deploy iaf-insights-engine-operator-controller-manager --replicas=1)
logInfo $(oc scale deploy iaf-operator-controller-manager --replicas=1)
logInfo $(oc scale deploy ibm-bts-operator-controller-manager --replicas=1)
logInfo $(oc scale deploy ibm-elastic-operator-controller-manager --replicas=1)
logInfo $(oc scale deploy nginx-ingress-controller --replicas=1)
logInfo $(oc scale deploy ibm-zen-operator --replicas=1)
logInfo $(oc scale deploy ibm-platform-api-operator --replicas=1)
logInfo $(oc scale deploy ibm-namespace-scope-operator --replicas=1)
logInfo $(oc scale deploy ibm-mongodb-operator --replicas=1)
logInfo $(oc scale deploy ibm-management-ingress-operator --replicas=1)
logInfo $(oc scale deploy ibm-ingress-nginx-operator --replicas=1)
logInfo $(oc scale deploy ibm-iam-operator --replicas=1)
logInfo $(oc scale deploy ibm-commonui-operator --replicas=1)
logInfo $(oc scale deploy ibm-common-service-operator --replicas=1)
# not always deployed
if oc get deployment iaf-system-entity-operator > /dev/null 2>&1; then
  logInfo $(oc scale deploy iaf-system-entity-operator --replicas=1)
fi
logInfo $(oc scale deploy iam-policy-controller --replicas=1)
logInfo $(oc scale deploy operand-deployment-lifecycle-manager --replicas=1)

# these two operator deployments do have the version in their name, therefore we have to get the deployment name first
eventsOperatorDeployment=$(oc get deployment -o 'custom-columns=NAME:.metadata.name,SELECTOR:.spec.selector.matchLabels.name' --no-headers --ignore-not-found | grep 'ibm-events-operator' | awk '{print $1}')
# not always deployed
if [[ "$eventsOperatorDeployment" != "" ]]; then
  logInfo $(oc scale deploy $eventsOperatorDeployment --replicas=1)
fi
postgresqlOperatorDeployment=$(oc get deployment -l=app.kubernetes.io/name=cloud-native-postgresql -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | awk '{print $1}')
logInfo $(oc scale deploy $postgresqlOperatorDeployment --replicas=1)
sleep 30
echo

# Second, scale up common-web-ui, and if stateful set also kafka and zookeeper
logInfo "Scaling up common-web-ui..."
logInfo $(oc scale deploy common-web-ui --replicas=$cp4baCommonWebUiReplicaSize)
if [[ "$(oc get statefulset.apps/iaf-system-zookeeper -o name --ignore-not-found)" != "" ]]; then
  logInfo "Scaling up zookeeper..."
  logInfo $(oc scale statefulset.apps/iaf-system-zookeeper --replicas=$cp4baZookeeperReplicaSize);
fi
if [[ "$(oc get statefulset.apps/iaf-system-kafka -o name --ignore-not-found)" != "" ]]; then
  logInfo "Scaling up kafka..."
  logInfo $(oc scale statefulset.apps/iaf-system-kafka --replicas=$cp4baKafkaReplicaSize);
fi
echo

# Third, Zen's cpdservice needs to be modified to get back all zen pods -> add "flag: true/false"
logInfo "Re-enabling ZEN..."
flag=$(oc get ZenService iaf-zen-cpdservice -o 'custom-columns=NAME:.metadata.name,FLAG:.spec.flag' --no-headers --ignore-not-found | awk '{print $2}')
if [[ $flag == null || $flag == "true" ]]; then
  logInfo $(oc patch ZenService iaf-zen-cpdservice --type merge --patch '{"spec":{"flag":false}}')
else
  logInfo $(oc patch ZenService iaf-zen-cpdservice --type merge --patch '{"spec":{"flag":true}}')
fi
echo

# Fourth, re-enable all suspended cron jobs
logInfo "Re-enabling suspended cron jobs..."
suspendedCronJobs=$(echo $cp4baSuspendedCronJobs | tr "," "\n")
for job in $suspendedCronJobs
do
  logInfo $(oc patch cronJob $job --type merge --patch '{"spec":{"suspend":false}}');
done
echo

logInfo "Environment is scaled up. It will take some time till all needed pods are there and are Running and Ready. Please check in the OCP Web Console. Once all pods are there, pls. check that everything works as expected."
echo
