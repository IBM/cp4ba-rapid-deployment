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

# This script is for preparing the Backup And Restore (BAR) process, scaling down all CP4BA components in the given namespace.
#    Only tested with CP4BA version: 21.0.3 IF034, dedicated common services set-up

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import common utilities
source ${CUR_DIR}/common.sh

INPUT_PROPS_FILENAME="001-barParameters.sh"
INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${INPUT_PROPS_FILENAME}"

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   
   . $INPUT_PROPS_FILENAME_FULL
   
   if [ $cp4baProjectName == "REQUIRED" ]; then
      echo "File ${INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 0
   fi

   echo "Done!"
else
   echo
   echo "File ${INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 0
fi

BACKUP_ROOT_DIRECTORY_FULL="${CUR_DIR}/${cp4baProjectName}"
if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo
else
   echo
   mkdir "$BACKUP_ROOT_DIRECTORY_FULL"
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/ScaleDownForBackup_$(date +'%Y%m%d_%H%M%S').log"
logInfo "Details will be logged to $LOG_FILE."

echo
echo -e "\x1B[1mThis script prepares namespace ${cp4baProjectName} for taking a backup. It scales down all pods to zero. \n \x1B[0m"

printf "Do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
   echo
   logInfo "Ok, scaling down the CP4BA deployment in namespace ${cp4baProjectName}..."
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
   exit 0
fi
echo

project=$(oc project --short)
logInfo "project =" $project
if [[ "$project" != "$cp4baProjectName" ]]; then
   logInfo "Switching to project ${cp4baProjectName}..."
   logInfo $(oc project $cp4baProjectName)
fi
echo



# Step Zero:
#   - Maybe have a separate script for all these checks that needs to be run first
#   - Do some checks if this is really a CP4BA deployment
#   - Check the CP4BA version number, atm only CP4BA v21.0.3 is supported
#   - Check the deployed CP4BA components, atm only Content, BAW and BAI are supported
#   - Check that everything is healthy atm, we only proceed if all pods are in Running or Completed state
#   - There is no unexpected stuff running in the project
#   - Check that dedicated common services is used
#   - Any other checks needed?
# TODO

# TODO: How to keep track of all changes done? So that when scaling up later, all things that where "scaled down" here, get "scaled up" later on?
# For example, number of pods to scale up to, or cron jobs that got suspended, to only enable those again that where active initially?

# TODO: We on TechZone only have an authoring environment available. CTIE will also have Process Server environments where other pods / resources are there.
# All bar scripts need to be tested with non-authoring environments, too.

# First, scale down all operators
logInfo "Scaling down operators..."
logInfo $(oc scale deploy ibm-cp4a-operator --replicas=0)
logInfo $(oc scale deploy ibm-cp4a-wfps-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-core-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-eventprocessing-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-flink-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-insights-engine-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy iaf-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy ibm-bts-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy ibm-elastic-operator-controller-manager --replicas=0)
logInfo $(oc scale deploy nginx-ingress-controller --replicas=0)
logInfo $(oc scale deploy postgresql-operator-controller-manager-1-18-12 --replicas=0)
logInfo $(oc scale deploy ibm-zen-operator --replicas=0)
logInfo $(oc scale deploy ibm-platform-api-operator --replicas=0)
logInfo $(oc scale deploy ibm-namespace-scope-operator --replicas=0)
logInfo $(oc scale deploy ibm-mongodb-operator --replicas=0)
logInfo $(oc scale deploy ibm-management-ingress-operator --replicas=0)
logInfo $(oc scale deploy ibm-ingress-nginx-operator --replicas=0)
logInfo $(oc scale deploy ibm-iam-operator --replicas=0)
logInfo $(oc scale deploy ibm-events-operator-v5.0.1 --replicas=0)
logInfo $(oc scale deploy ibm-commonui-operator --replicas=0)
logInfo $(oc scale deploy ibm-common-service-operator --replicas=0)
logInfo $(oc scale deploy iaf-system-entity-operator --replicas=0)
logInfo $(oc scale deploy iam-policy-controller --replicas=0)
sleep 10
echo

# Second, suspend all cron jobs
logInfo "Suspending cron jobs..."
cronJobs=$(oc get cronjob -o 'custom-columns=NAME:.metadata.name,SUSPEND:.spec.suspend' --no-headers --ignore-not-found | grep 'false' | awk '{print $1}')
logInfo "cronJobs =" $cronJobs
for i in $cronJobs; do
   logInfo "suspending cron job=" $i;
   # TODO: How to keep track of the cron jobs that we suspended?
   logInfo $(oc patch cronJob $i --type merge --patch '{"spec":{"suspend":true}}');
done
echo

# Third, scale down all deployments
# TODO: We want to be more speciffic here, scale down only the deployments we are aware of, not all.
logInfo "Scaling down deployments..."
deployments=$(oc get deploy -o name)
logInfo "deployments =" $deployments
for i in $deployments; do
   logInfo "scaling deployment =" $i;
   logInfo $(oc scale $i --replicas=0);
done
echo

# Fourth, scale down all stateful sets
# TODO: We want to be more speciffic here, scale down only the stateful sets we are aware of, not all.
logInfo "Scaling down stateful sets..."
statefulSets=$(oc get sts -o name)
logInfo "statefulSets =" $statefulSets
for i in $statefulSets; do
   logInfo "scaling stateful set =" $i;
   logInfo $(oc scale $i --replicas=0);
done
echo

# Fifth, delete all remaing running pods that we know
# TODO: This section most likely needs a more flexible approach. What when a customer has 5 or more kafka pods? Same for the other pods deleted here.
# We want to first query for all those pods and then delete those that are existing.
logInfo "Deleting all remaing running CP4BA pods..."
logInfo $(oc delete pod iaf-system-kafka-2)
logInfo $(oc delete pod iaf-system-kafka-1)
sleep 10
logInfo $(oc delete pod iaf-system-kafka-0)
sleep 10
logInfo $(oc delete pod iaf-system-zookeeper-2)
logInfo $(oc delete pod iaf-system-zookeeper-1)
sleep 10
logInfo $(oc delete pod iaf-system-zookeeper-0)
sleep 10
logInfo $(oc delete pod ibm-bts-cnpg-ibm-cp4ba-cp4ba-bts-2)
sleep 10
# Do not delete the bts-1 pod yet, will be needed to backup the db, once done it'll be deleted
# logInfo $(oc delete pod ibm-bts-cnpg-ibm-cp4ba-cp4ba-bts-1)
# sleep 10
rrpods=$(oc get pod -l=app.kubernetes.io/name=resource-registry --no-headers --ignore-not-found | awk '{print $1}')
for pod in ${rrpods[*]}
do
   logInfo $(oc delete pod $pod)
done
echo

# Sixth, delete all completed pods
logInfo "Deleting completed pods..."
completedpods=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase' --no-headers --ignore-not-found | grep 'Succeeded' | awk '{print $1}')
logInfo "completed pods = " $completedpods
for i in $completedpods; do
   logInfo "deleting pod =" $i;
   logInfo $(oc delete pod $i)
done
echo

# Seventh, check if there are some pods remaining
# TODO

echo
