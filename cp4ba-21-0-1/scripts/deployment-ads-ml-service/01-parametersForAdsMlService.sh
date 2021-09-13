#!/bin/bash
# set -x
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

echo "    Reading 01-parametersForAdsMlService.sh ..."

# ----------------------------------------------
# --- Parameters that usually need an update ---
# ----------------------------------------------

# --- Provide those BEFORE running any of the other scripts, for example 02-deployPostgres.sh ---

# OCP Project Name for the ADS ML Service, for example ibm-ads-ml-service
adsMlServiceProjectName=REQUIRED

# Path and filename to the ML Service Image archive that got build before, for example /data/ads-ml-service.tar
adsMlServiceImageArchive=REQUIRED

# Password for Postgress admin, for example passw0rd
pgAdminPassword=REQUIRED



# -----------------------------------------------------
# --- Parameters that usually do NOT need an update ---
# -----------------------------------------------------

# --- If changes here are needed, provide those BEFORE running any of the other scripts, for example 02-deployPostgres.sh ---

# Storage Class to use for PVCs / PVs
adsMlServiceStorageClassName=cp4a-file-delete-gold-gid

# Postgress speciffic parameters
pgServiceAccount=postgres
pgPostgresStorage=20Gi

# Number of pods to create for the ADS ML Service - for Demo purposes one is sufficent, if High Availability is needed, increase to two
adsMlServiceReplicaCount=1



# --- end of file ---



