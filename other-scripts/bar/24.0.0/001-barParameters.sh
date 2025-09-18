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

# This script is for holding the Backup And Restore (BAR) parameters for a specific backup or restore.
#    Only tested with CP4BA version: 21.0.3 IF029 and IF039, dedicated common services set-up

echo "  Reading 001-barParameters.sh ..."

# ----------------------------------------------
# --- Parameters that usually need an update ---
# ----------------------------------------------

# --- Provide those BEFORE running any other bar script ---

# OCP project name for CP4BA to backup/restore, for example ibm-cp4ba
cp4baProjectName=ibm-cp4ba-dev

# If URLs are protected, provide here the information to be used to get the authorization token, if a token is not needed, remove REQUIRED
useTokenForZenRoute=false
useTokenForInsightsengineManagementURL=false
useTokenForOpensearchRoute=false
barTokenUser=cp4badmin               # example value: $(oc -n $cp4baProjectName get secret ibm-fncm-secret -o jsonpath='{.data.appLoginUsername}' | base64 -d)
barTokenPass=passw0rd                # example value: $(oc -n $cp4baProjectName get secret ibm-fncm-secret -o jsonpath='{.data.appLoginPassword}' | base64 -d)
barCp4baHost=cpd-ibm-cp4ba-dev.apps.ocp.ibm.edu      # example value: $(oc -n $cp4baProjectName get route cpd -o jsonpath="{.spec.host}")
baw_cust_host=cpd-ibm-cp4ba-dev.apps.ocp.ibm.edu     # example value: $(oc -n $cp4baProjectName get route <your-custom-route-name> -o jsonpath="{.spec.host}")
resolve_ip=10.100.1.2                  # example value: $(getent hosts "$baw_cust_host" | awk '{ print $1 }')
barTokenResolveCp4ba=cpd-ibm-cp4ba-dev.apps.ocp.ibm.edu:443:10.100.1.2        # example value: ${barCp4baHost}:443:${resolve_ip}

# Name of the storage class used to create temp PVCs during backup/restore
pvcStorageClassName="nfs-client"

# Information for backing up or restoring Persistent Volumes

# Name of a directory on the storage server, in which the persistent volume backups should be stored, or from where backups are restored
pvBackupDirectory="\$HOME/backup"

# Array of names of the Storage classes used in the entire deployment that need to get backed up / restored
barStorageClass=()

# Array of backup/restore methods to be used, for now only "ServerBackup" is supported
barMethod=()

# Array of additional configuration data formatted as JSON:
# - "rootDirectory" - Required, the root directory on the storage server where the PVs to backup or restore can be found
barConfigData=()

# Example #1 for information for backup up Persistent Volumes, please adapt accordingly
barStorageClass[0]="nfs-client"
barMethod[0]="ServerBackup"
barConfigData[0]='{ "rootDirectory": "/export" }'

# Example #2 for information for backup up Persistent Volumes, please adapt accordingly or remove if only one storage class is used
barStorageClass[1]="nfs-client-fast"
barMethod[1]="ServerBackup"
barConfigData[1]='{ "rootDirectory": "/faststorage" }'

# Add further array entries as needed here, if more than two storage classes are in use



# -----------------------------------------------------
# --- Parameters that usually do NOT need an update ---
# -----------------------------------------------------

# --- If changes are needed here, provide those BEFORE running any other bar script ---

# Not all resources might be required to be backed up, specify here which to skip, comma separated list of resource types
barSkipToBackupResourceKinds=pod,event,event.events.k8s.io,packagemanifest.packages.operators.coreos.com,podmetrics.metrics.k8s.io



# --- end of file ---



