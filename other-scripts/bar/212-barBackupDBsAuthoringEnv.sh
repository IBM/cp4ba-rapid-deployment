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

# This script is for backing up DB2 databases of our Authoring environment

# Reference: 
# - https://www.ibm.com/docs/en/license-metric-tool/9.2.0?topic=database-backing-up-db2

# DBs to backup: GCDDB, AEDB, BAWTOS, BASDB, ICNDB, BAWDB, APPDB, BAWDOCS, BAWDOS

DATETIMESTR=$(date +'%Y%m%d_%H%M%S')

function perform_db_backup() {
  DBName=$1
  db2 terminate
  db2 deactivate db $DBName
  backupDir="/home/db2inst1/backup_${DBName}_${DATETIMESTR}"
  mkdir $backupDir
  echo "Backing up to:" $backupDir
  db2 backup database $DBName to $backupDir
  db2 activate db $DBName
}

perform_db_backup GCDDB
perform_db_backup AEDB
perform_db_backup BAWTOS
perform_db_backup BASDB
perform_db_backup ICNDB
perform_db_backup BAWDB
perform_db_backup APPDB
perform_db_backup BAWDOCS
perform_db_backup BAWDOS

