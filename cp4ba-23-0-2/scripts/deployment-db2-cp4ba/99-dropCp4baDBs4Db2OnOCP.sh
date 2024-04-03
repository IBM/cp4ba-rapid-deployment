#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2024. All Rights Reserved.
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

##
## Find Out, how many DB Instances are needed
##

DBINSTANCES=$(sed -n '/Database Instances:/{
	  s,^.*:,,g
	  p
}' $cp4baTemplateToUse)

dbinst=1
while [ $dbinst -le $DBINSTANCES ]; do

    # The following kind of code is expected in the template:
    # DBs on Instance 1: ICN GCD 

    SEDCOMMAND=$(printf '/DBs on Instance %1d:/p' $dbinst)
    DBs=$(sed -n "$SEDCOMMAND" $cp4baTemplateToUse | sed 's,^.*:,,g' | sed 's, ,x,g' | sed 's,$,x,g')
    DB2POD=$(printf 'c-db2-inst%1d-db2u-0' $dbinst)

    echo
    echo "Database Instance: $dbinst"
    echo
    echo "Dropping database BLUDB (might not work or might already be deleted, what is ok)..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database BLUDB"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database BLUDB"

    echo
    echo "Dropping database ${db2IcndbName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2IcndbName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2IcndbName}"

    echo
    echo "Dropping database ${db2ClosName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2ClosName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2ClosName}"

    echo
    echo "Dropping database ${db2Devos1Name}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2Devos1Name}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2Devos1Name}"

    echo
    echo "Dropping database ${db2AeosName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2AeosName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2AeosName}"

    echo
    echo "Dropping database ${db2BawDocsName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2BawDocsName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2BawDocsName}"

    echo
    echo "Dropping database ${db2BawDosName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2BawDosName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2BawDosName}"

    echo
    echo "Dropping database ${db2BawTosName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2BawTosName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2BawTosName}"

    echo
    echo "Dropping database ${db2BawDbName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2BawDbName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2BawDbName}"

    echo
    echo "Dropping database ${db2AppdbName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2AppdbName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2AppdbName}"

    echo
    echo "Dropping database ${db2AedbName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2AedbName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2AedbName}"

    echo
    echo "Dropping database ${db2GcddbName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2GcddbName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2GcddbName}"

    echo
    echo "Dropping database ${db2OdmdbName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database ${db2OdmdbName}"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database ${db2OdmdbName}"

    # TODO: parameterize the deletion of the ADP DBs
    echo
    echo "Dropping database ${db2CaBasedbName}..."
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database $db2CaBasedbName"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database $db2CaBasedbName"

    tenantNumber=1
    while [[ ${tenantNumber} -le  ${numberTenantDBs} ]]
    do
	if [[ ${tenantNumber} -le 9 ]]
	then
            # being picky here.  I want the tenant name to be PDBXX so adding a zero to single digits 
            tenantDBName="${db2TenantDBPrefix}0${tenantNumber}"
	else
            tenantDBName="${db2TenantDBPrefix}${tenantNumber}"
	fi
	echo "Dropping database $tenantDBName..."
	oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 deactivate database $tenantDBName"
	oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 drop database $tenantDBName"
	tenantNumber=$(($tenantNumber + 1))
    done

    echo
    echo "Restarting DB2 instance."
    oc exec $DB2POD -it -c db2u -- su -c "sudo wvcli system disable"
    sleep $db2ActivationDelay #let DB2 settle down
    oc exec $DB2POD -it -c db2u -- su - $db2AdminUserName -c "db2stop"
    sleep $db2ActivationDelay #let DB2 settle down
    oc exec $DB2POD -it -c db2u -- su - $db2AdminUserName -c "db2start"
    sleep $db2ActivationDelay #let DB2 settle down
    oc exec $DB2POD -it -c db2u -- su -c "sudo wvcli system enable"
    sleep $db2ActivationDelay #let DB2 settle down
    
    dbinst=$(( $dbinst + 1 ))
done

dbinst=1
while [ $dbinst -le $DBINSTANCES ]; do

    # The following kind of code is expected in the template:
    # DBs on Instance 1: ICN GCD 

    SEDCOMMAND=$(printf '/DBs on Instance %1d:/p' $dbinst)
    DBs=$(sed -n "$SEDCOMMAND" $cp4baTemplateToUse | sed 's,^.*:,,g' | sed 's, ,x,g' | sed 's,$,x,g')
    DB2POD=$(printf 'c-db2-inst%1d-db2u-0' $dbinst)

    echo
    echo "Remaining databases on DB Instance $dbinst are:"
    oc exec -c db2u $DB2POD -it -- su - $db2AdminUserName -c "db2 list database directory | grep \"Database name\""

    dbinst=$(( $dbinst + 1 ))
done

echo
echo "Done. Exiting..."
echo
