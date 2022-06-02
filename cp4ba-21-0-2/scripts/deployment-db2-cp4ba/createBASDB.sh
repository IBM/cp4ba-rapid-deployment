#!/usr/bin/env bash
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

dbname=$1
dbuser=$2

echo "*** Creating DB named: ${dbname} ***"

db2 create database "${dbname}" automatic storage yes using codeset UTF-8 territory US pagesize 32768;
db2 connect to "${dbname}";
db2 CREATE USER TEMPORARY TABLESPACE USRTMPSPC1;
db2 UPDATE DB CFG FOR "${dbname}" USING LOGFILSIZ 16384 DEFERRED;
db2 UPDATE DB CFG FOR "${dbname}" USING LOGSECOND 64 IMMEDIATE;
db2 grant dbadm on database to user "${dbuser}";
db2 connect reset;
