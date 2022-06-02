#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ADS_ML_SERVICE_INPUT_PROPS_FILENAME="01-parametersForAdsMlService.sh"
ADS_ML_SERVICE_INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${ADS_ML_SERVICE_INPUT_PROPS_FILENAME}"

if [[ -f $ADS_ML_SERVICE_INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "* Found ${ADS_ML_SERVICE_INPUT_PROPS_FILENAME}. Reading in variables from that script."
   . $ADS_ML_SERVICE_INPUT_PROPS_FILENAME
   
   if [[ $adsMlServiceProjectName == "" ]]; then
      echo "* File ${ADS_ML_SERVICE_INPUT_PROPS_FILENAME} not updated. Pls. update."
      echo
      exit 1
   fi
   
   echo "* Done!"
else
   echo
   echo "* File ${ADS_ML_SERVICE_INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 1
fi

echo
echo -e "\x1B[1m* This script DELETES the ADS ML Service and Postgress deployment running in project ${adsMlServiceProjectName}. \n \x1B[0m"

printf "* Do you want to continue (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "* Deleting the ADS ML Service and Postgress deployment..."
    ;;
*)
    echo
    echo -e "* Exiting..."
    echo
    exit 1
    ;;
esac

echo
if oc get project $adsMlServiceProjectName > /dev/null 2>&1; then
  echo "* Project ${adsMlServiceProjectName} exists. Switching to it..."
  oc project ${adsMlServiceProjectName}
else
  echo "* Project ${adsMlServiceProjectName} not found. Exiting..."
  echo
  exit 1
fi

echo
echo "* Deleting the ADS ML Service..."
oc delete -f networkpolicy.yaml
oc delete route ads-ml-service-service
oc delete -f service.yaml
oc delete -f deployment.yaml
oc delete -f configMap.yaml

echo
echo "* Deleting Postgress deployment, service, pvc, secret and serviceaccount..."
pgDeploymentDir=../../../deployment/postgres
PG_DEPLOYMENT_DIR=$(cd ${CUR_DIR}/${pgDeploymentDir}; pwd)

oc delete -f $PG_DEPLOYMENT_DIR/postgres.yaml

oc delete pvc postgres

oc delete secret postgres-secret

oc delete serviceaccount $pgServiceAccount

echo
echo "* Done. Exiting..."
echo
