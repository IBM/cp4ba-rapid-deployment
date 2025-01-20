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

# This script is for preparing the Backup And Restore (BAR) process, performing backup on all CP4BA components in the given namespace.
#    Only tested with CP4BA version: 21.0.3 IF034, dedicated common services set-up

# Reference: 
# - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=recovery-backing-up-your-environments
# - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=elasticsearch-taking-restoring-snapshots-data
# - https://community.ibm.com/community/user/automation/blogs/dian-guo-zou/2022/10/12/backup-and-restore-baw-2103

# Check if jq is installed
type jq > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo "Please install jq to continue."
  exit 1
fi

# Check if yq is installed
type yq > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo "Please install yq (https://github.com/mikefarah/yq/releases) to continue."
  exit 1
fi

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import common utilities
source ${CUR_DIR}/common.sh
DATETIMESTR=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="$CUR_DIR/Backup_${DATETIMESTR}.log"

echo "Details will be logged to $LOG_FILE."

INPUT_PROPS_FILENAME="001-barParameters.sh"
INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${INPUT_PROPS_FILENAME}"

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   logInfo "Found ${INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   
   . $INPUT_PROPS_FILENAME_FULL
   
   if [ $cp4baProjectName == "REQUIRED" ] || [ "$cp4baTlsSecretName" == "REQUIRED" ] || [ $cp4baAdminPassword == "REQUIRED" ] || [ $ldapAdminPassword == "REQUIRED" ] || [ $ldapServer == "REQUIRED" ]; then
      logError "File ${INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      exit 1
   fi

   logInfo "Done!"
else
   logError "File ${INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   exit 1
fi

echo -e "\x1B[1mThis script will backup the CP4BA environment deployed in ${cp4baProjectName}.\n \x1B[0m"

printf "Do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
   echo
   echo -e "Backing up CP4BA deployment in namespace ${cp4baProjectName}..."
   echo
   ;;
*)
   echo
   echo -e "Exiting..."
   echo
   exit 0
   ;;
esac

##### Preparation ##############################################################
# Verify OCP Connecction
logInfo "Verifying OC CLI is connected to the OCP cluster..."

WHOAMI=$(oc whoami)
logInfo "WHOAMI =" $WHOAMI

if [[ "$WHOAMI" == "" ]]; then
   logError "OC CLI is NOT connected to the OCP cluster. Please log in first with an admin user to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
   exit 1
fi

# switch to CP4BA project
logInfo "Switching to project ${cp4baProjectName}..."

CP4BA_PROJECT=$(oc project --short)
logInfo "CP4BA project =" $CP4BA_PROJECT
   
if [[ "$project" != "$cp4baProjectName" ]]; then
   oc project $cp4baProjectName
fi

# Create backup directory
logInfo "Creating backup directory..."
BACKUP_DIR=$CUR_DIR/backup_${DATETIMESTR}
mkdir -p $BACKUP_DIR/{secrets,pvc,postgresql,flink}

##### Backup CR ################################################################
# Get CP4BA depoyment name
CP4BA_NAME=$(oc get ICP4ACluster -o name |cut -d "/" -f 2)
logInfo "CP4BA deployment name: $CP4BA_NAME"

# Save the CR to local disk
logInfo "Saving CP4BA CR to $BACKUP_DIR ..."
oc get ICP4ACluster $CP4BA_NAME -o yaml > ${BACKUP_DIR}/CR.yaml

##### Backup secrets ###########################################################
# Save the CR to local so that we don't need retrieve it multiple times
oc get ICP4ACluster $CP4BA_NAME -o json > ${BACKUP_DIR}/CRTMP.json

# Find CP4BA version
CP4BA_VERSION=$(jq -r .spec.appVersion ${BACKUP_DIR}/CRTMP.json)
logInfo "Found CP4BA version: $CP4BA_VERSION"

# Find CP4BA deployment name
CP4BA_NAME=$(jq -r .metadata.name ${BACKUP_DIR}/CRTMP.json)

#cpe-oidc-secret
if oc get secret ${CP4BA_NAME}-cpe-oidc-secret > /dev/null 2>&1; then
  logInfo "Backing up ${CP4BA_NAME}-cpe-oidc-secret..."
  oc get secret ${CP4BA_NAME}-cpe-oidc-secret -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/${CP4BA_NAME}-cpe-oidc-secret.yaml
fi

#platform-oidc-credentials
logInfo "Backing up WLP_CLIENT_ID..."
WLP_CLIENT_ID=$(oc get secret platform-oidc-credentials -o jsonpath='{.data.WLP_CLIENT_ID}' | base64 -d )
echo $WLP_CLIENT_ID > ${BACKUP_DIR}/wlp_client_id

logInfo "Backing up WLP_CLIENT_SECRET..."
WLP_CLIENT_SECRET=$(oc get secret platform-oidc-credentials -o jsonpath='{.data.WLP_CLIENT_SECRET}' | base64 -d)
echo $WLP_CLIENT_SECRET > ${BACKUP_DIR}/wlp_client_secret

#secret admin-user-details
logInfo "Backing up admin-user-details secret..."
oc get secret admin-user-details -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences)'  > ${BACKUP_DIR}/secrets/admin-user-details.yaml

# Shared Encryption Key - use the name defined in CR, or default name
SECRET_SHARED_ENCRYPTION_KEY=icp4a-shared-encryption-key
if jq --exit-status -r .spec.shared_configuration.encryption_key_secret ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  # use the name defined in CR
  SECRET_SHARED_ENCRYPTION_KEY=$(jq -r .spec.shared_configuration.encryption_key_secret ${BACKUP_DIR}/CRTMP.json)
fi
logInfo "Backing up $SECRET_SHARED_ENCRYPTION_KEY..."
oc get secret $SECRET_SHARED_ENCRYPTION_KEY -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_SHARED_ENCRYPTION_KEY.yaml

# Entitlement Key - Skip, user should have that. 

# LDAP bind secret
if jq --exit-status -r .spec.ldap_configuration.lc_bind_secret ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up LDAP bind secret..."
  SECRET_LDAP_BIND=$(jq -r .spec.ldap_configuration.lc_bind_secret ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_LDAP_BIND -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_LDAP_BIND.yaml
fi

# LDAP SSL secret
if jq --exit-status -r .spec.ldap_configuration.lc_ldap_ssl_secret_name ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up LDAP SSL secret..."
  SECRET_LDAP_SSL=$(jq -r .spec.ldap_configuration.lc_ldap_ssl_secret_name ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_LDAP_SSL -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_LDAP_SSL.yaml
fi

# Workflow Runtime database secret
CP4BA_BAW_INSTANCE_COUNT=$(jq -r .spec.baw_configuration ${BACKUP_DIR}/CRTMP.json | jq 'length')
for ((i=0; i<$CP4BA_BAW_INSTANCE_COUNT; i++)); do
  SECRET_WORKFLOW_DB=$(jq -r .spec.baw_configuration[$i].database.secret_name ${BACKUP_DIR}/CRTMP.json)
  logInfo "Backing up Workflow database secret $i..."
  oc get secret $SECRET_WORKFLOW_DB -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_WORKFLOW_DB.yaml
done

# Workflow Authoring database secret
if jq --exit-status -r .spec.workflow_authoring_configuration.database.secret_name ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up Workflow Authoring database secret..."
  SECRET_WORKFLOW_AUTHORING_DB=$(jq -r .spec.workflow_authoring_configuration.database.secret_name ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_WORKFLOW_AUTHORING_DB -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_WORKFLOW_AUTHORING_DB.yaml
fi

# ADP database secret
if jq --exit-status -r .spec.ca_configuration.global.db_secret ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up Automation Document Processing database secret..."
  SECRET_ADP_DB=$(jq -r .spec.ca_configuration.global.db_secret ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_ADP_DB -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_ADP_DB.yaml
fi

# Database SSL secret in datasource_configuration section
grep database_ssl_secret_name: ${BACKUP_DIR}/CR.yaml | cut -d ':' -f2 |sort -u | while read each; do
  oc get secret $each -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$each.yaml
done

# Database SSL secret in BAW/BASTUDIO/APPENGINE sections
grep db_cert_secret_name: ${BACKUP_DIR}/CR.yaml | cut -d ':' -f2 |sort -u | while read each; do
  oc get secret $each -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$each.yaml
done

# application engine admin secret, no default value
CP4BA_AAE_INSTANCE_COUNT=$(jq -r .spec.application_engine_configuration ${BACKUP_DIR}/CRTMP.json | jq 'length')
for ((i=0; i<$CP4BA_AAE_INSTANCE_COUNT; i++)); do
  SECRET_APP_ENGINE_ADMIN=$(jq -r .spec.application_engine_configuration[$i].admin_secret_name ${BACKUP_DIR}/CRTMP.json)
  logInfo "Backing up Application Engine admin secret $i..."
  oc get secret $SECRET_APP_ENGINE_ADMIN -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_APP_ENGINE_ADMIN.yaml
done

# bastudio admin secret, no default value
if jq --exit-status -r .spec.bastudio_configuration.admin_secret_name ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up bastudio admin secret..."
  SECRET_BASTUDIO_ADMIN=$(jq -r .spec.bastudio_configuration.admin_secret_name ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_BASTUDIO_ADMIN -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_BASTUDIO_ADMIN.yaml
fi

# playback server admin secret, no default value
if jq --exit-status -r .spec.bastudio_configuration.playback_server.admin_secret_name ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up playback server admin secret..."
  SECRET_PLAYBACK_SERVER_ADMIN=$(jq -r .spec.bastudio_configuration.playback_server.admin_secret_name ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_PLAYBACK_SERVER_ADMIN -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_PLAYBACK_SERVER_ADMIN.yaml
fi

# ECM admin secret, no default value
if jq --exit-status -r .spec.ecm_configuration.fncm_secret_name ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up ECM admin secret..."
  SECRET_ECM_ADMIN=$(jq -r .spec.ecm_configuration.fncm_secret_name ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_ECM_ADMIN -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_ECM_ADMIN.yaml
fi

# Navigator admin secret, no default value
if jq --exit-status -r .spec.navigator_configuration.ban_secret_name ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up Navigator admin secret..."
  SECRET_NAVIGATOR_ADMIN=$(jq -r .spec.navigator_configuration.ban_secret_name ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_NAVIGATOR_ADMIN -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_NAVIGATOR_ADMIN.yaml
fi

# pfs admin secret
if jq --exit-status -r .spec.pfs_configuration.admin_secret_name ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up PFS admin secret..."
  SECRET_PFS_ADMIN=$(jq -r .spec.pfs_configuration.admin_secret_name ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_PFS_ADMIN -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_PFS_ADMIN.yaml
else
  # no PFS admin secret found in CR, check default value
  if oc get secret ibm-pfs-admin-secret > /dev/null 2>&1; then
    logInfo "Backing up PFS admin secret..."
    oc get secret ibm-pfs-admin-secret -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/ibm-pfs-admin-secret.yaml
  fi
fi

# RR admin secret
if jq --exit-status -r .spec.resource_registry_configuration.admin_secret_name ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up Resource Registry admin secret..."
  SECRET_RR_ADMIN=$(jq -r .spec.resource_registry_configuration.admin_secret_name ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_RR_ADMIN -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_RR_ADMIN.yaml
else
  if oc get secret resource-registry-admin-secret > /dev/null 2>&1; then
    logInfo "Backing up Resource Registry admin secret..."
    oc get secret resource-registry-admin-secret -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/resource-registry-admin-secret.yaml
  fi
fi

# Workflow Authoring admin secret, no default value
if jq --exit-status -r .spec.workflow_authoring_configuration.admin_secret_name ${BACKUP_DIR}/CRTMP.json > /dev/null 2>&1; then
  logInfo "Backing up Workflow Authoring admin secret..."
  SECRET_WORKFLOW_AUTHORING_ADMIN=$(jq -r .spec.workflow_authoring_configuration.admin_secret_name ${BACKUP_DIR}/CRTMP.json)
  oc get secret $SECRET_WORKFLOW_AUTHORING_ADMIN -o yaml | yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.namespace, .metadata.resourceVersion, .metadata.uid)'  > ${BACKUP_DIR}/secrets/$SECRET_WORKFLOW_AUTHORING_ADMIN.yaml
fi

##### Backup uid definition ####################################################
NAMESPACE_UID=$(oc describe project $cp4baProjectName | grep uid-range | cut -d"=" -f2 | cut -d"/" -f1)
logInfo "Namespace $cp4baProjectName uid: $NAMESPACE_UID"
echo $NAMESPACE_UID > ${BACKUP_DIR}/namespace_uid

##### Backup Persistent Volume Claims ##########################################
# Only backup dynamically created PVCs. Static PVCs are created by user.
# CPE PVC
if oc get deploy ${CP4BA_NAME}-cpe-deploy > /dev/null 2>&1; then
  logInfo "Found CPE deployment: ${CP4BA_NAME}-cpe-deploy"
  
  # cpe-cfgstore
  PVC_CPE_CFGSTORE=$(oc get deploy ${CP4BA_NAME}-cpe-deploy -o jsonpath='{.spec.template.spec.volumes}' | jq -r '.[] |select(.name == "cpe-cfg-stor") | .persistentVolumeClaim.claimName')
  logInfo "Backing up PVC: $PVC_CPE_CFGSTORE..."
  oc get pvc $PVC_CPE_CFGSTORE -o yaml | yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .spec.volumeMode, .spec.volumeName)' > ${BACKUP_DIR}/pvc/$PVC_CPE_CFGSTORE.yaml  

  # cpe-filestore
  PVC_CPE_FILESTORE=$(oc get deploy ${CP4BA_NAME}-cpe-deploy -o jsonpath='{.spec.template.spec.volumes}' | jq -r '.[] |select(.name == "file-stor") | .persistentVolumeClaim.claimName')
  logInfo "Backing up PVC: $PVC_CPE_FILESTORE..."
  oc get pvc $PVC_CPE_FILESTORE -o yaml | yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .spec.volumeMode, .spec.volumeName)' > ${BACKUP_DIR}/pvc/$PVC_CPE_FILESTORE.yaml  
fi

# CSS PVC
if oc get deploy ${CP4BA_NAME}-css-deploy-1 > /dev/null 2>&1; then
  logInfo "Found CSS deployment: ${CP4BA_NAME}-css-deploy-1"
  
  # css-indexstore
  PVC_CSS_INDEXSTORE=$(oc get deploy ${CP4BA_NAME}-css-deploy-1 -o jsonpath='{.spec.template.spec.volumes}' | jq -r '.[] |select(.name == "index-stor") | .persistentVolumeClaim.claimName')
  logInfo "Backing up PVC: $PVC_CSS_INDEXSTORE..."
  oc get pvc $PVC_CSS_INDEXSTORE -o yaml | yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .spec.volumeMode, .spec.volumeName)' > ${BACKUP_DIR}/pvc/$PVC_CSS_INDEXSTORE.yaml  
fi

# Navigator PVC
if oc get deploy ${CP4BA_NAME}-navigator-deploy > /dev/null 2>&1; then
  logInfo "Found Navigator deployment: ${CP4BA_NAME}-navigator-deploy"
  
  # icn-cfgstore
  PVC_NAVIGATOR_CFGSTORE=$(oc get deploy ${CP4BA_NAME}-navigator-deploy -o jsonpath='{.spec.template.spec.volumes}' | jq -r '.[] |select(.name == "icn-cfgstore") | .persistentVolumeClaim.claimName')
  logInfo "Backing up PVC: $PVC_NAVIGATOR_CFGSTORE..."
  oc get pvc $PVC_NAVIGATOR_CFGSTORE -o yaml | yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .spec.volumeMode, .spec.volumeName)' > ${BACKUP_DIR}/pvc/$PVC_NAVIGATOR_CFGSTORE.yaml  
fi

if [[ $CP4BA_VERSION =~ "21.0.3" ]]; then
  # Zen metastoredb PVC
  logInfo "Backing up PVC: datadir-zen-metastoredb-0..."
  oc get pvc datadir-zen-metastoredb-0 -o yaml | yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .spec.volumeMode, .spec.volumeName)' > ${BACKUP_DIR}/pvc/datadir-zen-metastoredb-0.yaml

  logInfo "Backing up PVC: datadir-zen-metastoredb-1..."
  oc get pvc datadir-zen-metastoredb-1 -o yaml | yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .spec.volumeMode, .spec.volumeName)' > ${BACKUP_DIR}/pvc/datadir-zen-metastoredb-1.yaml

  logInfo "Backing up PVC: datadir-zen-metastoredb-2..."
  oc get pvc datadir-zen-metastoredb-2 -o yaml | yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .spec.volumeMode, .spec.volumeName)' > ${BACKUP_DIR}/pvc/datadir-zen-metastoredb-2.yaml
fi

# JMS PVC
oc get pvc --no-headers |grep jms | while read each; do
  PVC_JMS=$(echo $each | awk '{ print $1 }')
  logInfo "Backing up PVC: $PVC_JMS..."
  oc get pvc $PVC_JMS -o yaml | yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .spec.volumeMode, .spec.volumeName)' > ${BACKUP_DIR}/pvc/$PVC_JMS.yaml
done


##### Backup data in PVCs ######################################################
#TODO backup entire NFS folder ?


##### Backup BTS PostgreSQL Database ###########################################
logInfo "Backing up BTS PostgreSQL Database..."
#BTS_PG_USER=$(oc exec ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts-1 -it -- bash -c "cat /etc/superuser-secret/username")
#BTS_PG_PASSWORD=$(oc exec ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts-1 -it -- bash -c "cat /etc/superuser-secret/password")
oc exec ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts-1 -it -- bash -c "pg_dump -d BTSDB -U postgres -Fp -c -C --if-exists  -f /var/lib/postgresql/data/backup_btsdb.sql"
oc cp ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts-1:/var/lib/postgresql/data/backup_btsdb.sql ${BACKUP_DIR}/postgresql/backup_btsdb.sql


##### Backup Databases #########################################################
#TODO DBA backup database

##### 
#TODO any customization files to be backed up ? e.g. font, config file

##### BAI ######################################################################
# Take ES snapshot
# scale down cp4a-operator
# oc scale deployment ibm-cp4a-operator --replicas=0

# iaf-insights-engine-management needs to be up and running
# oc wait --for=condition=Ready --timeout=-1s pod -l component=iaf-insights-engine-management
if [[ $CP4BA_VERSION =~ "21.0.3" ]]; then
  MANAGEMENT_POD=$(oc get pod --no-headers -l component=iaf-insights-engine-management |awk {'print $1'})
else
  MANAGEMENT_POD=$(oc get pod --no-headers -l component=${CP4BA_NAME}-insights-engine-management |awk {'print $1'})
fi
logInfo "MAnagement pod: $MANAGEMENT_POD"

# Get management service URL and credentails
logInfo "Getting insightsengine details..."
INSIGHTS_ENGINE=$(oc get insightsengine --no-headers | awk {'print $1'})
BPC_URL=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.cockpit.endpoints[?(@.scope=="External")].uri}')
logInfo "BPC URL: $BPC_URL"

MANAGEMENT_URL=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].uri}')
logInfo "Management URL: $MANAGEMENT_URL"

MANAGEMENT_AUTH_SECRET=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].authentication.secret.secretName}')
MANAGEMENT_USERNAME=$(oc get secret ${MANAGEMENT_AUTH_SECRET} -o jsonpath='{.data.username}' | base64 -d)
MANAGEMENT_PASSWORD=$(oc get secret ${MANAGEMENT_AUTH_SECRET} -o jsonpath='{.data.password}' | base64 -d)
FLINK_UI_URL=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.flinkUi.endpoints[?(@.scope=="External")].uri}')
logInfo "Flink UI: $FLINK_UI_URL"

# Retrieve the flink jobs
FLINK_AUTH_SECRET=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.flinkUi.endpoints[?(@.scope=="External")].authentication.secret.secretName}')
FLINK_USERNAME=$(oc get secret ${FLINK_AUTH_SECRET} -o jsonpath='{.data.username}' | base64 -d)
FLINK_PASSWORD=$(oc get secret ${FLINK_AUTH_SECRET} -o jsonpath='{.data.password}' | base64 -d)
logInfo "Retrieving flink jobs from $MANAGEMENT_URL/api/v1/processing/jobs/list..."

FLINK_JOBS=$(curl -sk -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} $MANAGEMENT_URL/api/v1/processing/jobs/list)
FLINK_JOBS_COUNT=$(echo $FLINK_JOBS |jq '.jobs' | jq 'length')

# Take savepoints and cancel the jobs
logInfo "Creating flink savepoints and canceling the jonbs..."
FLINK_SAVEPOINT_RESULTS=$(curl -X POST -sk -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} "${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints?cancel-job=true")
FLINK_SAVEPOINT_COUNT=$(echo $FLINK_SAVEPOINT_RESULTS | jq 'length')
for ((i=0; i<$FLINK_SAVEPOINT_COUNT; i++)); do
  FLINK_SAVEPOINT_NAME=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].name")
  FLINK_SAVEPOINT_JID=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].jid")
  FLINK_SAVEPOINT_STATE=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].state")
  FLINK_SAVEPOINT_LOCATION=$(echo $FLINK_SAVEPOINT_RESULTS | jq -r ".[$i].location")
  logInfo "  Flink savepoint: $FLINK_SAVEPOINT_NAME, JID: $FLINK_SAVEPOINT_JID, STATE: $FLINK_SAVEPOINT_STATE, Location: $FLINK_SAVEPOINT_LOCATION"
  logInfo "  Copying the savepoint to ${BACKUP_DIR}/flink/${FLINK_SAVEPOINT_LOCATION}..."
  oc cp ${MANAGEMENT_POD}:${FLINK_SAVEPOINT_LOCATION} ${BACKUP_DIR}/flink${FLINK_SAVEPOINT_LOCATION}
done

# Remove the Flink job submitters
logInfo "Removing flink job submitters..."
oc get jobs -o custom-columns=NAME:.metadata.name | grep bai- | grep -v bai-setup | xargs oc delete job

# Create ES/OS snapshots
if [[ $CP4BA_VERSION =~ "24.0" ]]; then
  # OpenSearch for 24.0 and later
  logInfo "Declaring the location of the snapshot repository for OpenSearch..."
  OPENSEARCH_ROUTE=$(oc get route opensearch-route -o jsonpath='{.spec.host}')
  OPENSEARCH_PASSWORD=$(oc get secret opensearch-ibm-elasticsearch-cred-secret --no-headers --ignore-not-found -o jsonpath={.data.elastic} | base64 -d)
  curl -skl -u elastic:$OPENSEARCH_PASSWORD -XPUT "https://$OPENSEARCH_ROUTE/_snapshot/${DATETIMESTR}" -H "Content-Type: application/json" -d'{"type":"fs","settings":{"location": "/workdir/snapshot_storage","compress": true}}'
  logInfo "Creating snapshot backup_${DATETIMESTR}..."
  SNAPSHOT_RESULT=$(curl -skL -u elastic:${OPENSEARCH_PASSWORD} -XPUT "https://${OPENSEARCH_ROUTE}/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?wait_for_completion=true&pretty=true")
  SNAPSHOT_STATE=$(echo $SNAPSHOT_RESULT | jq -r ".snapshot.state")
  checkResult $SNAPSHOT_STATE "SUCCESS" "Snapshot state"
else
  # ElasticSearch
  logInfo "Declaring the location of the snapshot repository for ElasticSearch..."
  ELASTICSEARCH_ROUTE=$(oc get route iaf-system-es -o jsonpath='{.spec.host}')
  ELASTICSEARCH_PASSWORD=$(oc get secret iaf-system-elasticsearch-es-default-user --no-headers --ignore-not-found -o jsonpath={.data.password} | base64 -d)
  curl -skl -u elasticsearch-admin:$ELASTICSEARCH_PASSWORD -XPUT "https://$ELASTICSEARCH_ROUTE/_snapshot/${DATETIMESTR}" -H "Content-Type: application/json" -d'{"type":"fs","settings":{"location": "/usr/share/elasticsearch/snapshots/main","compress": true}}'
  logInfo "Creating snapshot backup_${DATETIMESTR}..."
  SNAPSHOT_RESULT=$(curl -skL -u elasticsearch-admin:${ELASTICSEARCH_PASSWORD} -XPUT "https://${ELASTICSEARCH_ROUTE}/_snapshot/${DATETIMESTR}/backup_${DATETIMESTR}?wait_for_completion=true&pretty=true")
  SNAPSHOT_STATE=$(echo $SNAPSHOT_RESULT | jq -r ".snapshot.state")
  checkResult $SNAPSHOT_STATE "SUCCESS" "Snapshot state"
fi

#TODO copy the snapshots from the pod, what should be copied ? Need clarification from document


