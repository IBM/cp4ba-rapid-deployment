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

echo "  Reading 05-parametersForCp4ba.sh ..."

# ----------------------------------------------
# --- Parameters that usually need an update ---
# ----------------------------------------------

# --- Provide those BEFORE running script 06-prepareCp4baDeployment.sh ---

# OCP project name for CP4BA, for example ibm-cp4ba - make sure to use the same value as used before when running script cp4a-clusteradmin-setup.sh
cp4baProjectName=REQUIRED

# TLS secret name - see also secret name in project ibm-cert-store
#   If this secret is not available, leave empty (but remove the value 'REQUIRED') - then self-signed certificates will be used at the routes
cp4baTlsSecretName=REQUIRED

# Password for CP4BA Admin User (cp4baAdminName name see below), for example passw0rd - see ldif file you applied to LDAP
cp4baAdminPassword=REQUIRED

# Password for LDAP Admin User (ldapAdminName name see below), for example passw0rd - use the password that you specified when setting up LDAP
ldapAdminPassword=REQUIRED

# LDAP instance access information - hostname or IP
ldapServer="REQUIRED"



# -----------------------------------------------------
# --- Parameters that usually do NOT need an update ---
# -----------------------------------------------------

# --- If changes are needed here, provide those BEFORE running script 06-prepareCp4baDeployment.sh ---

# --- CP4BA settings ---
cp4baAdminName=cp4badmin
cp4baAdminGroup=cp4badmins
cp4baUsersGroup=cp4bausers
cp4baAdminFullName="cn=cp4badmin,dc=example,dc=com"
cp4baGroupAdminFullName="cn=cp4badmins,dc=example,dc=com"
# --- OCP Hostname ---
# OCP hostname
cp4baOcpHostname=

# --- Content OS Settings ---
contentOSname=CONTENT
contentOSasa=content_storage
contentOSsd=content_file_system_storage

# --- LDAP settings ---

# LDAP name - don't use dashes (-), only use underscores
ldapName=ldap_custom

ldapAdminName=cn=root

ldapType="IBM Security Directory Server"
ldapPort="389"
ldapSslEnabled=false
# leave empty ("") if ldapSslEnabled is set to false, otherwise create this secret manually and provide it's name here
ldapSslSecretName=""
ldapBaseDn="dc=example,dc=com"
ldapUserNameAttribute="*:cn"
ldapUserDisplayNameAttr="displayName"
ldapGroupBaseDn="dc=example,dc=com"
ldapGroupNameAttribute="*:cn"
ldapGroupDisplayNameAttr="cn"
ldapGroupMembershipSearchFilter="(\|(\&(objectclass=groupOfNames)(member={0}))(\&(objectclass=groupOfUniqueNames)(uniqueMember={0})))"
ldapGroupMemberIdMap="groupofnames:member"
ldapAdGcHost=
ldapAdGcPort=
ldapAdUserFilter="(\&(samAccountName=%v)(objectClass=user))"
ldapAdGroupFilter="(\&(samAccountName=%v)(objectclass=group))"
ldapTdsUserFilter="(\&(cn=%v)(objectclass=person))"
ldapTdsGroupFilter="(\&(cn=%v)(\|(objectclass=groupofnames)(objectclass=groupofuniquenames)(objectclass=groupofurls)))"

# --- Storage Class Settings ---
cp4baScSlow=nfs-client
cp4baScMedium=nfs-client
cp4baScFast=nfs-client
cp4baBlockScFast=nfs-client

# --- HA Settings ---
cp4baDeploymentProfileSize=small
cp4baADPDeploymentProfileSize=entry

cp4baReplicaCount=1
cp4baBaiJobParallelism=1



# --- end of file ---


