ls -l

oc project ibm-cp4ba-test
oc project ibm-cp4ba-qa

oc get pods | grep ibm-cp4a-operator- | awk '$1 {print$1}' | while read vol; do oc cp jdbc ${vol}:/opt/ansible/share/; done

oc apply -f secrets.yaml

test:
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
##########
# Do not modify this file, it will get updated automatically by the scripts
##########
# LDAP bind secret - goes in CR YAML under: spec:ldap_configuration:lc_bind_secret:
apiVersion: v1
kind: Secret
metadata:
  name: ldap-bind-secret
type: Opaque
stringData:
  ldapUsername: "cn=root"
  ldapPassword: "passw0rd123"
---
# Shared Encryption Key Secret - goes in CR YAML under: spec:shared_configuration:encryption_key_secret:
apiVersion: v1
kind: Secret
metadata:
  name: icp4a-shared-encryption-key
type: Opaque
stringData:
  encryptionKey: "passw0rd"
---
# BAN Secret - goes in CR YAML under: spec:navigator_configuration:ban_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-ban-secret
type: Opaque
stringData:
  navigatorDBUsername: "db2inst1"
  navigatorDBPassword: "passw0rd"
  ldapUsername: "cn=root"
  ldapPassword: "passw0rd123"
  appLoginUsername: "cp4badmin"
  appLoginPassword: "passw0rd"
  ltpaPassword: "passw0rd"
  keystorePassword: "passw0rd"
---
# FNCM Secret - goes in CR YAML under: spec:ecm_configuration:fncm_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-fncm-secret
type: Opaque
stringData:
  gcdDBUsername: "db2inst1"
  gcdDBPassword: "passw0rd"
  closDBUsername: "db2inst1"
  closDBPassword: "passw0rd"
  devos1DBUsername: "db2inst1"
  devos1DBPassword: "passw0rd"
  aeosDBUsername: "db2inst1"
  aeosDBPassword: "passw0rd"
  bawdocsDBUsername: "db2inst1"
  bawdocsDBPassword: "passw0rd"
  bawtosDBUsername: "db2inst1"
  bawtosDBPassword: "passw0rd"
  bawdosDBUsername: "db2inst1"
  bawdosDBPassword: "passw0rd"
  ldapUsername: "cn=root"
  ldapPassword: "passw0rd123"
  appLoginUsername: "cp4badmin"
  appLoginPassword: "passw0rd"
  ltpaPassword: "passw0rd"
  keystorePassword: "passw0rd"
---
# BAS server admin secret - goes in CR YAML under: spec:bastudio_configuration:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: icp4adeploy-bas-admin-secret
type: Opaque
stringData:
  dbUsername: "db2inst1"
  dbPassword: "passw0rd"
---
# AE server admin secret - goes in CR YAML under: spec:bastudio_configuration:playback_server:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: playback-server-admin-secret
type: Opaque
stringData:
  AE_DATABASE_USER: "db2inst1"
  AE_DATABASE_PWD: "passw0rd"
  REDIS_PASSWORD: "passw0rd"
---
# AAE Secret - goes in CR YAML under: spec:application_engine_configuration:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: icp4adeploy-workspace-aae-app-engine-admin-secret
type: Opaque
stringData:
  AE_DATABASE_USER: "db2inst1"
  AE_DATABASE_PWD: "passw0rd"
  REDIS_PASSWORD: "passw0rd"
---
# Capture Secret - goes in CR YAML under: spec: - not used atm, not found to be used in any of the CRs
apiVersion: v1
kind: Secret
metadata:
  name: ibm-adp-secret
type: Opaque
stringData:
  serviceUser: "cn=cp4badmin,dc=example,dc=com"
  servicePwd: "passw0rd"
  serviceUserBas: "cn=cp4badmin,dc=example,dc=com"
  servicePwdBas: "passw0rd"
  serviceUserCa: "cn=cp4badmin,dc=example,dc=com"
  servicePwdCa: "passw0rd"
  envOwnerUser: "cn=cp4badmin,dc=example,dc=com"
  envOwnerPwd: "passw0rd"
  mongoPwd: "passw0rd"
  mongoUser: "mongo"
---
# BAW Authoring DB Secret - goes in CR YAML under: spec:workflow_authoring_configuration:database:secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-bawaut-server-db-secret
type: Opaque  
stringData:
  dbUser: "db2inst1"
  password: "passw0rd"
---  
# BAW PFS Admin Secreeet - goes in CR YAML under: spec:pfs_configuration:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-pfs-admin-secret
type: Opaque
stringData:
  ltpaPassword: "passw0rd"
  oidcClientPassword: "passw0rd"
  sslKeyPassword: "passw0rd"
---
# BAW Authoring Admin Secret - goes in CR YAML under: spec:workflow_authoring_configuration:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-bawaut-admin-secret
type: Opaque
stringData:
  oidcClientPassword: "passw0rd"
  sslKeyPassword: "passw0rd"

qa:
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
##########
# Do not modify this file, it will get updated automatically by the scripts
##########
# LDAP bind secret - goes in CR YAML under: spec:ldap_configuration:lc_bind_secret:
apiVersion: v1
kind: Secret
metadata:
  name: ldap-bind-secret
type: Opaque
stringData:
  ldapUsername: "cn=root"
  ldapPassword: "passw0rd123"
---
# Shared Encryption Key Secret - goes in CR YAML under: spec:shared_configuration:encryption_key_secret:
apiVersion: v1
kind: Secret
metadata:
  name: icp4a-shared-encryption-key
type: Opaque
stringData:
  encryptionKey: "passw0rd"
---
# RR admin secret - goes in CR YAML under: spec:resource_registry_configuration:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: resource-registry-admin-secret
type: Opaque
stringData:
  rootPassword: "passw0rd"
  readUser: "reader"
  readPassword: "passw0rd"
  writeUser: "writer"
  writePassword: "passw0rd"
---
# BAN Secret - goes in CR YAML under: spec:navigator_configuration:ban_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-ban-secret
type: Opaque
stringData:
  navigatorDBUsername: "db2inst1"
  navigatorDBPassword: "passw0rd"
  ldapUsername: "cn=root"
  ldapPassword: "passw0rd123"
  appLoginUsername: "cp4badmin"
  appLoginPassword: "passw0rd"
  ltpaPassword: "passw0rd"
  keystorePassword: "passw0rd"
---
# FNCM Secret - goes in CR YAML under: spec:ecm_configuration:fncm_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-fncm-secret
type: Opaque
stringData:
  gcdDBUsername: "db2inst1"
  gcdDBPassword: "passw0rd"
  closDBUsername: "db2inst1"
  closDBPassword: "passw0rd"
  devos1DBUsername: "db2inst1"
  devos1DBPassword: "passw0rd"
  aeosDBUsername: "db2inst1"
  aeosDBPassword: "passw0rd"
  bawdocsDBUsername: "db2inst1"
  bawdocsDBPassword: "passw0rd"
  bawtosDBUsername: "db2inst1"
  bawtosDBPassword: "passw0rd"
  bawdosDBUsername: "db2inst1"
  bawdosDBPassword: "passw0rd"
  ldapUsername: "cn=root"
  ldapPassword: "passw0rd123"
  appLoginUsername: "cp4badmin"
  appLoginPassword: "passw0rd"
  ltpaPassword: "passw0rd"
  keystorePassword: "passw0rd"
---
# BAS server admin secret - goes in CR YAML under: spec:bastudio_configuration:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: icp4adeploy-bas-admin-secret
type: Opaque
stringData:
  dbUsername: "db2inst1"
  dbPassword: "passw0rd"
---
# AE server admin secret - goes in CR YAML under: spec:bastudio_configuration:playback_server:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: playback-server-admin-secret
type: Opaque
stringData:
  AE_DATABASE_USER: "db2inst1"
  AE_DATABASE_PWD: "passw0rd"
  REDIS_PASSWORD: "passw0rd"
---
# AAE Secret - goes in CR YAML under: spec:application_engine_configuration:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: icp4adeploy-workspace-aae-app-engine-admin-secret
type: Opaque
stringData:
  AE_DATABASE_USER: "db2inst1"
  AE_DATABASE_PWD: "passw0rd"
  REDIS_PASSWORD: "passw0rd"
---
# Capture Secret - goes in CR YAML under: spec: - not used atm, not found to be used in any of the CRs
apiVersion: v1
kind: Secret
metadata:
  name: ibm-adp-secret
type: Opaque
stringData:
  serviceUser: "cn=cp4badmin,dc=example,dc=com"
  servicePwd: "passw0rd"
  serviceUserBas: "cn=cp4badmin,dc=example,dc=com"
  servicePwdBas: "passw0rd"
  serviceUserCa: "cn=cp4badmin,dc=example,dc=com"
  servicePwdCa: "passw0rd"
  envOwnerUser: "cn=cp4badmin,dc=example,dc=com"
  envOwnerPwd: "passw0rd"
  mongoPwd: "passw0rd"
  mongoUser: "mongo"
---
# BAW Authoring DB Secret - goes in CR YAML under: spec:workflow_authoring_configuration:database:secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-bawaut-server-db-secret
type: Opaque  
stringData:
  dbUser: "db2inst1"
  password: "passw0rd"
---  
# BAW PFS Admin Secreeet - goes in CR YAML under: spec:pfs_configuration:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-pfs-admin-secret
type: Opaque
stringData:
  ltpaPassword: "passw0rd"
  oidcClientPassword: "passw0rd"
  sslKeyPassword: "passw0rd"
---
# BAW Authoring Admin Secret - goes in CR YAML under: spec:workflow_authoring_configuration:admin_secret_name:
apiVersion: v1
kind: Secret
metadata:
  name: ibm-bawaut-admin-secret
type: Opaque
stringData:
  oidcClientPassword: "passw0rd"
  sslKeyPassword: "passw0rd"
