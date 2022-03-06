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

. ./common-db2-utils.sh

STARTING_TENANT=$1 
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

## overwrite variables used by script with ADP specific values
db2OnOcpProjectName=$adpDb2OnOcpProjectName
db2AdminUserPassword=$adpDb2AdminUserPassword
db2AdminUserName=$adpDb2AdminUserName

echo
echo -e "\x1B[1mThis script CREATES all needed ADP databases (assumes Db2u is running in project ${db2OnOcpProjectName}). \n \x1B[0m"

printf "Do you want to continue (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Creating all needed ADP databases..."
    ;;
*)
    echo
    echo -e "Exiting..."
    echo
    exit 0
    ;;
esac


## Set DB2 project 
echo
echo "Switching to project ${db2OnOcpProjectName}..."
oc project ${db2OnOcpProjectName}

## Update values required to create Content Analizer base DB and tenant DBs
echo 
echo "Preparing create base DB and tennant templates"
cp baca-db/DB2/common_for_DB2.sh.sample baca-db/DB2/common_for_DB2.sh
sed -i.bak "s|db2CaBasedbName|$db2CaBasedbName|g" baca-db/DB2/common_for_DB2.sh
sed -i.bak "s|db2AdminUserName|$db2AdminUserName|g" baca-db/DB2/common_for_DB2.sh
sed -i.bak "s|db2AdminUserPassword|$db2AdminUserPassword|g" baca-db/DB2/common_for_DB2.sh


## Copy content on DB2 server
echo
echo "Copying execution scripts and sample data on DB2 server"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm -rf /tmp/DB2"
oc cp baca-db/DB2 c-db2ucluster-db2u-0:/tmp/
oc cp createAndInitProjectDB.sh c-db2ucluster-db2u-0:/tmp/DB2
oc cp verifyProjectDB.sh c-db2ucluster-db2u-0:/tmp/DB2
oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod -R 777 /tmp/DB2"

if [[ -z $STARTING_TENANT ]]
then
    ## Create Conent Analizer Base DB
    echo
    echo "Creating Base Content Analizer DB ${db2CaBasedbName}"
    time oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "cd /tmp/DB2 && ./CreateBaseDB.sh"


    ## Activating Content Analizer Base DB
    activateDatabase $db2CaBasedbName $db2AdminUserName
    tenantNumber=1
else
    echo
    echo "Skipping Base Content Analizer DB creation. Creating Project DBs from ${STARTING_TENANT} to ${numberTenantDBs}"
    tenantNumber=$STARTING_TENANT
fi

date>tenantDBs.log

while [[ ${tenantNumber} -le  ${numberTenantDBs} ]]
do
    if [[ ${tenantNumber} -le 9 ]]
    then
        # being picky here.  I want the tenant name to be PDBXX so adding a zero to single digits 
        tenantDBName="${db2TenantDBPrefix}0${tenantNumber}"
    else
        tenantDBName="${db2TenantDBPrefix}${tenantNumber}"
    fi

    #Create, initialize and load test data
    echo
    echo "Creating tenant DB ${tenantDBName}. This will take some time..." 
    date
    # Create, initialize and load new tenant DB
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "cd /tmp/DB2 && ./createAndInitProjectDB.sh ${tenantDBName}">>tenantDBs.log 2>&1
    
    # Verify that the new tenant DB was created properly and that there is a record in the $db2CaBasedbName about it 
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "cd /tmp/DB2 && ./verifyProjectDB.sh ${tenantDBName} ${db2CaBasedbName}"
    rc=$?

    if [ $rc != 0 ]
    then
        echo "WARNING: Tenant DB ${tenantDBName} did not create properly. Check tenantDBs.log"
    else
        echo "Tenant DB ${tenantDBName} successfully created." 
    fi

    tenantNumber=$(($tenantNumber + 1))
done


