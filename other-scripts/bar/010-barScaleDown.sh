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
  backupFile=$BACKUP_ROOT_DIRECTORY_FULL/properties_$(date +'%Y%m%d_%H%M%S').bak
  logInfo "Old properties file found. Moving it to" $backupFile
  mv $propertiesfile $backupFile
fi
logInfo "Persisting scale down information in" $propertiesfile
cp ${CUR_DIR}/templates/properties.template.sh $propertiesfile

# Persist the project for which this backup is
sed -i.bak "s|§cp4baProjectNamespace|$cp4baProjectName|g" $propertiesfile

# Persist the replica size of the common-web-ui deployment
commonWebUiReplicas=$(oc get pod -l=app.kubernetes.io/name=common-web-ui -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
sed -i.bak "s|§cp4baCommonWebUiReplicaSize|$commonWebUiReplicas|g" $propertiesfile
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
logInfo $(oc scale deploy ibm-zen-operator --replicas=0)
logInfo $(oc scale deploy ibm-platform-api-operator --replicas=0)
logInfo $(oc scale deploy ibm-namespace-scope-operator --replicas=0)
logInfo $(oc scale deploy ibm-mongodb-operator --replicas=0)
logInfo $(oc scale deploy ibm-management-ingress-operator --replicas=0)
logInfo $(oc scale deploy ibm-ingress-nginx-operator --replicas=0)
logInfo $(oc scale deploy ibm-iam-operator --replicas=0)
logInfo $(oc scale deploy ibm-commonui-operator --replicas=0)
logInfo $(oc scale deploy ibm-common-service-operator --replicas=0)
# not always deployed
if oc get deployment iaf-system-entity-operator > /dev/null 2>&1; then
  logInfo $(oc scale deploy iaf-system-entity-operator --replicas=0)
fi
logInfo $(oc scale deploy iam-policy-controller --replicas=0)
logInfo $(oc scale deploy operand-deployment-lifecycle-manager --replicas=0)

# these two operator deployments do have the version in their name, therefore we have to get the deployment name first
eventsOperatorDeployment=$(oc get deployment -o 'custom-columns=NAME:.metadata.name,SELECTOR:.spec.selector.matchLabels.name' --no-headers --ignore-not-found | grep 'ibm-events-operator' | awk '{print $1}')
# not always deployed
if [[ "$eventsOperatorDeployment" != "" ]]; then
  logInfo $(oc scale deploy $eventsOperatorDeployment --replicas=0)
fi
postgresqlOperatorDeployment=$(oc get deployment -l=app.kubernetes.io/name=cloud-native-postgresql -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | awk '{print $1}')
logInfo $(oc scale deploy $postgresqlOperatorDeployment --replicas=0)
sleep 10
echo

# Now, drain the system by disabling the nginx
logInfo "Draining system by scaling deployment = ibm-nginx"
logInfo $(oc scale deployment ibm-nginx --replicas=0)
sleep 30
echo

# Second, suspend all cron jobs
logInfo "Suspending cron jobs..."
cronJobs=$(oc get cronjob -o 'custom-columns=NAME:.metadata.name,SUSPEND:.spec.suspend' --no-headers --ignore-not-found | grep 'false' | awk '{print $1}')
cronJobsProperty=""
logInfo "cronJobs =" $cronJobs
for i in $cronJobs; do
   if [[ $cronJobsProperty = "" ]]; then
     cronJobsProperty="$i"
   else
     cronJobsProperty="$cronJobsProperty,$i"
   fi
   logInfo "suspending cron job=" $i;
   logInfo $(oc patch cronJob $i --type merge --patch '{"spec":{"suspend":true}}');
done
sed -i.bak "s|§cp4baSuspendedCronJobs|$cronJobsProperty|g" $propertiesfile
echo

# Third, scale down all deployments
# TODO: We want to be more specific here, scale down only the deployments we are aware of, not all.
logInfo "Scaling down deployments..."
deployments=$(oc get deploy -o name)
logInfo "deployments =" $deployments
for i in $deployments; do
   if [[ "$i" == "deployment.apps/iaf-insights-engine-management" ]]; then
     # Don't scale down now, needed while backup
     logInfo "not scaled = $i"
   else
     logInfo "scaling deployment =" $i
     logInfo $(oc scale $i --replicas=0)
   fi
done
echo

# Fourth, scale down all stateful sets
# TODO: We want to be more specific here, scale down only the stateful sets we are aware of, not all.
logInfo "Scaling down stateful sets..."
statefulSets=$(oc get sts -o name)
kafkaIsSTS=false
kafkaReplicas=0
zookeeperIsSTS=false
zookeeperReplicas=0
logInfo "statefulSets =" $statefulSets
for s in $statefulSets; do
   if [[ "$s" == "statefulset.apps/iaf-system-elasticsearch-es-data" || "$s" == "statefulset.apps/icp-mongodb" || "$s" == "statefulset.apps/zen-metastoredb" ]]; then
     # Don't scale down now, needed while backup
     logInfo "Required for backup. Not scaled = $s"
   elif [[ "$s" == "statefulset.apps/iaf-system-kafka" ]]; then
     # Scale down kafka to one only, needed while backup
     kafkaReplicas=$(oc get $s -o 'custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas' --no-headers --ignore-not-found | awk '{print $2}')
     sed -i.bak "s|§cp4baKafkaReplicaSize|$kafkaReplicas|g" $propertiesfile
     logInfo "Scaling stateful set to 1 =" $s
     logInfo $(oc scale $s --replicas=1)
     kafkaIsSTS=true
   elif [[ "$s" == "statefulset.apps/iaf-system-zookeeper" ]]; then
     # Scale down zookeeper to one only, needed while backup
     zookeeperReplicas=$(oc get $s -o 'custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas' --no-headers --ignore-not-found | awk '{print $2}')
     sed -i.bak "s|§cp4baZookeeperReplicaSize|$zookeeperReplicas|g" $propertiesfile
     logInfo "Scaling stateful set to 1 =" $s
     logInfo $(oc scale $s --replicas=1)
     zookeeperIsSTS=true
   else
     logInfo "Scaling stateful set =" $s
     logInfo $(oc scale $s --replicas=0)
   fi
done
echo

# Fifth, delete all remaing running pods that we know
logInfo "Deleting all remaing running CP4BA pods..."
if [[ "$kafkaIsSTS" = "false" ]]; then
  kafkapods=$(oc get pod -l=app.kubernetes.io/name=kafka --no-headers --ignore-not-found | awk '{print $1}')
  for pod in ${kafkapods[*]}
  do
    # Don't scale down kafka-0 pod now, needed while backup
    if [[ "$pod" != "iaf-system-kafka-0" ]]; then
      logInfo $(oc delete pod $pod)
    fi
  done
  sleep 10
fi

if [[ "$zookeeperIsSTS" = "false" ]]; then
  zookeeperpods=$(oc get pod -l=app.kubernetes.io/name=zookeeper --no-headers --ignore-not-found | awk '{print $1}')
  for pod in ${zookeeperpods[*]}
  do
    # Don't scale down zookeeper-0 pod now, needed while backup
    if [[ "$pod" != "iaf-system-zookeeper-0" ]]; then
      logInfo $(oc delete pod $pod)
    fi
  done
  sleep 10
fi

btscnpgpods=$(oc get pod -l=app.kubernetes.io/name=ibm-bts-cp4ba-bts --no-headers --ignore-not-found | awk '{print $1}')
for pod in ${btscnpgpods[*]}
do
  # Don't scale down ibm-bts-cp4ba-bts-1 pod now, needed while backup
  if [[ "$pod" != "ibm-bts-cnpg-"$cp4baProjectName"-cp4ba-bts-1" ]]; then
    logInfo $(oc delete pod $pod)
  fi
done
sleep 10

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

rm $propertiesfile.bak

logInfo "Environment is scaled down. You now can take a backup of this project."
echo
