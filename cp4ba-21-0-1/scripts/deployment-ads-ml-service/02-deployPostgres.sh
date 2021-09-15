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
   
   if [ $adsMlServiceProjectName == "REQUIRED" ] || [ $adsMlServiceImageArchive == "REQUIRED" ] || [ $pgAdminPassword == "REQUIRED" ]; then
      echo "* File ${ADS_ML_SERVICE_INPUT_PROPS_FILENAME} not fully updated. Pls. update all parameters with value REQUIRED."
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
  echo "* Project ${adsMlServiceProjectName} already exists. Switching to it..."
  oc project ${adsMlServiceProjectName}
else
  echo "* Creating project ${adsMlServiceProjectName}..."
  oc new-project ${adsMlServiceProjectName}
fi

echo
if oc get serviceaccount $pgServiceAccount > /dev/null 2>&1; then
    echo "* Postgres Service Account already exists"
else
    echo "* Creating Postgres Service Account"
    oc create serviceaccount $pgServiceAccount
fi

echo
echo "* Configuring Postgres service account to with anyuid Role Binding"
oc adm policy add-scc-to-user anyuid -z $pgServiceAccount

echo
postgresSecretJson=$(oc create secret generic postgres-secret --from-literal postgres-password=$pgAdminPassword --from-literal postgres-user=pgadmin --from-literal pguser=pgadmin --from-literal pgbench-password=$pgAdminPassword --dry-run=true -o json)

if oc get secret postgres-secret > /dev/null 2>&1; then
    echo "* Secret already exists, updating it"
    echo $postgresSecretJson | oc replace -f -
else
    echo "* Creating Postgres Secret"
    echo $postgresSecretJson | oc apply -f -
fi

echo
if oc get pvc postgres > /dev/null 2>&1; then
    echo "* Postgres Storage already exists"
    if [[ "$(oc get pvc postgres -o 'jsonpath={.status.phase}')" != "Bound" ]]; then
	echo "* Postgres Persistent Volume Claim is not bound, please check. Aborting"
        echo
	exit 1
    fi
else
    if oc get storageclass $adsMlServiceStorageClassName > /dev/null 2>&1; then
	echo "* Found Storage Class $adsMlServiceStorageClassName"
    else
	echo "* Storage Class $adsMlServiceStorageClassName is not existing, please create, aborting"
        echo
	exit 1
    fi

    echo "* Creating Postgres PersistentVolumeClaim"
    cat postgres-pvc.yaml | \
	sed "s/:STORAGE-CLASS:/$adsMlServiceStorageClassName/g" | \
	sed "s/:POSTGRES-STORAGE:/$pgPostgresStorage/" | \
	oc apply -f -
    echo "* Waiting for Postgres PersistentVolumeClaim to be bound"

    while [[ "$(oc get pvc postgres -o 'jsonpath={.status.phase}')" != "Bound" ]]; do
	sleep 10
    done
    echo "* Postgres PersistentVolumeClaim is bound"
fi
    
echo
if oc get deploy postgres > /dev/null 2>&1; then
    echo "* Postgres Deployment already exists"
    POSTGRES=$(oc get pod -l app=postgres -oname)
    if [[ "${POSTGRES}" == "" ]]; then
	echo "* No Postgres POD exists, please check, aborting"
        echo
	exit 1
    fi
    echo "* Postgres POD exists: $POSTGRES"

    if [[ "$(oc get ${POSTGRES} -o 'jsonpath={.status.phase}')" != "Running" ]]; then
	echo "* Postgres POD not running, please check, aborting"
        echo
	exit 1
    fi
    echo "* Postgres POD is running"
else
    echo "* Creating new Postgres Deployment and Service"
    oc apply -f postgres.yaml
    echo "* Waiting for Pods to be created"
    sleep 5
    POSTGRES=$(oc get pod -l app=postgres -oname)
    if [[ "${POSTGRES}" == "" ]]; then
	echo "* No Postgres POD exists, please check, aborting"
        echo
	exit 1
    fi
    echo "* Postgres POD exists: $POSTGRES"
    while [[ "$(oc get ${POSTGRES} -o 'jsonpath={.status.phase}')" != "Running" ]]; do
	sleep 10
    done
    echo "* Postgres POD is running"
fi
									     
echo
echo "* Monitor the log output of the Postgres pod and wait until it is initialized."
echo "* Wait for log output:"
echo
echo -e "\x1B[1m        \"LOG:  database system is ready to accept connections\"\x1B[0m"
echo
echo "* before you proceed with creating the database."
echo
