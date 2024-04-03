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

. ./common-db2-utils.sh

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

if [ "x$cp4baTemplateToUse" == "x" -o "x$cp4baTemplateToUse" == "xREQUIRED" ]; then
    echo
    echo Parameter cp4baTemplateToUse not set!!
    echo
    exit 1
fi

if [ ! -f $cp4baTemplateToUse ]; then
    echo
    echo cp4baTemplateToUse points to a template file, which is not existing!!
    echo
    exit 1
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
    
    if [[ $DBs =~ xICNx ]]; then
	echo
	echo "Creating database ${db2IcndbName}... on DB instance $dbinst"
	oc cp -c db2u createICNDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createICNDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createICNDB.sh ${db2IcndbName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createICNDB.sh"
	echo
    fi

    if [[ $DBs =~ xCLOSx ]]; then
	echo
	echo "Creating database ${db2ClosName}...on DB instance $dbinst"
	oc cp  -c db2u createOSDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createOSDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2ClosName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
	echo
    fi

    if [[ $DBs =~ xDEVOS1x ]]; then
	echo
	echo "Creating database ${db2Devos1Name}...on DB instance $dbinst"
	oc cp  -c db2u createOSDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createOSDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2Devos1Name} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
	echo
    fi

    if [[ $DBs =~ xAEOSx ]]; then
	echo
	echo "Creating database ${db2AeosName}...on DB instance $dbinst"
	oc cp  -c db2u createOSDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createOSDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2AeosName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
	echo
    fi

    if [[ $DBs =~ xBAWDOCSx ]]; then
	echo
	echo "Creating database ${db2BawDocsName}...on DB instance $dbinst"
	oc cp  -c db2u createOSDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2BawDocsName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
	echo
    fi

    if [[ $DBs =~ xBAWDOSx ]]; then  
	echo
	echo "Creating database ${db2BawDosName}...on DB instance $dbinst"
	oc cp  -c db2u createOSDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2BawDosName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
	echo
    fi

    if [[ $DBs =~ xBAWTOSx ]]; then
	echo
	echo "Creating database ${db2BawTosName}...on DB instance $dbinst"
	oc cp  -c db2u createOSDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2BawTosName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
	echo
    fi

    if [[ $DBs =~ xBAWx ]]; then
	echo
	echo "Creating database ${db2BawDbName}...on DB instance $dbinst"
	oc cp  -c db2u createBAWDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createBAWDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createBAWDB.sh ${db2BawDbName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createBAWDB.sh"
	echo
    fi
    
    if [[ $DBs =~ xAPPx ]]; then
	echo
	echo "Creating database ${db2AppdbName}...on DB instance $dbinst"
	oc cp  -c db2u createAPPDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createAPPDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createAPPDB.sh ${db2AppdbName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createAPPDB.sh"
	echo
    fi

    if [[ $DBs =~ xAEx ]]; then
	echo
	echo "Creating database ${db2AedbName}...on DB instance $dbinst"
	oc cp  -c db2u createAPPDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u  ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createAPPDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createAPPDB.sh ${db2AedbName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createAPPDB.sh"
	echo
    fi

    if [[ $DBs =~ xBASx ]]; then
	echo
	echo "Creating database ${db2BasdbName}...on DB instance $dbinst"
	oc cp  -c db2u createBASDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createBASDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createBASDB.sh ${db2BasdbName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createBASDB.sh"
	echo
    fi
    
    if [[ $DBs =~ xGCDx ]]; then
	echo
	echo "Creating database ${db2GcddbName}...on DB instance $dbinst"
	oc cp  -c db2u createGCDDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createGCDDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createGCDDB.sh ${db2GcddbName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createGCDDB.sh"
	echo
    fi
    
    if [[ $DBs =~ xODMx ]]; then
	echo
	echo "Creating database ${db2OdmdbName}...on DB instance $dbinst"
	oc cp  -c db2u createODMDB.sh ${DB2POD}:/tmp/
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "chmod a+x /tmp/createODMDB.sh"
	oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "/tmp/createODMDB.sh ${db2OdmdbName} ${db2AdminUserName}"
	oc exec -c db2u ${DB2POD} -it -- /bin/sh -c "rm /tmp/createODMDB.sh"
	echo
    fi
    
    echo
    echo "Existing databases on instance $dbinst are:"
    oc exec -c db2u ${DB2POD} -it -- su - $db2AdminUserName -c "db2 list database directory | grep \"Database name\""

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
    echo "Restarting DB2 instance $dbinst"
    oc exec ${DB2POD} -it -c db2u -- su -c "sudo wvcli system disable"
    sleep $db2ActivationDelay #let DB2 settle down
    oc exec ${DB2POD} -it -c db2u -- su - $db2AdminUserName -c "db2stop"
    sleep $db2ActivationDelay #let DB2 settle down
    oc exec ${DB2POD} -it -c db2u -- su - $db2AdminUserName -c "db2start"
    sleep $db2ActivationDelay #let DB2 settle down
    oc exec ${DB2POD} -it -c db2u -- su -c "sudo wvcli system enable"
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
    echo "Activating databases...on DB2 instance $dbinst"
    echo
    
    if [[ $DBs =~ xICNx ]]; then
	activateDatabase ${db2IcndbName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xCLOSx ]]; then
	activateDatabase ${db2ClosName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xDEVOS1x ]]; then
	activateDatabase ${db2Devos1Name} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xAEOSx ]]; then
    activateDatabase ${db2AeosName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xBAWDOCSx ]]; then
	activateDatabase ${db2BawDocsName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xBAWDOSx ]]; then  
	activateDatabase ${db2BawDosName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xBAWTOSx ]]; then
	activateDatabase ${db2BawTosName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xBAWx ]]; then
	activateDatabase ${db2BawDbName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xAPPx ]]; then
	activateDatabase ${db2AppdbName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xAEx ]]; then
	activateDatabase ${db2AedbName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xBASx ]]; then
	activateDatabase ${db2BasdbName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xGCDx ]]; then
	activateDatabase ${db2GcddbName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xODMx ]]; then
	activateDatabase ${db2OdmdbName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
    fi
    
    if [[ $DBs =~ xADPx ]]; then
	activateDatabase ${db2CaBasedbName} $db2AdminUserName $DB2POD 
	sleep $db2ActivationDelay
	echo
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

	    activateDatabase ${tenantDBName} $db2AdminUserName ${DB2POD} 
	    sleep $db2ActivationDelay

	    tenantNumber=$(($tenantNumber + 1))
	done
    fi

    dbinst=$(( $dbinst + 1 ))
    
done
echo
echo "Done. Exiting..."
echo