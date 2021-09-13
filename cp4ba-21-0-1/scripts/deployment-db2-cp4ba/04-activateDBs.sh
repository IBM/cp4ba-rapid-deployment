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
DB2_INPUT_PROPS_FILENAME="01-parametersForDb2OnOCP.sh"
DB2_INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${DB2_INPUT_PROPS_FILENAME}"

if [[ -f $DB2_INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${DB2_INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   . $DB2_INPUT_PROPS_FILENAME_FULL
   
   if [ $db2OnOcpProjectName == "REQUIRED" ]; then
      echo "File ${DB2_INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 0
   fi
   
   echo "Done!"
else
   echo
   echo "File ${DB2_INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 0
fi

echo
echo "Switching to project ${db2OnOcpProjectName}..."
oc project ${db2OnOcpProjectName}

echo
echo "Restarting Db2..."
oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2stop"
sleep 5
oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2start"
sleep 5

echo
echo "Activating databases..."
echo
echo "${db2UmsdbName}..."
oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2UmsdbName}"
sleep 5
echo
echo "${db2IcndbName}..."
oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2IcndbName}"

if [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml" ] || [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.002.ent.FoundationContent.yaml" ]; then
  sleep 5
  echo
  echo "${db2Devos1Name}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2Devos1Name}"
fi

if [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml" ]; then
  sleep 5
  echo
  echo "${db2AeosName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2AeosName}"
  sleep 5
  echo
  echo "${db2BawDocsName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BawDocsName}"
  sleep 5
  echo
  echo "${db2BawDosName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BawDosName}"
  sleep 5
  echo
  echo "${db2BawTosName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BawTosName}"
  sleep 5
  echo
  echo "${db2BawDbName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BawDbName}"
  sleep 5
  echo
  echo "${db2AppdbName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2AppdbName}"
  sleep 5
  echo
  echo "${db2AedbName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2AedbName}"
  sleep 5
  echo
  echo "${db2BasdbName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BasdbName}"
fi

if [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml" ] || [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.002.ent.FoundationContent.yaml" ]; then
  sleep 5
  echo
  echo "${db2GcddbName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2GcddbName}"
fi

echo
echo "Done. Exiting..."
echo
