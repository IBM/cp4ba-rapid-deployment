#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2025-2026. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# This script is for restoring DB2 databases of our ibm-cp4ba-test environment

# Reference: 
# - https://www.ibm.com/docs/en/license-metric-tool/9.2.0?topic=database-restoring-db2

# DBs to restore: GCDDB2, AEDB2, BAWTOS2, ICNDB2, BAWDB2, BAWDOCS2, BAWDOS2

DATETIMESTR=20251216_071632

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
echo "Restoring DBs 4 ibm-cp4ba-test Environment..."
echo
perform_db_restore GCDDB2 20251216071636
echo
perform_db_restore AEDB2 20251216071644
echo
perform_db_restore BAWTOS2 20251216071652
echo
perform_db_restore ICNDB2 20251216071703
echo
perform_db_restore BAWDB2 20251216071710
echo
perform_db_restore BAWDOCS2 20251216071731
echo
perform_db_restore BAWDOS2 20251216071739
echo
