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

projectDB=$1

export tenant_db=${projectDB} 
export tenant_db_name=${projectDB} 
export tenant_dsn_name=${projectDB}
export tenant_id=${projectDB}

#Create DB
./CreateEmptyProjectDB.sh
#initialize DB
./InitTenantDB.sh
#Load sample data
./LoadDefaultData.sh
