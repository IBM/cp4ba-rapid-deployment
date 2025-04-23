#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2025. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# This script is for restoring DB2 databases of our Authoring environment

# Reference: 
# - https://www.ibm.com/docs/en/license-metric-tool/9.2.0?topic=database-restoring-db2

# DBs to restore: GCDDB, AEDB, BAWTOS, BASDB, ICNDB, BAWDB, APPDB, BAWDOCS, BAWDOS

DATETIMESTR=20250414_111109

function perform_db_restore() {
  DBName=$1
  TimeStamp=$2
  db2 terminate
  db2 deactivate db $DBName
  backupDir="/home/db2inst1/backup_${DBName}_${DATETIMESTR}"
  echo "Restoring DB:" $DBName
  db2 restore db $DBName from $backupDir taken at $TimeStamp replace existing
  db2 activate db $DBName
}

echo
echo "Restoring DBs 4 Authoring Environment..."
echo
perform_db_restore GCDDB 20250414111113
echo
perform_db_restore AEDB 20250414111119
echo
perform_db_restore BAWTOS 20250414111124
echo
perform_db_restore BASDB 20250414111131
echo
perform_db_restore ICNDB 20250414111141
echo
perform_db_restore BAWDB 20250414111146
echo
perform_db_restore APPDB 20250414111156
echo
perform_db_restore BAWDOCS 20250414111201
echo
perform_db_restore BAWDOS 20250414111208
echo
