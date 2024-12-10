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
INPUT_PROPS_FILENAME="001-barParameters.sh"
INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${INPUT_PROPS_FILENAME}"

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   . $INPUT_PROPS_FILENAME_FULL
   
   if [ $cp4baProjectName == "REQUIRED" ] || [ "$cp4baTlsSecretName" == "REQUIRED" ] || [ $cp4baAdminPassword == "REQUIRED" ] || [ $ldapAdminPassword == "REQUIRED" ] || [ $ldapServer == "REQUIRED" ]; then
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

echo
echo -e "\x1B[1mThis script prepares namespace ${cp4baProjectName} for taking a backup. It scales down all pods to zero. \n \x1B[0m"

printf "Do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Scaling down the CP4BA deployment..."
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

# TODO: ocadmin will not be there in other environments! Needs a different solution.
if [[ $WHOAMI != "ocadmin" ]]; then
  echo "OC CLI is NOT connected to the OCP cluster. Please log in first with user \"ocadmin\" to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
  echo
  exit 0
fi

echo
echo "Switching to project ${cp4baProjectName}..."
oc project $cp4baProjectName
echo



# First, scale down all relevant deployments
oc scale deploy ibm-cp4a-operator --replicas=0
oc scale deploy ibm-pfs-operator  --replicas=0
oc scale deploy ibm-content-operator  --replicas=0
for i in 'oc get deploy -o name |grep icp4adeploy'; do oc scale $i --replicas=0; done
for i in 'oc get sts -o name |grep icp4adeploy'; do oc scale $i --replicas=0; done
oc scale sts zen-metastoredb --replicas=0
