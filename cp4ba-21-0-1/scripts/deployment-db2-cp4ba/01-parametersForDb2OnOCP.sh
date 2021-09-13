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

echo "  Reading 01-parametersForDb2OnOCP.sh ..."

# ----------------------------------------------
# --- Parameters that usually need an update ---
# ----------------------------------------------

# --- Provide those BEFORE running script 02-createDb2OnOCP.sh ---

# Selected CP4BA template to use for deployment, for example ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml
#   Available templates:
#     ibm_cp4a_cr_template.001.ent.Foundation.yaml
#     ibm_cp4a_cr_template.002.ent.FoundationContent.yaml
#     ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml
cp4baTemplateToUse=ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml

# OCP Project Name for DB2, for example ibm-db2
db2OnOcpProjectName=REQUIRED

# Password for DB2 Admin User (Admin User name see below), for example passw0rd
db2AdminUserPassword=REQUIRED

# DB2 Standard license key base64 encoded
#   If this key is not available, leave empty (but remove the value 'REQUIRED') - then the Community edition is used that allows less CPU & RAM
#   In that case, also update parameters db2Cpu and db2Memory below (the defaults there assume you have a DB2 Standard license available)
db2StandardLicenseKey=REQUIRED

# CPUs to assign to DB2 pod (max with DB2 Standard license is 16, max with Community edition is 4)
#   If you selected CP4BA template     ibm_cp4a_cr_template.001.ent.Foundation.yaml               set it to 4
#   If you selected CP4BA template     ibm_cp4a_cr_template.002.ent.FoundationContent.yaml        set it to 4
#   If you selected CP4BA template     ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml     set it to 16
db2Cpu=16

# RAM to assign to DB2 pod (max with DB2 Standard license is 128Gi, max with Community edition is 16Gi)
#   If you selected CP4BA template     ibm_cp4a_cr_template.001.ent.Foundation.yaml               set it to 16Gi
#   If you selected CP4BA template     ibm_cp4a_cr_template.002.ent.FoundationContent.yaml        set it to 16Gi
#   If you selected CP4BA template     ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml     set it to 110Gi
db2Memory=110Gi



# --- Provide those AFTER running script 02-createDb2OnOCP.sh (see output of script 02-createDb2OnOCP.sh) ---

# DB2 instance access information - host name or IP to access DB2 instance(see output of script 02-createDb2OnOCP.sh)
# This value can be either a hostname or an IP
db2HostName=REQUIRED

# DB2 instance access information - port number (see output of script 02-createDb2OnOCP.sh)
db2PortNumber=REQUIRED



# -----------------------------------------------------
# --- Parameters that usually do NOT need an update ---
# -----------------------------------------------------

# --- If changes are needed here, provide those BEFORE running script 02-createDb2OnOCP.sh ---

# Version of DB2 operator to install.  For swat-dev-01 use db2u-operator.v1.0.5 otherwise leave as specified.
# Change only when a new operator version should be used.
db2OperatorVersion=db2u-operator.v1.1.3

# Channel version for Operator updates. For swat-dev-01 use v1.0 otherwise leave as specified. 
# Change only if a new DB2 operator version requires a new channel version.
db2OperatorChannel=v1.1

# DB2 instance version to be created.   For swat-dev-01 use 11.5.5.0-cn4 otherwise leave as specified.
# Change only when a new version of DB2 should be used.  
# This version of DB2 must be supported by the Operator version installed as specified above.
db2InstanceVersion=11.5.6.0

# Indicate if to install DB2 containerized on the OpenShift cluster (true/false)
db2UseOnOcp=true

# IP for DB2 instance access information.  If IP must be specified use otherwise leave as specified
db2HostIp=$db2HostName

# DB2 Admin User name - when using Db2 on OCP pls. do not change db2AdminUserName, it must be "db2inst1"
db2AdminUserName=db2inst1

# Deployment platform, either ROKS or OCP
cp4baDeploymentPlatform=ROKS

# Name of the storage class used for DB2's PVC
db2OnOcpStorageClassName=cp4a-file-delete-gold-gid

# Size of the PVC for DB2 (on ROKS: the larger the faster, good performance with 500Gi)
db2StorageSize=500Gi

# CP4BA Database Name information
db2UmsdbName=UMSDB
db2IcndbName=ICNDB
db2Devos1Name=DEVOS1
db2AeosName=AEOS
db2BawDocsName=BAWDOCS
db2BawTosName=BAWTOS
db2BawDosName=BAWDOS
db2BawDbName=BAWDB
db2AppdbName=APPDB
db2AedbName=AEDB
db2BasdbName=BASDB
db2GcddbName=GCDDB

# --- end of file ---



