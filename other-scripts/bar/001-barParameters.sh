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
cp4baProjectName=ibm-cp4ba-dev

# Not all resources might be required to be backed up, specify here which to skip
barSkipToBackupResourceKinds=event,event.events.k8s.io,packagemanifest.packages.operators.coreos.com



# -----------------------------------------------------
# --- Parameters that usually do NOT need an update ---
# -----------------------------------------------------

# --- If changes are needed here, provide those BEFORE running any other bar script ---



# --- end of file ---



