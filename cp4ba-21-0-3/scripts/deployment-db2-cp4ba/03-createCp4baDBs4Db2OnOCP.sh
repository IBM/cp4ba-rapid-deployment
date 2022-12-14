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

DBs=$(sed -n '/Needed DBs:/{
	  s,^.*:,,g
	  s, ,x,g
	  s,$,x,g
	  p
}' $cp4baTemplateToUse)


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

if [[ $DBs =~ xICNx ]]; then
    echo
    echo "Creating database ${db2IcndbName}..."
    oc cp -c db2u createICNDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createICNDB.sh"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createICNDB.sh ${db2IcndbName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createICNDB.sh"
fi

if [[ $DBs =~ xCLOSx ]]; then
    echo
    echo "Creating database ${db2ClosName}..."
    oc cp  -c db2u createOSDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createOSDB.sh"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2ClosName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
fi

if [[ $DBs =~ xDEVOS1x ]]; then
    echo
    echo "Creating database ${db2Devos1Name}..."
    oc cp  -c db2u createOSDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createOSDB.sh"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2Devos1Name} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
fi

if [[ $DBs =~ xAEOSx ]]; then
    echo
    echo "Creating database ${db2AeosName}..."
    oc cp  -c db2u createOSDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createOSDB.sh"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2AeosName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
fi

if [[ $DBs =~ xBAWDOCSx ]]; then
    echo
    echo "Creating database ${db2BawDocsName}..."
    oc cp  -c db2u createOSDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2BawDocsName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
fi

if [[ $DBs =~ xBAWDOSx ]]; then  
    echo
    echo "Creating database ${db2BawDosName}..."
    oc cp  -c db2u createOSDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2BawDosName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
fi

if [[ $DBs =~ xBAWTOSx ]]; then
    echo
    echo "Creating database ${db2BawTosName}..."
    oc cp  -c db2u createOSDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createOSDB.sh ${db2BawTosName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createOSDB.sh"
fi

if [[ $DBs =~ xBAWx ]]; then
    echo
    echo "Creating database ${db2BawDbName}..."
    oc cp  -c db2u createBAWDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createBAWDB.sh"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createBAWDB.sh ${db2BawDbName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createBAWDB.sh"
fi

if [[ $DBs =~ xAPPx ]]; then
    echo
    echo "Creating database ${db2AppdbName}..."
    oc cp  -c db2u createAPPDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createAPPDB.sh"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createAPPDB.sh ${db2AppdbName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createAPPDB.sh"
fi

if [[ $DBs =~ xAEx ]]; then
    echo
    echo "Creating database ${db2AedbName}..."
    oc cp  -c db2u createAPPDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u  c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createAPPDB.sh"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createAPPDB.sh ${db2AedbName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createAPPDB.sh"
fi

if [[ $DBs =~ xBASx ]]; then
    echo
    echo "Creating database ${db2BasdbName}..."
    oc cp  -c db2u createBASDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createBASDB.sh"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createBASDB.sh ${db2BasdbName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createBASDB.sh"
fi

if [[ $DBs =~ xGCDx ]]; then
    echo
    echo "Creating database ${db2GcddbName}..."
    oc cp  -c db2u createGCDDB.sh c-db2ucluster-db2u-0:/tmp/
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "chmod a+x /tmp/createGCDDB.sh"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "/tmp/createGCDDB.sh ${db2GcddbName} ${db2AdminUserName}"
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- /bin/sh -c "rm /tmp/createGCDDB.sh"
fi



echo
echo "Existing databases are:"
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 list database directory | grep \"Database name\""

echo
echo "Restarting DB2 instance."
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su -c "sudo wvcli system disable"
sleep $db2ActivationDelay #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2stop"
sleep $db2ActivationDelay #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2start"
sleep $db2ActivationDelay #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su -c "sudo wvcli system enable"
sleep $db2ActivationDelay #let DB2 settle down

echo
echo "Activating databases..."
echo

if [[ $DBs =~ xICNx ]]; then
    echo "${db2IcndbName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2IcndbName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xCLOSx ]]; then
    echo
    echo "${db2ClosName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2ClosName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xDEVOS1x ]]; then
    echo
    echo "${db2Devos1Name}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2Devos1Name}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xAEOSx ]]; then
    echo
    echo "${db2AeosName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2AeosName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xBAWDOCSx ]]; then
    echo
    echo "${db2BawDocsName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BawDocsName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xBAWDOSx ]]; then  
    echo
    echo "${db2BawDosName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BawDosName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xBAWTOSx ]]; then
    echo
    echo "${db2BawTosName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BawTosName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xBAWx ]]; then
    echo
    echo "${db2BawDbName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BawDbName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xAPPx ]]; then
    echo
    echo "${db2AppdbName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2AppdbName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xAEx ]]; then
    echo
    echo "${db2AedbName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2AedbName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xBASx ]]; then
    echo
    echo "${db2BasdbName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2BasdbName}"
    sleep $db2ActivationDelay
fi

if [[ $DBs =~ xGCDx ]]; then
    echo
    echo "${db2GcddbName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2GcddbName}"
    sleep $db2ActivationDelay
fi

echo
echo "Done. Exiting..."
echo
