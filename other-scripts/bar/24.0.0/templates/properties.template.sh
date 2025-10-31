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

# DO NOT CHANGE THIS FILE

# This script is for holding the Backup And Restore (BAR) properties generated when scaling down a deployment.
#    Only tested with CP4BA version: 24.0.0, dedicated common services set-up

echo "  Reading properties.sh ..."

# -----------------------------------------------------
# --- Parameters captured                           ---
# -----------------------------------------------------

cp4baProjectNamespace=§cp4baProjectNamespace

cp4baSuspendedCronJobs=§cp4baSuspendedCronJobs

cp4baCommonWebUiReplicaSize=§cp4baCommonWebUiReplicaSize

cp4baInsightsEngineFlinkTaskmanagerReplicaSize=§cp4baInsightsEngineFlinkTaskmanagerReplicaSize

# --- end of file ---



