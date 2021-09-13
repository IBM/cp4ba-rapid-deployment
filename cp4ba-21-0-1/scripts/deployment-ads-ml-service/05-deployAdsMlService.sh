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
if oc get project $adsMlServiceProjectName > /dev/null 2>&1; then
  echo "* Project ${adsMlServiceProjectName} exists. Switching to it..."
  oc project ${adsMlServiceProjectName}
else
  echo "* Project ${adsMlServiceProjectName} not found. Exiting..."
  echo
  exit 1
fi

echo
echo "* Deploying the ads ml service config map..."
oc apply -f configMap.yaml

echo
echo "Deploying the ads ml service deployment..."
cp adsMlServiceDeployment.template.yaml adsMlServiceDeployment.yaml
sed -i "s|adsMlServiceReplicaCount|$adsMlServiceReplicaCount|g" adsMlServiceDeployment.yaml
sed -i "s|pgAdminPassword|$pgAdminPassword|g" adsMlServiceDeployment.yaml
sed -i "s|adsMlServiceProjectName|$adsMlServiceProjectName|g" adsMlServiceDeployment.yaml
oc apply -f adsMlServiceDeployment.yaml

echo
echo "Deploying the ads ml service service..."
oc apply -f service.yaml

echo
echo "Exposing the ads ml service service..."
oc expose service ads-ml-service-service

echo
echo "Deploying the network policy..."
oc apply -f networkpolicy.yaml

echo
echo "* Done. Exiting..."
echo
