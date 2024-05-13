#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2023. All Rights Reserved.
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
#     ibm_cp4a_cr_template.003.ent.FoundationContentApplication.yaml
#     ibm_cp4a_cr_template.005.ent.FoundationContentApplicationBawauth.yaml
#     ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml
#     ibm_cp4a_cr_template.200.ent.ClientOnboardingDemoWithADP.yaml
cp4baTemplateToUse=ibm_cp4a_cr_template.201.ent.ClientOnboardingDemoWithADPOneDB.yaml

# OCP Project Name for DB2, for example ibm-db2
db2OnOcpProjectName=ibm-db2

# Password for DB2 Admin User (Admin User name see below), for example passw0rd
db2AdminUserPassword=Cp4badm1n

# DB2 Standard license key base64 encoded
#   If this key is not available, leave empty (but remove the value 'REQUIRED') - then the Community edition is used that allows less CPU & RAM
#   In that case, also update parameters db2Cpu and db2Memory below (the defaults there assume you have a DB2 Standard license available)
db2StandardLicenseKey=

# CPUs to assign to DB2 pod (max with DB2 Standard license is 16, max with Community edition is 4)
# If you use two DB2 pods, assign 50% of the suggested values, each DB2 pod will be set up with specified db2Cpu
#   If you selected CP4BA template     ibm_cp4a_cr_template.001.ent.Foundation.yaml                              set it to 4
#   If you selected CP4BA template     ibm_cp4a_cr_template.002.ent.FoundationContent.yaml                       set it to 4
#   If you selected CP4BA template     ibm_cp4a_cr_template.003.ent.FoundationContentApplication.yaml            set it to 4
#   If you selected CP4BA template     ibm_cp4a_cr_template.005.ent.FoundationContentApplicationBawauth.yaml     set it to 5
#   If you selected CP4BA template     ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml                    set it to 16
#   If you selected CP4BA template     ibm_cp4a_cr_template.200.ent.ClientOnboardingDemoWithADP.yaml             set it to 16
db2Cpu=16

# RAM to assign to DB2 pod (max with DB2 Standard license is 128Gi, max with Community edition is 16Gi)
# If you use two DB2 pods, assign 50% of the suggested values, each DB2 pod will be set up with specified db2Memory
#   If you selected CP4BA template     ibm_cp4a_cr_template.001.ent.Foundation.yaml                              set it to 16Gi
#   If you selected CP4BA template     ibm_cp4a_cr_template.002.ent.FoundationContent.yaml                       set it to 16Gi
#   If you selected CP4BA template     ibm_cp4a_cr_template.003.ent.FoundationContentApplication.yaml            set it to 16Gi
#   If you selected CP4BA template     ibm_cp4a_cr_template.005.ent.FoundationContentApplicationBawauth.yaml     set it to 26Gi
#   If you selected CP4BA template     ibm_cp4a_cr_template.100.ent.ClientOnboardingDemo.yaml                    set it to 110Gi
#   If you selected CP4BA template     ibm_cp4a_cr_template.200.ent.ClientOnboardingDemoWithADP.yaml             set it to 110Gi
db2Memory=110Gi



# -----------------------------------------------------
# --- Parameters that usually do NOT need an update ---
# -----------------------------------------------------

# --- If changes are needed here, provide those BEFORE running script 02-createDb2OnOCP.sh ---

# Version of DB2 operator to install. Change only when a new operator version should be used.
db2OperatorVersion=db2u-operator.v110509.0.0

# Channel version for Operator updates. Change only if a new DB2 operator version requires a new channel version.
db2OperatorChannel=v110509.0

# DB2 instance version to be created. Change only when a new version of DB2 should be used.  
# This version of DB2 must be supported by the Operator version installed as specified above.
db2InstanceVersion=s11.5.9.0

# Indicate if to install DB2 containerized on the OpenShift cluster (true/false)
db2UseOnOcp=true

# DB2 instance access information.
# This uses the DB2 nodeport service name to access DB2

# Following parameters can be set in case $db2UseOnOcp == true, they are not used for the $db2UseOcp == false case
# Up to two containerized DB2 instances can be set-up, see the CR.yaml template files, these two parameters specify their names
db2HostName[1]=db2server1
db2HostName[2]=db2server2

# If the service name is used, the port is 5000 and does not need to be changed
# If using IP address or a HAProxy to access the node port, the port number
# would need to change
db2PortNumber[1]=50000
db2PortNumber[2]=50000

# IP for DB2 instance access information. If IP must be specified use, otherwise leave as specified
db2HostIp[1]=${db2HostName[1]}
db2HostIp[2]=${db2HostName[2]}

# When enabling SSL, make sure to use the correct port above, and specify below the db2SslSecretName that contains the ssl certificate
db2SslEnabled=false

# Leave empty ("") if db2SslEnabled is set to false, otherwise create this secret manually and provide it's name here
db2SslSecretName[1]=""
db2SslSecretName[2]=""

# DB2 Admin User name - when using Db2 on OCP pls. do not change db2AdminUserName, it must be "db2inst1"
db2AdminUserName=db2inst1

# Deployment platform, either ROKS or OCP
cp4baDeploymentPlatform=OCP

# Name of the storage class used for DB2's PVC
db2OnOcpStorageClassName=nfs-client

# Size of the PVC for DB2 (on ROKS: the larger the faster, good performance with 500Gi)
db2StorageSize=500Gi

# Database activation delay. Scripts will wait this time in seconds between activating databases.
# With problems on activation, or if on slow environments, try to increase this delay
db2ActivationDelay=5

# Number of DBs that should be supported by the DB instance
db2NumOfDBsSupported=30

# CP4BA Database Name information
db2IcndbName=ICNDB
db2ClosName=CLOS
db2Devos1Name=DEVOS1
db2AeosName=AEOS
db2BawDocsName=BAWDOCS
db2BawTosName=BAWTOS
db2BawDosName=BAWDOS
db2BawDbName=BAWDB
db2AppdbName=APPDB
db2AedbName=AEDB
db2GcddbName=GCDDB
db2OdmdbName=ODMDB

# Indicate if you want to deploy ADP, if so provide the ADP Database Name information

# ADP Configuration
# The DB Instance for the ADP databases is the one on which ADP is mentioned in the template file in this comment:
# DBs on Instance 2: DEVOS1 GCD BAS ADP

# Name of the base Content Analizer database for ADP
db2CaBasedbName=BASECA

# All tenant DBs will be created using this prexi
db2TenantDBPrefix=PDB
numberTenantDBs=6

# --- end of file ---


