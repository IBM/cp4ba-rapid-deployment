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

if [ $cp4baTemplateToUse == "" -o $cp4baTemplateToUse == "REQUIRED" ]; then
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
DBs=$(sed -n '/Needed DBs:/{
	  s,^.*:,,g
	  p
}' $cp4baTemplateToUse)

echo "Used Template:" $cp4baTemplateToUse
echo "Used DBs:" $DBs