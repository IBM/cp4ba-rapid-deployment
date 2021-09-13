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
CP4BA_INPUT_PROPS_FILENAME="05-parametersForCp4ba.sh"
CP4BA_INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${CP4BA_INPUT_PROPS_FILENAME}"

if [[ -f $CP4BA_INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${CP4BA_INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   . $CP4BA_INPUT_PROPS_FILENAME_FULL
   
   if [ $cp4baProjectName == "REQUIRED" ] || [ $cp4baOcpHostname == "REQUIRED" ] || [ "$cp4baTlsSecretName" == "REQUIRED" ] || [ $cp4baAdminPassword == "REQUIRED" ] || [ $cp4baUmsAdminPassword == "REQUIRED" ] || [ $ldapAdminPassword == "REQUIRED" ] || [ $ldapServer == "REQUIRED" ]; then
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
echo "Switching to project ${cp4baProjectName}..."
oc project $cp4baProjectName

echo
echo "Preparing the AutomationUIConfig CR & Cartridge CR for deployment..."

cp automationUIConfig.template.yaml automationUIConfig.yaml
cp cartridge.template.yaml cartridge.yaml

sed -i.bak "s|cp4baProjectName|$cp4baProjectName|g" automationUIConfig.yaml
sed -i.bak "s|cp4baScFast|$cp4baScFast|g" automationUIConfig.yaml

sed -i.bak "s|cp4baProjectName|$cp4baProjectName|g" cartridge.yaml

echo
echo "Creating the AutomationUIConfig & Cartridge deployment..."
oc apply -f automationUIConfig.yaml
oc apply -f cartridge.yaml
echo "Done."

echo
echo "All changes got applied. Exiting..."
echo
