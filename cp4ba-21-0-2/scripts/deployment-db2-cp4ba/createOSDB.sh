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
dbpath=$3
dbtuning=$4
dbstopaths=$3


echo "*** Creating DB named: $dbname ***"

# if optional storage paths are not specified
#  db2 create database ${dbname} automatic storage yes on ${dbstopaths} dbpath on ${dbpath} using codeset UTF-8 territory US pagesize 32 K
# Let ootb Db2 container setup take over
db2 create database "${dbname}" automatic storage yes using codeset UTF-8 territory US pagesize 32 K

db2 connect to "${dbname}"

db2 drop tablespace USERSPACE1

echo "*** Create bufferpool ***"
# Create 1GB fixed bufferpool for performance, automatic tuning for platform

db2 create bufferpool "${dbname}"_32K immediate size 32768 pagesize 32k

echo "*** Create table spaces ***"
db2 CREATE LARGE TABLESPACE "${dbname}"_DATA_TBS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE AUTORESIZE YES INITIALSIZE 10G INCREASESIZE 1G MAXSIZE 25G BUFFERPOOL "${dbname}"_32K

db2 CREATE USER TEMPORARY TABLESPACE "${dbname}"_TMP_TBS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL "${dbname}"_32K

echo "*** Grant permissions to DB user ***"
db2 GRANT CREATETAB,CONNECT ON DATABASE  TO user "${dbuser}"
db2 GRANT USE OF TABLESPACE "${dbname}"_DATA_TBS TO user "${dbuser}"
db2 GRANT USE OF TABLESPACE "${dbname}"_TMP_TBS TO user "${dbuser}"
db2 GRANT SELECT ON SYSIBM.SYSVERSIONS to user "${dbuser}"
db2 GRANT SELECT ON SYSCAT.DATATYPES to user "${dbuser}"
db2 GRANT SELECT ON SYSCAT.INDEXES to user "${dbuser}"
db2 GRANT SELECT ON SYSIBM.SYSDUMMY1 to user "${dbuser}"
db2 GRANT USAGE ON WORKLOAD SYSDEFAULTUSERWORKLOAD to user "${dbuser}"
db2 GRANT IMPLICIT_SCHEMA ON DATABASE to user "${dbuser}"

echo "*** Apply DB tunings ***"
db2 update db cfg for "${dbname}" using LOCKTIMEOUT 30
db2 update db cfg for "${dbname}" using APPLHEAPSZ 2560
db2 update db cfg using cur_commit ON

# Let Db2 ootb container settings stay
#db2 update db cfg for ${dbname} using LOGBUFSZ 212
#db2 update db cfg for ${dbname} using LOGFILSIZ 6000
# db2 update db cfg for ${dbname} using LOGPRIMARY 10

db2 connect reset
db2 deactivate db "${dbname}"

echo "*** Done creating and tuning DB named: ${dbname} ***"
