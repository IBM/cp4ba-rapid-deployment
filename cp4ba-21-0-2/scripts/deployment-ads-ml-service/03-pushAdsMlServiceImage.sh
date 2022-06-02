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
oc project openshift-image-registry
imageRegistryRoute=$(oc get route image-registry -o 'jsonpath={.spec.host}')
if [[ $imageRegistryRoute == "" ]]; then
  oc create route reencrypt --service=image-registry
  imageRegistryRoute=$(oc get route image-registry -o 'jsonpath={.spec.host}')
fi
echo "* Route: ${imageRegistryRoute}"

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
echo "* Docker login"
docker login $imageRegistryRoute -u $(oc whoami) -p $(oc whoami -t)
echo
echo "* Docker load"
docker load -i $adsMlServiceImageArchive
echo
echo "* Docker tag"
docker tag ads-ml-service:latest $imageRegistryRoute/$adsMlServiceProjectName/ads-ml-service:latest
echo
echo "* Docker push"
docker push $imageRegistryRoute/$adsMlServiceProjectName/ads-ml-service:latest
echo
echo "* Docker rmi"
docker rmi ads-ml-service:latest -f

echo
echo "* Done. Exiting..."
echo
