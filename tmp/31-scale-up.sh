#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2024. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# This script is for scaling up the JiaB environment on TechZone before being able to use it
#    CP4BA version: 23.0.2 IF002
#    CP4BA template used for deployment: ibm_cp4a_cr_template.201.ent.ClientOnboardingDemoWithADPOneDB.yaml

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DB2_INPUT_PROPS_FILENAME="01-parametersForDb2OnOCP.sh"
DB2_INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${DB2_INPUT_PROPS_FILENAME}"

if [[ -f $DB2_INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${DB2_INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   . $DB2_INPUT_PROPS_FILENAME_FULL
   
   echo "Done!"
else
   echo
   echo "File ${DB2_INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 0
fi

CP4BA_INPUT_PROPS_FILENAME="05-parametersForCp4ba.sh"
CP4BA_INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${CP4BA_INPUT_PROPS_FILENAME}"

if [[ -f $CP4BA_INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${CP4BA_INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   . $CP4BA_INPUT_PROPS_FILENAME_FULL
   
   if [ $cp4baProjectName == "REQUIRED" ] || [ "$cp4baTlsSecretName" == "REQUIRED" ] || [ $cp4baAdminPassword == "REQUIRED" ] || [ $ldapAdminPassword == "REQUIRED" ] || [ $ldapServer == "REQUIRED" ]; then
      echo "File ${CP4BA_INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 0
   fi

   echo "Done!"
else
   echo
   echo "File ${CP4BA_INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 0
fi

echo
echo -e "\x1B[1mThis script SCALES UP the CP4BA deployment in project ${cp4baProjectName}. \n \x1B[0m"

printf "Are ${DB2_INPUT_PROPS_FILENAME} and ${CP4BA_INPUT_PROPS_FILENAME} up to date, and do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Scaling up the CP4BA deployment..."
    ;;
*)
    echo
    echo -e "Exiting..."
    echo
    exit 0
    ;;
esac

echo
echo "Verifying OC CLI is connected to the OCP cluster..."
WHOAMI=$(oc whoami)

if [[ $WHOAMI != "ocadmin" ]]; then
  echo "OC CLI is NOT connected to the OCP cluster. Please log in first with user \"ocadmin\" to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
  echo
  exit 0
fi

echo
echo "Switching to project ${cp4baProjectName}..."
oc project $cp4baProjectName
echo



# First, start SDS
echo "Re-starting SDS..."
sudo systemctl stop sds
sudo systemctl start sds
sleep 15
echo



# Second, resume the OCP updates
echo "Resuming OCP updates..."
oc patch MachineConfigPool master --type merge --patch '{"spec":{"paused":false}}'
oc patch MachineConfigPool worker --type merge --patch '{"spec":{"paused":false}}'
sleep 15
echo



# Third, start the pods of the CP4BA deployment that got scaled down before

# Scale up the platform services
echo "Scaling up platform services..."
# TODO: Needs changes when zen and common-service are properly scaled up, replicas then will be larger than 1
oc scale deployment platform-auth-service --replicas=1
oc scale deployment platform-identity-provider --replicas=1
oc scale deployment platform-identity-management --replicas=1
authservicepodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-auth-service -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
identityproviderpodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-identity-provider -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
identitymanagementpodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-identity-management -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
RUNNINGANDREADY=false
while [[ $RUNNINGANDREADY == false ]]
do
  if [[ $authservicepodCount = 0 ]] || [[ $identityproviderpodCount = 0 ]] || [[ $identitymanagementpodCount = 0 ]]; then
    echo "  Waiting..."
    sleep 10
    authservicepodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-auth-service -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
    identityproviderpodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-identity-provider -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
    identitymanagementpodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-identity-management -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
  else
    echo "  Pods platform-auth-service, platform-identity-provider and platform-identity-management are Running and Ready."
    RUNNINGANDREADY=true
  fi
done
echo

# BAStudio pods - first scale to 1, wait till pod -0 is Running and ready, then scale to 2
echo "Scaling up BAStudio pods to 1..."
oc scale statefulset icp4adeploy-bastudio-deployment --replicas=1
BASTUDIOPOD0COUNT=$(oc get pod -l=statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-0 -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
RUNNINGANDREADY=false
while [[ $RUNNINGANDREADY == false ]]
do
  if [[ $BASTUDIOPOD0COUNT = 0 ]]; then
    echo "  Waiting..."
    sleep 10
    BASTUDIOPOD0COUNT=$(oc get pod -l=statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-0 -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
  else
    echo "  Pod icp4adeploy-bastudio-deployment-0 is Running and Ready."
    RUNNINGANDREADY=true
  fi
done
echo

echo "Scaling up BAStudio pods to 2..."
oc scale statefulset icp4adeploy-bastudio-deployment --replicas=2
BASTUDIOPOD1COUNT=$(oc get pod -l=statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-1 -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
RUNNINGANDREADY=false
while [[ $RUNNINGANDREADY == false ]]
do
  if [[ $BASTUDIOPOD1COUNT = 0 ]]; then
    echo "  Waiting..."
    sleep 10
    BASTUDIOPOD1COUNT=$(oc get pod -l=statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-1 -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}' | wc -l)
  else
    echo "  Pod icp4adeploy-bastudio-deployment-1 is Running and Ready."
    RUNNINGANDREADY=true
  fi
done
echo

# Finally, scale up the operators
echo
echo "Scaling up the CP4BA operators..."
oc scale deployment ibm-zen-operator --replicas=1
oc scale deployment ibm-iam-operator --replicas=1
oc scale deployment ibm-content-operator --replicas=1
oc scale deployment ibm-ads-operator --replicas=1
oc scale deployment ibm-cp4a-wfps-operator --replicas=1
oc scale deployment ibm-dpe-operator --replicas=1
oc scale deployment ibm-odm-operator --replicas=1
oc scale deployment ibm-pfs-operator --replicas=1
oc scale deployment ibm-cp4a-operator --replicas=1
# TODO: more operators to be added here?

# TODO: Think about if we want to verify, those pods are really Running and Ready. For now, we'll just wait for 30 seconds.
sleep 30
echo



echo "All critical components got scaled up / started. Environment is ready for final manual verification and usage."
echo
