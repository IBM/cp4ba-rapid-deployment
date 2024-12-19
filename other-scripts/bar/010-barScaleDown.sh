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

# TODO: Instead of a debug flag, we want to write detailed logs into a log file
DEBUG=false

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INPUT_PROPS_FILENAME="001-barParameters.sh"
INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${INPUT_PROPS_FILENAME}"

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   if $DEBUG = true; then
      echo
      echo "Found ${INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   else
      echo
   fi
   
   . $INPUT_PROPS_FILENAME_FULL
   
   if [ $cp4baProjectName == "REQUIRED" ] || [ "$cp4baTlsSecretName" == "REQUIRED" ] || [ $cp4baAdminPassword == "REQUIRED" ] || [ $ldapAdminPassword == "REQUIRED" ] || [ $ldapServer == "REQUIRED" ]; then
      echo "File ${INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 0
   fi

   if $DEBUG = true; then
      echo "Done!"
   fi
else
   echo
   echo "File ${INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 0
fi

echo
echo -e "\x1B[1mThis script prepares namespace ${cp4baProjectName} for taking a backup. It scales down all pods to zero. \n \x1B[0m"

printf "Do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
   echo
   echo -e "Ok, scaling down the CP4BA deployment in namespace ${cp4baProjectName}..."
   echo
   ;;
*)
   echo
   echo -e "Exiting..."
   echo
   exit 0
   ;;
esac

if $DEBUG = true; then
   echo "Verifying OC CLI is connected to the OCP cluster..."
fi
WHOAMI=$(oc whoami)
if $DEBUG = true; then
   echo
   echo "DEBUG WHOAMI =" $WHOAMI
   echo
fi

if [[ "$WHOAMI" == "" ]]; then
   echo "OC CLI is NOT connected to the OCP cluster. Please log in first with user \"ocadmin\" to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
   echo
   exit 0
fi

if $DEBUG = true; then
   echo "Switching to project ${cp4baProjectName}..."
fi
project=$(oc project --short)
if $DEBUG = true; then
   echo
   echo "DEBUG project =" $project
   echo
fi
if [[ "$project" != "$cp4baProjectName" ]]; then
   oc project $cp4baProjectName
   echo
fi



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
oc scale deploy ibm-cp4a-operator --replicas=0
oc scale deploy ibm-cp4a-wfps-operator-controller-manager --replicas=0
oc scale deploy iaf-core-operator-controller-manager --replicas=0
oc scale deploy iaf-eventprocessing-operator-controller-manager --replicas=0
oc scale deploy iaf-flink-operator-controller-manager --replicas=0
oc scale deploy iaf-insights-engine-operator-controller-manager --replicas=0
oc scale deploy iaf-operator-controller-manager --replicas=0
oc scale deploy ibm-bts-operator-controller-manager --replicas=0
oc scale deploy ibm-elastic-operator-controller-manager --replicas=0
oc scale deploy nginx-ingress-controller --replicas=0
oc scale deploy postgresql-operator-controller-manager-1-18-12 --replicas=0
oc scale deploy ibm-zen-operator --replicas=0
oc scale deploy ibm-platform-api-operator --replicas=0
oc scale deploy ibm-namespace-scope-operator --replicas=0
oc scale deploy ibm-mongodb-operator --replicas=0
oc scale deploy ibm-management-ingress-operator --replicas=0
oc scale deploy ibm-ingress-nginx-operator --replicas=0
oc scale deploy ibm-iam-operator --replicas=0
oc scale deploy ibm-events-operator-v5.0.1 --replicas=0
oc scale deploy ibm-commonui-operator --replicas=0
oc scale deploy ibm-common-service-operator --replicas=0
oc scale deploy iaf-system-entity-operator --replicas=0
oc scale deploy iam-policy-controller --replicas=0
sleep 10
echo

# Second, suspend all cron jobs
if $DEBUG = true; then
   echo "DEBUG Suspending cron jobs..."
fi
cronJobs=$(oc get cronjob -o 'custom-columns=NAME:.metadata.name,SUSPEND:.spec.suspend' --no-headers --ignore-not-found | grep 'false' | awk '{print $1}')
if $DEBUG = true; then
   echo "DEBUG cronJobs =" $cronJobs
   echo
fi
for i in $cronJobs; do
   if $DEBUG = true; then
      echo "DEBUG suspending i =" $i;
      echo
   fi
   # TODO: How to keep track of the cron jobs that we suspended?
   oc patch cronJob $i --type merge --patch '{"spec":{"suspend":true}}';
done

# Third, scale down all deployments
# TODO: We want to be more speciffic here, scale down only the deployments we are aware of, not all.
deployments=$(oc get deploy -o name)
if $DEBUG = true; then
   echo "DEBUG deployments =" $deployments
   echo
fi
for i in $deployments; do
   if $DEBUG = true; then
      echo "DEBUG scaling i =" $i;
      echo
   fi
   oc scale $i --replicas=0;
done

# Fourth, scale down all stateful sets
# TODO: We want to be more speciffic here, scale down only the stateful sets we are aware of, not all.
statefulSets=$(oc get sts -o name)
if $DEBUG = true; then
   echo "DEBUG statefulSets =" $statefulSets
   echo
fi
for i in $statefulSets; do
   if $DEBUG = true; then
      echo "DEBUG scaling i =" $i;
      echo
   fi
   oc scale $i --replicas=0;
done

# Fifth, delete all remaing running pods that we know
# TODO: This section most likely needs a more flexible approach. What when a customer has 5 or more kafka pods? Same for the other pods deleted here.
# We want to first query for all those pods and then delete those that are existing.
oc delete pod iaf-system-kafka-2
oc delete pod iaf-system-kafka-1
sleep 10
oc delete pod iaf-system-kafka-0
sleep 10
oc delete pod iaf-system-zookeeper-2
oc delete pod iaf-system-zookeeper-1
sleep 10
oc delete pod iaf-system-zookeeper-0
sleep 10
oc delete pod ibm-bts-cnpg-ibm-cp4ba-cp4ba-bts-2
sleep 10
oc delete pod ibm-bts-cnpg-ibm-cp4ba-cp4ba-bts-1
sleep 10
rrpods=$(oc get pod -l=app.kubernetes.io/name=resource-registry --no-headers --ignore-not-found | awk '{print $1}')
for pod in ${rrpods[*]}
do
  oc delete pod $pod
done

# Sixth, delete all completed pods
if $DEBUG = true; then
   echo "DEBUG Deleting completed pods"
   echo
fi
completedpods=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase' --no-headers --ignore-not-found | grep 'Succeeded' | awk '{print $1}')
if $DEBUG = true; then
   echo "DEBUG completedpods = " $completedpods
   echo
fi
for i in $completedpods; do
   if $DEBUG = true; then
      echo "DEBUG deleting i =" $i;
      echo
   fi
   oc delete pod $i
done

# Seventh, check if there are some pods remaining
# TODO

echo
