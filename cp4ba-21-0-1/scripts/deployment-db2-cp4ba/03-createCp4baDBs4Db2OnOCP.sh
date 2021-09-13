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
echo -e "\x1B[1mThis script CREATES all needed CP4BA databases (assumes Db2u is running in project ${db2OnOcpProjectName}). \n \x1B[0m"

printf "Do you want to continue (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Creating all needed CP4BA databases..."
    ;;
*)
    echo
    echo -e "Exiting..."
    echo
    exit 0
    ;;
esac

echo
echo "Switching to project ${db2OnOcpProjectName}..."
oc project ${db2OnOcpProjectName}

echo
echo "Creating database ${db2UmsdbName}..."
oc cp createUMSDB.sh c-db2ucluster-db2u-0:/tmp/
oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createUMSDB.sh"
oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createUMSDB.sh ${db2UmsdbName} ${db2AdminUserName}"
oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createUMSDB.sh"

echo
echo "Creating database ${db2IcndbName}..."
oc cp createICNDB.sh c-db2ucluster-db2u-0:/tmp/
oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createICNDB.sh"
oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createICNDB.sh ${db2IcndbName} ${db2AdminUserName}"
oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createICNDB.sh"

if [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml" ] || [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.002.ent.FoundationContent.yaml" ]; then
  echo
  echo "Creating database ${db2Devos1Name}..."
  oc cp createOSDB.sh c-db2ucluster-db2u-0:/tmp/
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createOSDB.sh"
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2Devos1Name} ${db2AdminUserName}"
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
fi

if [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml" ]; then  
  echo
  echo "Creating database ${db2AeosName}..."
  oc cp createOSDB.sh c-db2ucluster-db2u-0:/tmp/
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createOSDB.sh"
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2AeosName} ${db2AdminUserName}"
  
  echo
  echo "Creating database ${db2BawDocsName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2BawDocsName} ${db2AdminUserName}"
  
  echo
  echo "Creating database ${db2BawDosName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2BawDosName} ${db2AdminUserName}"
  
  echo
  echo "Creating database ${db2BawTosName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2BawTosName} ${db2AdminUserName}"
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
  
  echo
  echo "Creating database ${db2BawDbName}..."
  oc cp createBAWDB.sh c-db2ucluster-db2u-0:/tmp/
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createBAWDB.sh"
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createBAWDB.sh ${db2BawDbName} ${db2AdminUserName}"
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createBAWDB.sh"
  
  echo
  echo "Creating database ${db2AppdbName}..."
  oc cp createAPPDB.sh c-db2ucluster-db2u-0:/tmp/
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createAPPDB.sh"
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createAPPDB.sh ${db2AppdbName} ${db2AdminUserName}"
  
  echo
  echo "Creating database ${db2AedbName}..."
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createAPPDB.sh ${db2AedbName} ${db2AdminUserName}"
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createAPPDB.sh"
  
  echo
  echo "Creating database ${db2BasdbName}..."
  oc cp createBASDB.sh c-db2ucluster-db2u-0:/tmp/
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createBASDB.sh"
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createBASDB.sh ${db2BasdbName} ${db2AdminUserName}"
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createBASDB.sh"
fi

if [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml" ] || [ $cp4baTemplateToUse == "ibm_cp4a_cr_template.002.ent.FoundationContent.yaml" ]; then
  echo
  echo "Creating database ${db2GcddbName}..."
  oc cp createGCDDB.sh c-db2ucluster-db2u-0:/tmp/
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createGCDDB.sh"
  oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createGCDDB.sh ${db2GcddbName} ${db2AdminUserName}"
  oc exec c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createGCDDB.sh"
fi

echo
echo "Existing databases are:"
oc exec c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 list database directory | grep \"Database name\""

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
