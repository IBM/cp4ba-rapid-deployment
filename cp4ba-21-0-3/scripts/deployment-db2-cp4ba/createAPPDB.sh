#!/usr/bin/env bash
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

dbname=$1
dbuser=$2
myself=$(whoami)

echo "*** Creating DB named: ${dbname} ***"

db2 create database "${dbname}" automatic storage yes  using codeset UTF-8 territory US pagesize 32768;
db2 connect to "${dbname}";

db2 CREATE BUFFERPOOL DBASBBP IMMEDIATE SIZE 1024 PAGESIZE 32K;
db2 CREATE REGULAR TABLESPACE APPENG_TS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE DROPPED TABLE RECOVERY ON BUFFERPOOL DBASBBP;
db2 CREATE USER TEMPORARY TABLESPACE APPENG_TEMP_TS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL DBASBBP;

if [ "$dbuser" != "$myself" ]; then 
  db2 GRANT USE OF TABLESPACE APPENG_TS TO user "${dbuser}";
  db2 GRANT USE OF TABLESPACE APPENG_TEMP_TS TO user "${dbuser}";
  db2 grant dbadm on database to user "${dbuser}";
fi

db2 connect reset;

echo "*** Done creating and tuning DB named: ${dbname} ***"
