#! /bin/bash
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

[ ! -z "$DEBUG" ] && set -x

##
## Description:
##  This function waits until  specific operator reports successful installation.
##  The Operator is represented by its Cluster Service Version. 
##  Once the CSV goes to Succeeded phase the function returns unless it times out. 
## Parameters:
##  $1  Name of cluster service version for the operator
##  $2  Time in minutes to wait for the operator to install properly 
##  $3  Namespace were operator is installed
## Display:
##  - Empty string if time out waiting
##  - Succeeded string otherwise
##
function wait_for_operator_to_install_successfully {
  local csvName=$1
  local timeToWait=$2
  local namespace=$3
  local TOTAL_WAIT_TIME_SECS=$(( 60 * $timeToWait))
  local CURRENT_WAIT_TIME=0
  local CSV_STATUS=""

  while [ $CURRENT_WAIT_TIME -lt $TOTAL_WAIT_TIME_SECS ]
  do
    CSV_STATUS=$(oc get csv $csvName -o custom-columns=PHASE:.status.phase --no-headers -n $namespace 2>/dev/null | grep Succeeded | cat)
    if [ ! -z "$CSV_STATUS" ]
    then
      #Done waiting
      break
    fi
    # Still waiting
    sleep 10
    CURRENT_WAIT_TIME=$(( $CURRENT_WAIT_TIME + 10 ))
  done

  echo $CSV_STATUS
}


##
## Description:
##  This function waits until an install plan is defined for an operator subscription.
## Parameters:
##  $1  Name of subscription for the operator
##  $2  Time in minutes to wait for the install plan to be ready
##  $3  Namespace were subscription was created
## Display:
##  - Empty string if time out waiting
##  - Name of install plan otherwise
##
function wait_for_install_plan {
  local subscriptionName=$1
  local timeToWait=$2
  local namespace=$3
  local TOTAL_WAIT_TIME_SECS=$(( 60 * $timeToWait))
  local CURRENT_WAIT_TIME=0
  local INSTALL_PLAN=""

  while [ $CURRENT_WAIT_TIME -lt $TOTAL_WAIT_TIME_SECS ]
  do
    INSTALL_PLAN=$(oc get subscription $subscriptionName -o custom-columns=IPLAN:.status.installplan.name --no-headers -n $namespace 2>/dev/null | grep -v "<none>" | cat)
    if [ ! -z "$INSTALL_PLAN" ] 
    then
      # Done waiting 
      break
    fi
    # Still waiting
    sleep 10
    CURRENT_WAIT_TIME=$(( $CURRENT_WAIT_TIME + 10 ))
  done

  echo $INSTALL_PLAN 
}

##
## Description:
##   This function waits until a kubernetes resource exist
## Parameters:
##  $1  Kind of resource to wait for
##  $2  Name of the resource to wait for
##  $3  Time in minutes to wait for the install plan to be ready
##  $4  Namespace were resource is located
## Display:
##  - Empty string if time out waiting
##  - Resource fully qualified name of the resource as returned by oc get -o name 
##
function wait_for_resource_created_by_name {
  local resourceKind=$1
  local name=$2
  local timeToWait=$3
  local namespace=$4
  local TOTAL_WAIT_TIME_SECS=$(( 60 * $timeToWait))
  local CURRENT_WAIT_TIME=0
  local RESOURCE_FULLY_QUALIFIED_NAME=""

  while [ $CURRENT_WAIT_TIME -lt $TOTAL_WAIT_TIME_SECS ]
  do
    RESOURCE_FULLY_QUALIFIED_NAME=$(oc get $resourceKind $name  -o name --no-headers -n $namespace 2>/dev/null)
    if [ ! -z "$RESOURCE_FULLY_QUALIFIED_NAME" ] 
    then
      # Done waiting 
      break
    fi
    # Still waiting
    sleep 10
    CURRENT_WAIT_TIME=$(( $CURRENT_WAIT_TIME + 10 ))
  done
 
  echo $RESOURCE_FULLY_QUALIFIED_NAME 
}


##
## Description:
##  This function waits for a job to go into Complete state
## Parameters:
##  $1  Name of the job to wait for
##  $2  Time in minutes to wait for the install plan to be ready
##  $3  Namespace were job is located
## Display:
##  - Empty string if time out waiting
##  - Complete string if job is completed  
##
function wait_for_job_to_complete_by_name {
  local jobName=$1
  local timeToWait=$2
  local namespace=$3
  local TOTAL_WAIT_TIME_SECS=$(( 60 * $timeToWait))
  local CURRENT_WAIT_TIME=0
  local JOB_STATUS=""

  while [ $CURRENT_WAIT_TIME -lt $TOTAL_WAIT_TIME_SECS ]
  do
    JOB_STATUS=$(oc get job $jobName -n $namespace -o custom-columns=STATUS:'.status.conditions[*].type' 2>/dev/null | grep Complete | cat)
    if [ ! -z "$JOB_STATUS" ] 
    then
      # Done waiting 
      break
    fi
    # Still waiting
    sleep 10
    CURRENT_WAIT_TIME=$(( $CURRENT_WAIT_TIME + 10 ))
  done
 
  echo $JOB_STATUS 
}


##
## Description:
##  Get the address or addresses associated with the worker node hosting a POD
## Parameters:
##  $1  Pod name
##  $2  namepsace where the pod is located
##  $3  Type filter for address entry.  The values depend on the cluster (i.e ROKS vs OCP) but could include ExternalIP, InternalIP, Hostname
## Display:
##  - If filter provided, address for the specific filter
##  - If not filter provided, all addresses associated with worker node
##
function get_worker_node_addresses_from_pod {
  local podName=$1
  local namespace=$2
  local typeFilter=$3
  local HOST_NODE=""
  local HOST_ADDRESSES=""

  HOST_NODE=$(oc get pod $podName -o custom-columns=NODE:.spec.nodeName --no-headers 2>/dev/null) 
  ## This is using the filtering capabilities to find the ExternalIP of the worker node
  if [ ! -z "$typeFilter" ] 
  then 
    HOST_ADDRESSES=$(oc get node $HOST_NODE -o custom-columns="ADDRESS":".status.addresses[?(@.type==\"${typeFilter}\")].address" --no-headers 2>/dev/null) 
    # Example: 
    # HOST_ADDRESSES=$(oc get node $HOST_NODE -o custom-columns="ADDRESS":'.status.addresses[?(@.type=="ExternalIP")].address' --no-headers 2>/dev/null)
  else
    HOST_ADDRESSES=$(oc get node $HOST_NODE -o custom-columns="ADDRESSES":'.status.addresses[*].address' --no-headers 2>/dev/null)
  fi

  echo $HOST_ADDRESSES
}
