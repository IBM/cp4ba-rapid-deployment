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
echo "Switching to project ${db2OnOcpProjectName}..."
oc project ${db2OnOcpProjectName}

echo
echo "Restarting Db2..."
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2stop"
sleep 5
oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2start"
sleep 5

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

if [[ $DBs =~ xADPx ]]; then
    echo
    echo "${db2CaBasedbName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2CaBasedbName}"
    sleep $db2ActivationDelay
    echo
    echo "${db2CaTendbName}..."
    oc exec -c db2u c-db2ucluster-db2u-0 -it -- su - $db2AdminUserName -c "db2 activate database ${db2CaTendbName}"
    sleep $db2ActivationDelay
fi

echo
echo "Done. Exiting..."
echo
