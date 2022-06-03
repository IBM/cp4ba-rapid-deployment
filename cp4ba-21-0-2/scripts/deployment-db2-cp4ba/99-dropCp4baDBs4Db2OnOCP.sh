#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2022. All Rights Reserved.
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
   
   if [[ $db2OnOcpProjectName == "" ]]; then
      echo "File ${DB2_INPUT_PROPS_FILENAME} not updated. Pls. update."
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
echo -e "\x1B[1mThis script DROPS all CP4BA databases (assumes Db2u is running in project ${db2OnOcpProjectName}). \n \x1B[0m"

printf "Do you want to continue (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Deleting all CP4BA databases..."
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
echo "Dropping database BLUDB (might not work or might already be deleted, what is ok)..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database BLUDB"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database BLUDB"

echo
echo "Dropping database ${db2UmsdbName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2UmsdbName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2UmsdbName}"

echo
echo "Dropping database ${db2IcndbName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2IcndbName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2IcndbName}"

echo
echo "Dropping database ${db2Devos1Name}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2Devos1Name}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2Devos1Name}"

echo
echo "Dropping database ${db2AeosName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2AeosName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2AeosName}"

echo
echo "Dropping database ${db2BawDocsName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2BawDocsName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2BawDocsName}"

echo
echo "Dropping database ${db2BawDosName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2BawDosName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2BawDosName}"

echo
echo "Dropping database ${db2BawTosName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2BawTosName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2BawTosName}"

echo
echo "Dropping database ${db2BawDbName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2BawDbName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2BawDbName}"

echo
echo "Dropping database ${db2AppdbName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2AppdbName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2AppdbName}"

echo
echo "Dropping database ${db2AedbName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2AedbName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2AedbName}"

echo
echo "Dropping database ${db2BasdbName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2BasdbName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2BasdbName}"

echo
echo "Dropping database ${db2GcddbName}..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2GcddbName}"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 drop database ${db2GcddbName}"

echo
echo "Remaining databases are:"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 list database directory | grep \"Database name\""

echo
echo "Restarting DB2 instance."
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su -c "sudo wvcli system disable"
sleep 30 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2stop"
sleep 30 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2start"
sleep 30 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su -c "sudo wvcli system enable"
sleep 30 #let DB2 settle down

echo
echo "Done. Exiting..."
echo
