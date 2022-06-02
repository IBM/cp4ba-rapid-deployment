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
   
   if [[ $cp4baProjectName == "" ]]; then
      echo "File ${CP4BA_INPUT_PROPS_FILENAME} not updated. Pls. update."
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
echo -e "\x1B[1mThis script DELETES the current CP4BA deployment (ibm_cp4a_cr_final.yaml) in project ${cp4baProjectName}. \n \x1B[0m"

printf "Do you want to continue (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Deleting the current CP4BA deployment..."
    ;;
*)
    echo
    echo -e "Exiting..."
    echo
    exit 0
    ;;
esac

echo
echo "Switching to project ${cp4baProjectName}..."
oc project $cp4baProjectName

echo
echo "Deleting the current deployment..."
oc delete -f ibm_cp4a_cr_final.yaml
sleep 30

echo
echo "Deleting the PVCs..."
oc delete pvc icn-asperastore
oc delete pvc icn-cfgstore
oc delete pvc icn-logstore
oc delete pvc icn-pluginstore
oc delete pvc icn-vw-cachestore
oc delete pvc icn-vw-logstore

oc delete pvc cmis-cfgstore
oc delete pvc cmis-logstore

oc delete pvc cpe-bootstrapstore
oc delete pvc cpe-cfgstore
oc delete pvc cpe-filestore
oc delete pvc cpe-fnlogstore
oc delete pvc cpe-icmrulesstore
oc delete pvc cpe-logstore
oc delete pvc cpe-textextstore

oc delete pvc css-cfgstore
oc delete pvc css-customstore
oc delete pvc css-indexstore
oc delete pvc css-logstore
oc delete pvc css-tempstore

oc delete pvc graphql-cfgstore
oc delete pvc graphql-logstore

oc delete pvc icp4adeploy-bastudio-authoring-jms-data-vc-icp4adeploy-bastudio-authoring-jms-0

oc delete pvc cdra-cfgstore
oc delete pvc cdra-datastore
oc delete pvc cdra-logstore
oc delete pvc cds-logstore
oc delete pvc cpds-cfgstore
oc delete pvc cpds-logstore
oc delete pvc gitgateway-cfgstore
oc delete pvc gitgateway-datastore
oc delete pvc mongo-datastore
oc delete pvc viewone-cacherootstore
oc delete pvc viewone-configstore
oc delete pvc viewone-customerfontsstore
oc delete pvc viewone-docrepositoryrootstore
oc delete pvc viewone-externalresourcepathstore
oc delete pvc viewone-logsstore
oc delete pvc viewone-workingpathstore

oc delete pvc data-icp4adeploy-elasticsearch-statefulset-0
oc delete pvc icp4adeploy-workflow-authoring-baw-jms-data-vc-icp4adeploy-workflow-authoring-baw-jms-0

oc delete pvc data-icp4adeploy-ibm-dba-ek-data-0
oc delete pvc data-icp4adeploy-ibm-dba-ek-data-1
oc delete pvc data-icp4adeploy-ibm-dba-ek-master-0
oc delete pvc data-icp4adeploy-ibm-dba-ek-master-1
oc delete pvc data-icp4adeploy-ibm-dba-ek-master-2

echo
echo "Deleting the secrets..."
oc delete -f secrets.yaml
oc delete -f tlsSecrets.yaml
oc delete secret ibm-entitlement-key

echo
echo "Deleting the operator pod (will be re-created automatically)..."
oc get pods | grep ibm-cp4a-operator- | awk '$1 {print$1}' | while read vol; do oc delete pod/${vol}; done

echo
echo "Done. Exiting..."
echo
