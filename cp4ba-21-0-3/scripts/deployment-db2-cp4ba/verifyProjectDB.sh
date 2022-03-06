#!/bin/bash -e
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

projectDB=$1
baseDB=$2

## Verify that project DB is actually active
DB_ACTIVE=$(db2 list active databases | grep ${projectDB} | cat) 

## Verify that the project DB has been registered against the Base Content Analizer DB
BASE_DB_RECORD=$(db2 -v connect to ${baseDB}>/dev/null 2>&1 && db2 select "dbname" from tenantinfo | grep ${projectDB} | cat)

## Exit with a $? of 1 if information not found 
if [[ -z $DB_ACTIVE  || -z $BASE_DB_RECORD ]]
then
    exit 1
fi