#!/bin/bash
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

bar_version=1.1

# This script contains shared utility functions.

function logInfo() {
  echo "$(date +'%F %T.%3N %Z')   INFO    $*"
  echo "$(date +'%F %T.%3N %Z')   INFO    $*" >> $LOG_FILE
}

function logInfoValue() {
  prompt=$1; shift
  echo -e "$(date +'%F %T.%3N %Z')   INFO    $prompt \x1B[1m$*\x1B[0m"
  echo "$(date +'%F %T.%3N %Z')   INFO    $prompt $*" >> $LOG_FILE
}

function logWarning() {
  echo "$(date +'%F %T.%3N %Z')   WARNING $*"
  echo "$(date +'%F %T.%3N %Z')   WARNING $*" >> $LOG_FILE
}

function logError() {
  echo "$(date +'%F %T.%3N %Z')   ERROR   $*"
  echo "$(date +'%F %T.%3N %Z')   ERROR   $*" >> $LOG_FILE
}

# Convert operator version number to actual release number, e.g. 21.3.34 to 21.0.3.34
function convertVersionNumber() {
  array=($(echo "$1" | awk -F'.' '{for(i=1;i<=NF;i++) print $i}'))
  echo ${array[0]}.0.${array[1]}.${array[2]}
}

# Check the value, call logInfo if it's expected, or call logError
# $1 the value
# $2 the expected value
# $3 the message to be logged
function checkResult() {
  if [ "$1" != "$2" ]; then
    logError "  $3: $1, please check !!"
    return 1
  else
    logInfo "  $3: $1"
    return 0
  fi
}

# Check HTTP return code
# $1 http return code
# $2 expected http code
# $3 URL
function checkHTTPCode() {
  if [[ $1 != $2 ]]; then
    logError "  Cannot connect to: $3, HTTP $1 returned, please check !!"
    return 1
  else
    logInfo "  Successfully connected to: $3, HTTP $1 returned"
    return 0
  fi
}