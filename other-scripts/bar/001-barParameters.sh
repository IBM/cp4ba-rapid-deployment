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
#    Only tested with CP4BA version: 21.0.3 IF034, dedicated common services set-up

echo "  Reading 001-barParameters.sh ..."

# ----------------------------------------------
# --- Parameters that usually need an update ---
# ----------------------------------------------

# --- Provide those BEFORE running any other bar script ---

# OCP project name for CP4BA to backup/restore, for example ibm-cp4ba
cp4baProjectName=REQUIRED

# If URLs are protected, provide here the information to be used to get the authorization token, if a token is not needed, remove REQUIRED
useTokenForInsightsengineManagementURL=false
useTokenForElasticsearchRoute=false
barTokenUser=REQUIRED
barTokenPass=REQUIRED
barTokenResolveCp4ba=REQUIRED
barCp4baHost=REQUIRED

# Name of a directory, in which the persistent volume backups should be stored on the storage server
pvBackupDirectory="\$HOME/backup"

# Name of the storage class used to create temp PVCs during backup/restore
pvcStorageClassName="nfs-client"

# Information for backup up Persistent Volumes
# Name of the Storage classes
barStorageClass=()

# Backup method. For now support only ServerBackup
barMethod=()

# Further Information which is needed. Data formatted as JSON.
barConfigData=()

barStorageClass[0]="nfs-client"
barMethod[0]="ServerBackup"
barConfigData[0]='{ "rootDirectory": "/export"}'

barStorageClass[1]="nfs-client-fast"
barMethod[1]="ServerBackup"
barConfigData[1]='{ "rootDirectory": "/faststorage"}'



# -----------------------------------------------------
# --- Parameters that usually do NOT need an update ---
# -----------------------------------------------------

# --- If changes are needed here, provide those BEFORE running any other bar script ---

# Not all resources might be required to be backed up, specify here which to skip, comma separated list of resource types
barSkipToBackupResourceKinds=pod,event,event.events.k8s.io,packagemanifest.packages.operators.coreos.com,podmetrics.metrics.k8s.io



# --- end of file ---



