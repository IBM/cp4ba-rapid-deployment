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


## Set DB2 project 
echo
echo "Switching to project ${db2OnOcpProjectName}..."
oc project ${db2OnOcpProjectName}

if [[ -z $STARTING_TENANT ]]
then
    ## Activating Content Analizer Base DB
    activateDatabase $db2CaBasedbName $db2AdminUserName
    tenantNumber=1
else
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

    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${tenantDBName}"

    tenantNumber=$(($tenantNumber + 1))
done


