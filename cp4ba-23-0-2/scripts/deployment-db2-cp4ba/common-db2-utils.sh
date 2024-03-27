#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2024. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

##
## Description:
##  This function activates a DB2 database running on OCP by connecting to the c-db2ucluster-db2u-0 POD.  
##  The function first checks if DB is activated. If activated it just returns 0 without doing anything.
##  If activation fails this function tries up to 5 times before giving up.
##
## Parameters:
##  $1  Name of database to activate
##  $2  Name of db2 user.  Typically db2inst1 
## Display:
##  Progress messages
## Returns:
##  0 if database was activated properly non zero otherwise
##
function activateDatabase {
    local db=$1
    local dbUser=$2
    local dbPod=$3
    local MAX_TRIES=5
    local tries=0
    local waitTime=30


    DB=$(oc exec -c db2u $dbPod -it -- su - $dbUser -c "db2 list active databases 2>/dev/null" | grep ${db} | cat)

    if [[ $DB != "" ]]
    then
        ## Database already active nothing to do
        echo 
        echo "Database ${db} already active."
        return 0
    fi

    echo
    echo "Activating Database ${db}..."
    oc exec $dbPod -it -c db2u -- su - $dbUser -c "db2 activate database ${db}"
    rc=$?

    while [ $rc -ne 0 ] && [ $tries -lt $MAX_TRIES ]
    do
        echo "Activation for Database ${db} failed.  Waiting $waitTime seconds and trying again.."
        sleep $waitTime
        oc exec $dbPod -it -- su - $dbUser -c "db2 deactivate database ${db}"
        sleep $waitTime
        oc exec $dbPod -it -- su - $dbUser -c "db2 activate database ${db}"
        rc=$?
        tries=$(( $tries + 1 ))
        # progressively increase the waiting time every time we retry
        waitTime=$(($waitTime + 10))
    done

    return $rc
}
