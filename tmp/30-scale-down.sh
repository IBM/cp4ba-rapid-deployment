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

# This script is for scaling down the JiaB environment on TechZone before taking a snapshot, pauses OCP updates and stops SDS
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
echo -e "\x1B[1mThis script SCALES DOWN critical components of the CP4BA deployment in project ${cp4baProjectName}, pauses OCP updates and stops SDS. \n \x1B[0m"

printf "Are ${DB2_INPUT_PROPS_FILENAME} and ${CP4BA_INPUT_PROPS_FILENAME} up to date, and do you want to continue scaling down / stopping? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Scaling down the CP4BA deployment, pausing OCP updates and stopping SDS..."
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



# First, scale down the operators
echo
echo "Scaling down the CP4BA operators..."
oc scale deployment ibm-cp4a-operator --replicas=0
oc scale deployment ibm-content-operator --replicas=0
oc scale deployment ibm-ads-operator --replicas=0
oc scale deployment ibm-cp4a-wfps-operator --replicas=0
oc scale deployment ibm-dpe-operator --replicas=0
oc scale deployment ibm-iam-operator --replicas=0
oc scale deployment ibm-odm-operator --replicas=0
oc scale deployment ibm-pfs-operator --replicas=0
oc scale deployment ibm-zen-operator --replicas=0
# TODO: more operators to be added here?

# TODO: Think about if we want to verify, those pods are really gone. For now, we'll just wait for 30 seconds.
sleep 30
echo



# Second, scale down the CP4BA components that may make trouble when reserving an instance of this environment on TechZone

# BAStudio pods - first scale to 1, wait till all other pods are gone, then scale to 0
echo "Scaling down BAStudio pods to 1..."
oc scale statefulset icp4adeploy-bastudio-deployment --replicas=1
BASTUDIOPOD1=$(oc get pod -l statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-1 -o name)
BASTUDIOPOD2=$(oc get pod -l statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-2 -o name)
GONE=false
while [[ $GONE == false ]]
do
  if [[ $BASTUDIOPOD1 != "" ]] || [[ $BASTUDIOPOD2 != "" ]]; then
    echo "  Waiting..."
    sleep 10
    BASTUDIOPOD1=$(oc get pod -l statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-1 -o name)
    BASTUDIOPOD2=$(oc get pod -l statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-2 -o name)
  else
    GONE=true
    echo "  BAStudio pods scaled to 1"
  fi
done
echo

echo "Scaling down BAStudio pods to 0..."
oc scale statefulset icp4adeploy-bastudio-deployment --replicas=0
BASTUDIOPOD0=$(oc get pod -l statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-0 -o name)
GONE=false
while [[ $GONE == false ]]
do
  if [[ $BASTUDIOPOD0 != "" ]]; then
    echo "  Waiting..."
    sleep 10
    BASTUDIOPOD0=$(oc get pod -l statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-0 -o name)
  else
    GONE=true
    echo "  BAStudio pods scaled to 0"
  fi
done
echo

# Platform service pods need usually a re-start, too
echo "Scaling down platform service pods..."
oc scale deployment platform-auth-service --replicas=0
oc scale deployment platform-identity-provider --replicas=0
oc scale deployment platform-identity-management --replicas=0
AUTHSERVICEPOD=$(oc get pod -l app.kubernetes.io/instance=platform-auth-service -o name)
IDENTITYPROVIDERPOD=$(oc get pod -l app.kubernetes.io/instance=platform-identity-provider -o name)
IDENTITYMANAGEMENTPOD=$(oc get pod -l app.kubernetes.io/instance=platform-identity-management -o name)
GONE=false
while [[ $GONE == false ]]
do
  if [[ $AUTHSERVICEPOD != "" ]] || [[ $IDENTITYPROVIDERPOD != "" ]] || [[ $IDENTITYMANAGEMENTPOD != "" ]]; then
    echo "  Waiting..."
    sleep 10
    AUTHSERVICEPOD=$(oc get pod -l app.kubernetes.io/instance=platform-auth-service -o name)
    IDENTITYPROVIDERPOD=$(oc get pod -l app.kubernetes.io/instance=platform-identity-provider -o name)
    IDENTITYMANAGEMENTPOD=$(oc get pod -l app.kubernetes.io/instance=platform-identity-management -o name)
  else
    GONE=true
    echo "  Platform service pods scaled to 0"
  fi
done
echo

# Pause the OCP updates
echo "Pausing OCP updates..."
oc patch MachineConfigPool master --type merge --patch '{"spec":{"paused":true}}'
oc patch MachineConfigPool worker --type merge --patch '{"spec":{"paused":true}}'
sleep 15
echo

# Finally, stop SDS
echo "Stopping SDS..."
sudo systemctl stop sds
sleep 15
echo



echo "All critical components got scaled down / stopped. Environment is ready for shut-down."
echo
