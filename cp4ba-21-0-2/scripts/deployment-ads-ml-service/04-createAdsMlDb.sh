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
echo "* Configuring ADS ML Service Database in Postgres deployment"
POSTGRES=$(oc get pod -l app=postgres -oname | sed s,pod/,,g)
if [[ "${POSTGRES}" == "" ]]; then
    echo "* No Postgres POD exists, please check. Exiting..."
    echo
    exit 1
fi

echo "* Postgres POD exists: $POSTGRES"

PGDBS=$(oc exec $POSTGRES -- bash -c "psql -c '\l'" )
if [[ "${PGDBS}" =~ "mlserving" ]]; then
    echo "* Postgres mlserving Database already exists. Exiting..."
    echo
    exit 1
else
    oc cp createMlServingDatabase.sh $POSTGRES:/tmp/
    oc exec $POSTGRES -- bash -c "chmod +x /tmp/createMlServingDatabase.sh"
    oc exec $POSTGRES -- bash -c "/tmp/createMlServingDatabase.sh"
    echo
    echo "* Existing databases are:"
    oc exec $POSTGRES -- bash -c "psql -c '\l'" 
fi

echo "* Done. Exiting..."
echo
