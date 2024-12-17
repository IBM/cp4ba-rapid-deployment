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

# Second, scale down all cp4ba deployments
# TODO: icp4adeploy could be different!
# deployments=$(oc get deploy -o name |grep icp4adeploy)
deployments=$(oc get deploy -o name)
if $DEBUG = true; then
   echo "DEBUG deployments =" $deployments
fi
for i in $deployments; do
   if $DEBUG = true; then
      echo
      echo "DEBUG scaling i =" $i;
      echo
   fi
   oc scale $i --replicas=0;
done

# Third, scale down all cp4ba stateful sets
# TODO: icp4adeploy could be different!
# statefulSets=$(oc get sts -o name |grep icp4adeploy)
statefulSets=$(oc get sts -o name)
if $DEBUG = true; then
   echo "DEBUG statefulSets =" $statefulSets
fi
for i in $statefulSets; do
   if $DEBUG = true; then
      echo
      echo "DEBUG scaling i =" $i;
      echo
   fi
   oc scale $i --replicas=0;
done

echo
