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

# This script is for preparing the Restore (BAR) process, creating the cp4ba namespace,
# restoring the persistent volumes and persistent volume claims, and creating the secrets.
#    Only tested with CP4BA version: 21.0.3 IF034, dedicated common services set-up

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import common utilities
source ${CUR_DIR}/common.sh

LOG_FILE="/dev/null"

INPUT_PROPS_FILENAME="001-barParameters.sh"
INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${INPUT_PROPS_FILENAME}"

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${INPUT_PROPS_FILENAME}. Reading in variables from that script."
   
   . $INPUT_PROPS_FILENAME_FULL
   
   if [ "$cp4baProjectName" == "REQUIRED" ] || [ "$barTokenUser" == "REQUIRED" ] || [ "$barTokenPass" == "REQUIRED" ] || [ "$barTokenResolveCp4ba" == "REQUIRED" ] || [ "$barCp4baHost" == "REQUIRED" ]; then
      echo "File ${INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 1
   fi

   echo "Done!"
else
   echo
   echo "File ${INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 1
fi

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

logInfo "preDeploy will use project/namespace ${cp4baProjectName}"

BACKUP_ROOT_DIRECTORY_FULL="${CUR_DIR}/${cp4baProjectName}"
if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo 
else
   logError "Backup Directory ${cp4baProjectName} does not exist"
   exit 1
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/preDeploy_$(date +'%Y%m%d_%H%M%S').log"
logInfo "Details will be logged to $LOG_FILE."
echo

# $1 PVC name to check
# $2 CR NAME
function restore_this_pvc() {
  local pvcname=$1
  local crname=$2
  local sedexpr=$(printf 's/%s/CRNAME/g' $crname)
  local pvcname=$(echo ${pvcname} | sed $sedexpr)

  if [[ $pvcname == cpe-filestore  ]]; then return 0; fi
  if [[ $pvcname == css-indexstore  ]]; then return 0; fi
  if [[ $pvcname == icn-cfgstore  ]]; then return 0; fi

  pattern="CRNAME-workflow-authoring-baw-jms-data-vc-CRNAME-workflow-authoring-baw-jms-0"
  if [[ $pvcname =~ $pattern   ]]; then return 0; fi
  if [[ $pvcname == operator-shared-pvc ]]; then return 0; fi

  # To be restored per the documentation on https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=recovery-backing-up-your-environments

  pattern="datadir-zen-metastoredb-.*"
  if [[ $pvcname =~ $pattern  ]]; then return 0; fi

  # Optional but nice to have, have amended to the list
  if [[ $pvcname == cpe-cfgstore  ]]; then return 0; fi
  if [[ $pvcname == cpe-bootstrapstore ]]; then return 0; fi 
  if [[ $pvcname == icn-pluginstore  ]]; then return 0; fi

  # According to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=environments-persistent-volume-claims-be-backed-up#ref_hadr_pvcs__ads
  # if [[ $pvcname == CRNAME-ads-runtime-storage-pvc  ]]; then return 0; fi

  # Commented out for now: Postgres will not come up from the PVCs alone. 
  ## This might sound crazy, but if the pattern is not stored in a variable, the regexp comparison will just not match
  #pattern="ibm-bts-cnpg-.*-cp4ba-bts-.*"
  #if [[ $pvcname =~ $pattern   ]]; then return 0; fi

  # According to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=environments-persistent-volume-claims-be-backed-up#ref_hadr_pvcs__baw__title__1
  pattern="CRNAME-.*-baw-file-storage-pvc"
  if [[ $pvcname =~ $pattern   ]]; then return 0; fi
  pattern="CRNAME-.*-baw-jms-data-vc-CRNAME-.*-baw-jms-0"
  if [[ $pvcname =~ $pattern   ]]; then return 0; fi
  if [[ $pvcname == CRNAME-bastudio-files-pvc ]]; then return 0; fi
  pattern="jms-pvc-CRNAME-bastudio-deployment-.*"
  if [[ $pvcname =~ $pattern  ]]; then return 0; fi
  if [[ $pvcname == CRNAME-dba-rr-pvc ]]; then return 0; fi
  if [[ $pvcname == cp4a-shared-log-pvc ]]; then return 0; fi
  
  # Added by Thomas 4 ES & BAI
  pattern="data-iaf-system-elasticsearch-es-data-.*"
  if [[ $pvcname =~ $pattern  ]]; then return 0; fi
  if [[ $pvcname == iaf-system-elasticsearch-es-snap-main-pvc ]]; then return 0; fi
  if [[ $pvcname == CRNAME-bai-pvc ]]; then return 0; fi
  pattern="data-iaf-system-kafka-.*"
  if [[ $pvcname =~ $pattern  ]]; then return 0; fi
  pattern="data-iaf-system-zookeeper-.*"
  if [[ $pvcname =~ $pattern  ]]; then return 0; fi
  
  # Added by Thomas as best guess
  pattern=".*-pbkae-file-pvc"
  if [[ $pvcname =~ $pattern  ]]; then return 0; fi
  pattern=".*-aaeae-file-pvc"
  if [[ $pvcname =~ $pattern  ]]; then return 0; fi
  
  return 1
}

# $1 Secret name to check
# $2 CR NAME
function restore_this_secret() {
  local secretname=$1
  local crname=$2
  local sedexpr=$(printf 's/%s/CRNAME/g' $crname)
  local secretname=$(echo ${secretname} | sed $sedexpr)

  # To be restored per the documentation on https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=recovery-backing-up-your-environments
  if [[ $secretname == CRNAME-cpe-oidc-secret  ]]; then return 0; fi
  if [[ $secretname == ldap-bind-secret  ]]; then return 0; fi
  if [[ $secretname == icp4a-shared-encryption-key  ]]; then return 0; fi 
  if [[ $secretname == ibm-iaws-shared-key-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-baw-wfs-server-db-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-pfs-admin-secret  ]]; then return 0; fi
  # if [[ $secretname == icp4adeploy-workspace-aae-app-engine-admin-secret  ]]; then return 0; fi   # icp4adeploy is a custom name, secret referenced by CR, so we shoould get it by the last if in this function
  if [[ $secretname == CRNAME-workspace-aae-app-engine-admin-secret  ]]; then return 0; fi
  if [[ $secretname == iaf-system-elasticsearch-es-default-user  ]]; then return 0; fi
  if [[ $secretname == CRNAME-elasticsearch-admin-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-ban-secret  ]]; then return 0; fi
  if [[ $secretname == ibm-fncm-secret  ]]; then return 0; fi
  if [[ $secretname == CRNAME-global-function-id-secret  ]]; then return 0; fi
  if [[ $secretname == CRNAME-ae-function-id-secret ]]; then return 0; fi
  pattern="ibm-.*-admin-secret"
  if [[ $secretname =~ $pattern   ]]; then return 0; fi
  pattern="ibm-.*-server-db-secret"
  if [[ $secretname =~ $pattern   ]]; then return 0; fi
  if [[ $secretname == CRNAME-workflow-authoring-baw-server-encrypt-secret ]]; then return 0; fi
  if [[ $secretname == CRNAME-workflow-authoring-baw-jms-encrypt-secret ]]; then return 0; fi
  if [[ $secretname == CRNAME-pfs-encrypt-secret ]]; then return 0; fi
  # if [[ $secretname == icp4adeploy-bas-admin-secret  ]]; then return 0; fi   # icp4adeploy is a custom name, secret referenced by CR, so we shoould get it by the last if in this function
  if [[ $secretname == CRNAME-bas-admin-secret  ]]; then return 0; fi
  if [[ $secretname == platform-oidc-credentials  ]]; then return 0; fi
  if [[ $secretname == oauth-client-secret  ]]; then return 0; fi
  pattern="ibm-bts-cnpg-.*-cp4ba-bts-app"
  if [[ $secretname =~ $pattern   ]]; then return 0; fi
  if [[ $secretname == admin-user-details  ]]; then return 0; fi
  if [[ $secretname == ibm-entitlement-key  ]]; then return 0; fi
  # if [[ $secretname == icp4adeploy-rr-admin-secret  ]]; then return 0; fi   # icp4adeploy is a custom name, secret referenced by CR, so we shoould get it by the last if in this function
  if [[ $secretname == CRNAME-rr-admin-secret    ]]; then return 0; fi

  if [[ $secretname == playback-server-admin-secret  ]]; then return 0; fi
  if [[ $secretname == CRNAME-wfps-admin-secret  ]]; then return 0; fi
  
  # Secrets added by Thomas
  if [[ $secretname == cs-ca-certificate-secret ]]; then return 0; fi
  if [[ $secretname == iaf-system-automationui-aui-zen-cert ]]; then return 0; fi
  if [[ $secretname == iaf-system-elasticsearch-es-client-cert-kp ]]; then return 0; fi
  if [[ $secretname == icp-serviceid-apikey-secret ]]; then return 0; fi
  if [[ $secretname == platform-auth-idp-credentials ]]; then return 0; fi
  if [[ $secretname == platform-auth-ldaps-ca-cert ]]; then return 0; fi
  if [[ $secretname == platform-auth-scim-credentials ]]; then return 0; fi
  if [[ $secretname == zen-serviceid-apikey-secret ]]; then return 0; fi
  if [[ $secretname == auth-pdp-secret ]]; then return 0; fi
  if [[ $secretname == common-web-ui-cert ]]; then return 0; fi
  if [[ $secretname == foundation-iaf-automationbase-ab-ss-ca ]]; then return 0; fi
  if [[ $secretname == iaf-system-automationui-aui-zen-ca ]]; then return 0; fi
  if [[ $secretname == iaf-system-elasticsearch-es-ss-cacert-kp ]]; then return 0; fi
  if [[ $secretname == iam-pap-secret ]]; then return 0; fi
  if [[ $secretname == ibm-bts-ca-secret ]]; then return 0; fi
  if [[ $secretname == ibm-bts-tls-secret ]]; then return 0; fi
  if [[ $secretname == icp-mongodb-client-cert ]]; then return 0; fi
  if [[ $secretname == identity-provider-secret ]]; then return 0; fi
  if [[ $secretname == icp-management-ingress-tls-secret ]]; then return 0; fi
  if [[ $secretname == mongodb-root-ca-cert ]]; then return 0; fi
  if [[ $secretname == platform-api-secret ]]; then return 0; fi
  if [[ $secretname == platform-auth-secret ]]; then return 0; fi
  if [[ $secretname == platform-identity-management ]]; then return 0; fi
  if [[ $secretname == route-tls-secret ]]; then return 0; fi
  if [[ $secretname == admin.registrykey ]]; then return 0; fi
  
  # added for authoring env with bai
  if [[ $secretname == iaf-insights-engine-management-cert ]]; then return 0; fi
  if [[ $secretname == iaf-insights-engine-cockpit-cert ]]; then return 0; fi
  if [[ $secretname == foundation-iaf-apicurio-ap-apicurio-cert ]]; then return 0; fi
  pattern="iaf-insights-engine-.*-ss-cacert-kp"
  if [[ $secretname =~ $pattern   ]]; then return 0; fi
  pattern="iaf-insights-engine-.*-client-cert-kp"
  if [[ $secretname =~ $pattern   ]]; then return 0; fi
  pattern="iaf-insights-engine-.*-internal-cert-kp"
  if [[ $secretname =~ $pattern   ]]; then return 0; fi
  pattern="iaf-insights-engine-.*-admin-user"
  if [[ $secretname =~ $pattern   ]]; then return 0; fi
  
  # secrets for ES
  if [[ $secretname == icp4ba-es-auth ]]; then return 0; fi
  
  # secrets for kafka
  pattern="icp4ba-kafka-auth-.*"
  if [[ $secretname =~ $pattern   ]]; then return 0; fi
  
  # If the name appears in the CR, then it is also part of what is needed.
  # This should get any LDAP or DB TLS secrets as well, or renamed secrets 
  if grep $secretname $CR_SPEC > /dev/null 2>/dev/null; then return 0; fi


  # ldap-ssl-secret will, if used, appear in the CR. There is no default name for it. Below all secrets appearing the CR will be included for the restore
  # Same counts for the db2 certificates.



  # To be restored following https://community.ibm.com/community/user/automation/blogs/dian-guo-zou/2022/10/12/backup-and-restore-baw-2103


  return 1
}

function restore_secret() {
  local secretName=$1
  local secretFile=$2
  local backupNamespace=$3
  
  secret=$(oc get secret $secretName --ignore-not-found)
  if [[ "$secret" == "" ]]; then
    logInfoValue "Defining Secret " ${secretName}
    logInfo $(yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .metadata.generation)' $secretFile | oc apply -f - -n $backupNamespace)
  fi
}

# $1 ConfigMap name to check
# $2 CR NAME
function restore_this_configmap() {
  local configmapname=$1
  local crname=$2
  local sedexpr=$(printf 's/%s/CRNAME/g' $crname)
  local configmapname=$(echo ${configmapname} | sed $sedexpr)

  if [[ $configmapname == registration-json  ]]; then return 0; fi

  # ConfigMaps added by Thomas
  if [[ $configmapname == platform-auth-idp ]]; then return 0; fi
  
  # If the name appears in the CR, then it is also part of what is needed.
  if grep $configmapname $CR_SPEC > /dev/null 2>/dev/null; then return 0; fi

  return 1
}

# Added by Thomas
# $1 Cert-ManagerIO Certificate name to check
# $2 CR NAME
function restore_this_certmanageriocertificate() {
  local certmanageriocertificatename=$1
  local crname=$2
  local sedexpr=$(printf 's/%s/CRNAME/g' $crname)
  local certmanageriocertificatename=$(echo ${certmanageriocertificatename} | sed $sedexpr)
  
  return 0;
  
  ## For now, we'll restore all
  # if [[ $certmanageriocertificatename == cs-ca-certificate-secret ]]; then return 0; fi

  # If the name appears in the CR, then it is also part of what is needed.
  # if grep $certmanageriocertificatename $CR_SPEC > /dev/null 2>/dev/null; then return 0; fi

  # return 1
}

# Added by Thomas
# $1 CertManagerK8S Certificate name to check
# $2 CR NAME
function restore_this_certmanagerk8scertificate() {
  local certmanagerk8scertificatename=$1
  local crname=$2
  local sedexpr=$(printf 's/%s/CRNAME/g' $crname)
  local certmanagerk8scertificatename=$(echo ${certmanagerk8scertificatename} | sed $sedexpr)
  
  return 0;
  
  ## For now, we'll restore all
  # if [[ $certmanagerk8scertificatename == <name> ]]; then return 0; fi

  # If the name appears in the CR, then it is also part of what is needed.
  # if grep $certmanagerk8scertificatename $CR_SPEC > /dev/null 2>/dev/null; then return 0; fi

  # return 1
}

# Added by Thomas
# $1 Issuer name to check
# $2 CR NAME
function restore_this_issuer() {
  local issuername=$1
  local crname=$2
  local sedexpr=$(printf 's/%s/CRNAME/g' $crname)
  local issuername=$(echo ${issuername} | sed $sedexpr)
  
  return 0;
  
  ## For now, we'll restore all
  # if [[ $issuername == <name> ]]; then return 0; fi

  # If the name appears in the CR, then it is also part of what is needed.
  # if grep $issuername $CR_SPEC > /dev/null 2>/dev/null; then return 0; fi

  # return 1
}

# Check if directory is empty
if [ "$(ls -A $BACKUP_ROOT_DIRECTORY_FULL)" ]; then
  # If directory is not empty, list subdirectories
  echo "Available backups:"
  count=0
  echo
  for dir in $BACKUP_ROOT_DIRECTORY_FULL/backup_*; do
    if [ -d "$dir" ]; then
      count=$(expr $count + 1)
      echo "$count:    $(basename $dir)"
    fi
  done

  # Prompt user to select a subdirectory
  read -p "Enter the number of the subdirectory to choose: " choice
  echo
  if [ -z "$choice" ]; then
    logError "No choice made, exiting."
    exit 1
  fi

  # Check if choice is a number
  if ! [[ $choice =~ ^[0-9]+$ ]]; then
    logError "Choice must be a number, exiting."
    exit 1
  fi

  # Check if choice is within range
  if [ $choice -lt 1 ] || [ $choice -gt $count ]; then
    logError "Choice is out of range, exiting"
    exit 1
  fi

  # Get the selected subdirectory
  count=0
  for dir in $BACKUP_ROOT_DIRECTORY_FULL/backup_*; do
    if [ -d "$dir" ]; then
      count=$(expr $count + 1)
      if [ "$count" == "$choice" ]; then
        BACKUP_DIR="$BACKUP_ROOT_DIRECTORY_FULL/$(basename $dir)"
      fi
    fi
  done
else
  logError "No Backups found for project ${cp4baProjectName}"
  echo
  exit 1
fi

logInfo "preDeploy will use backup directory $BACKUP_DIR"

if [[ -d $BACKUP_DIR/icp4acluster.icp4a.ibm.com ]]; then
  if [[ $(ls -A $BACKUP_DIR/icp4acluster.icp4a.ibm.com | wc -l) -eq 1 ]]; then
    CR_SPEC=$BACKUP_DIR/icp4acluster.icp4a.ibm.com/$(ls -A $BACKUP_DIR/icp4acluster.icp4a.ibm.com)
  fi
fi

# Note that below check will not succeed, if more than one CR was found. This is intended.
if [[ ! -e $CR_SPEC ]]; then
  logError "Could not find the CR in the backup directory $BACKUP_DIR"
  echo
  exit 1
fi

backupNamespace=$(yq eval '.metadata.namespace' $CR_SPEC)
backupDeploymentName=$(yq eval '.metadata.name' $CR_SPEC)
backupAppVersion=$(yq eval '.spec.appVersion' $CR_SPEC)

logInfoValue "Backup was made on project: " $backupNamespace
if [[ "$backupNamespace" != "$cp4baProjectName" ]]; then
  logError "Backup project name $backupNamespace differs from restore project name ${cp4baProjectName}, data inconsistent, exiting."
  echo
  exit 1
fi

logInfoValue "The CR from the backup used deployment name: " $backupDeploymentName
logInfoValue "The CR specification is for CP4BA Version: " $backupAppVersion

logInfo "Verifying OC CLI is connected to the OCP cluster..."
WHOAMI=$(oc whoami)
logInfo "WHOAMI =" $WHOAMI

if [[ "$WHOAMI" == "" ]]; then
  logError "OC CLI is NOT connected to the OCP cluster. Please log in first with an admin user to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
  echo
  exit 1
fi
echo

if oc get project $backupNamespace  > /dev/null 2>&1; then
  logWarning "Backup Namespace is already existing"
  logInfoValue "Running command " oc project $backupNamespace
  oc project $backupNamespace > $LOG_FILE
else
  if [[ "$(oc auth can-i create project 2>/dev/null)" == "yes" ]]; then
    logInfo "Project $backupNamespace is not yet existing, but needs to be created."
    echo
    read -p "Press Return to continue, CTRL-C to abort" choice
    echo
    logInfoValue "Running command " oc new-project $backupNamespace
    oc new-project $backupNamespace >> $LOG_FILE
  else
    logError "Project $backupNamespace is not yet existing, but logged on user $(oc whoami) has not enough rights to create it. Exiting..."
  echo
    exit 1
  fi
fi
echo

################ Restore Secrets ################
if [ -d $BACKUP_DIR/secret ]; then
  logInfo "Processing Secrets ($(ls -A $BACKUP_DIR/secret | wc -l))"
else
  logInfo "Processing Secrets (none)"
fi

yamlFiles=()
countYamlFiles=0
existingSecrets=$(oc get secret -o custom-columns=name:.metadata.name --no-headers)

function is_existing_secret() {
  local existing_secret=""
  local secret=$1
  for existing_secret in $existingSecrets; do 
    if [ "$existing_secret" == "$secret" ]; then
      return 0
    fi
  done
  return 1
}

for yaml in $BACKUP_DIR/secret/*.yaml; do
  secretName=$(yq eval '.metadata.name' $yaml)
  secretNamespace=$(yq eval '.metadata.namespace' $yaml)
  if [[ "$secretName" != "null" ]]; then
    if [[ "$secretNamespace" != "null" && "$secretNamespace" != "$backupNamespace" ]]; then
      logWarning "Skipping Secret $secretName in file $(basename $yaml) it has a non-matching namespace: $secretNamespace"
    else 
      if restore_this_secret $secretName $backupDeploymentName; then
        if is_existing_secret $secretName; then
          logInfoValue "Secret already defined: " $secretName
        else        
          yamlFiles+=($yaml)
          countYamlFiles=$(expr $countYamlFiles + 1)
        fi
      fi
    fi
  fi
done

if [[ "$countYamlFiles" == "0" ]]; then
	logInfo "All secrets have already been applied"
else
  echo
  echo "The script will try to apply following secrets:"

  for file in "${yamlFiles[@]}"; do
    secretName=$(yq eval '.metadata.name' $file)
    echo -e "\tSecret \x1B[1m$secretName\x1B[0m  (File: $(basename $file))"
  done

  echo
  printf "OK to apply these secret definitions? (Yes/No, default Yes): "
  read -rp "" ans
  case "$ans" in
  "n"|"N"|"no"|"No"|"NO")
     echo
     echo -e "Exiting..."
     echo
     exit 0
     ;;
  *)
     echo
     echo -e "OK..."
     ;;
  esac
  
  for file in "${yamlFiles[@]}"; do
    secretName=$(yq eval '.metadata.name' $file)
    restore_secret $secretName $file $backupNamespace
#    logInfoValue "Defining Secret " ${secretName}
#    yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .metadata.generation)' $file | oc apply -f - -n $backupNamespace

  done
fi
echo

################ Restore ConfigMaps ################
if [ -d $BACKUP_DIR/configmap ]; then
  logInfo "Processing Configmaps ($(ls -A $BACKUP_DIR/configmap | wc -l))"
else
  logInfo "Processing Configmaps (none)"
fi

yamlFiles=()
countYamlFiles=0
existingConfigmaps=$(oc get configmap -o custom-columns=name:.metadata.name --no-headers)

function is_existing_configmap() {
  local existing_configmap=""
  local configmap=$1
  for existing_configmap in $existingConfigmaps; do 
    if [ "$existing_configmap" == "$configmap" ]; then
      return 0
    fi
  done
  return 1
}

for yaml in $BACKUP_DIR/configmap/*.yaml; do
  configmapName=$(yq eval '.metadata.name' $yaml)
  configmapNamespace=$(yq eval '.metadata.namespace' $yaml)
  if [[ "$configmapName" != "null" ]]; then
    if [[ "$configmapNamespace" != "null" && "$configmapNamespace" != "$backupNamespace" ]]; then
      logWarning "Skipping Configmap $configmapName in file $(basename $yaml) it has a non-matching namespace: $configmapNamespace"
    else 
      if restore_this_configmap $configmapName $backupDeploymentName; then
        if is_existing_configmap $configmapName; then
          logInfoValue "Configmap already defined: " $configmapName
        else        
          yamlFiles+=($yaml)
          countYamlFiles=$(expr $countYamlFiles + 1)
        fi
      fi
    fi
  fi
done

echo

if [[ "$countYamlFiles" == "0" ]]; then
	logInfo "All Configmaps have already been applied"
else
  echo
  echo "The script will try to apply following Configmaps:"

  for file in "${yamlFiles[@]}"; do
    configmapName=$(yq eval '.metadata.name' $file)
    echo -e "\tConfigmap \x1B[1m$configmapName\x1B[0m  (File: $(basename $file))"
  done

  echo
  printf "OK to apply these Configmap definitions? (Yes/No, default Yes): "
  read -rp "" ans
  case "$ans" in
  "n"|"N"|"no"|"No"|"NO")
     echo
     echo -e "Exiting..."
     echo
     exit 0
     ;;
  *)
     echo
     echo -e "OK..."
     ;;
  esac

  for file in "${yamlFiles[@]}"; do
    configmapName=$(yq eval '.metadata.name' $file)
    logInfoValue "Defining Configmap " ${configmapName}
    yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences)' $file | oc apply -f - -n $backupNamespace
  done
fi
echo



################ Restore Cert-ManagerIO Certificates ################
if [ -d $BACKUP_DIR/certificate.cert-manager.io ]; then
  logInfo "Processing Cert-ManagerIO Certificates ($(ls -A $BACKUP_DIR/certificate.cert-manager.io | wc -l))"
else
  logInfo "Processing Cert-ManagerIO Certificates (none)"
fi

yamlFiles=()
countYamlFiles=0
existingcertmanageriocertificates=$(oc get certificate.cert-manager.io -o custom-columns=name:.metadata.name --no-headers)

function is_existing_certmanageriocertificate() {
  local existing_certmanageriocertificate=""
  local certmanageriocertificate=$1
  for existing_certmanageriocertificate in $existingcertmanageriocertificates; do 
    if [ "$existing_certmanageriocertificate" == "$certmanageriocertificate" ]; then
      return 0
    fi
  done
  return 1
}

for yaml in $BACKUP_DIR/certificate.cert-manager.io/*.yaml; do
  certmanageriocertificateName=$(yq eval '.metadata.name' $yaml)
  certmanageriocertificateNamespace=$(yq eval '.metadata.namespace' $yaml)
  if [[ "$certmanageriocertificateName" != "null" ]]; then
    if [[ "$certmanageriocertificateNamespace" != "null" && "$certmanageriocertificateNamespace" != "$backupNamespace" ]]; then
      logWarning "Skipping Cert-ManagerIO Certificate $certmanageriocertificateName in file $(basename $yaml) it has a non-matching namespace: $certmanageriocertificateNamespace"
    else 
      if restore_this_certmanageriocertificate $certmanageriocertificateName $backupDeploymentName; then
        if is_existing_certmanageriocertificate $certmanageriocertificateName; then
          logInfoValue "Cert-ManagerIO Certificate already defined: " $certmanageriocertificateName
        else        
          yamlFiles+=($yaml)
          countYamlFiles=$(expr $countYamlFiles + 1)
        fi
      fi
    fi
  fi
done

echo

if [[ "$countYamlFiles" == "0" ]]; then
	logInfo "All Cert-ManagerIO Certificates have already been applied"
else
  echo
  echo "The script will try to apply following Cert-ManagerIO Certificates:"
  
  for file in "${yamlFiles[@]}"; do
    certmanageriocertificateName=$(yq eval '.metadata.name' $file)
    echo -e "\tCert-ManagerIO Certificate \x1B[1m$certmanageriocertificateName\x1B[0m  (File: $(basename $file))"
  done

  echo
  printf "OK to apply these Cert-ManagerIO Certificate definitions? (Yes/No, default Yes): "
  read -rp "" ans
  case "$ans" in
  "n"|"N"|"no"|"No"|"NO")
     echo
     echo -e "Exiting..."
     echo
     exit 0
     ;;
  *)
     echo
     echo -e "OK..."
     ;;
  esac

  for file in "${yamlFiles[@]}"; do
    certmanageriocertificateName=$(yq eval '.metadata.name' $file)
    logInfoValue "Defining Cert-ManagerIO Certificate " ${certmanageriocertificateName}
    yq eval 'del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences)' $file | oc apply -f - -n $backupNamespace
  done
fi
echo



################ Restore CertManagerK8S Certificates ################
if [ -d $BACKUP_DIR/certificate.certmanager.k8s.io ]; then
  logInfo "Processing CertManagerK8S Certificates ($(ls -A $BACKUP_DIR/certificate.certmanager.k8s.io | wc -l))"
else
  logInfo "Processing CertManagerK8S Certificates (none)"
fi

yamlFiles=()
countYamlFiles=0
existingcertmanagerk8scertificates=$(oc get certificate.certmanager.k8s.io -o custom-columns=name:.metadata.name --no-headers)

function is_existing_certmanagerk8scertificate() {
  local existing_certmanagerk8scertificate=""
  local certmanagerk8scertificate=$1
  for existing_certmanagerk8scertificate in $existingcertmanagerk8scertificates; do 
    if [ "$existing_certmanagerk8scertificate" == "$certmanagerk8scertificate" ]; then
      return 0
    fi
  done
  return 1
}

for yaml in $BACKUP_DIR/certificate.certmanager.k8s.io/*.yaml; do
  certmanagerk8scertificateName=$(yq eval '.metadata.name' $yaml)
  certmanagerk8scertificateNamespace=$(yq eval '.metadata.namespace' $yaml)
  if [[ "$certmanagerk8scertificateName" != "null" ]]; then
    if [[ "$certmanagerk8scertificateNamespace" != "null" && "$certmanagerk8scertificateNamespace" != "$backupNamespace" ]]; then
      logWarning "Skipping CertManagerK8S Certificate $certmanagerk8scertificateName in file $(basename $yaml) it has a non-matching namespace: $certmanagerk8scertificateNamespace"
    else 
      if restore_this_certmanagerk8scertificate $certmanagerk8scertificateName $backupDeploymentName; then
        if is_existing_certmanagerk8scertificate $certmanagerk8scertificateName; then
          logInfoValue "CertManagerK8S Certificate already defined: " $certmanagerk8scertificateName
        else        
          yamlFiles+=($yaml)
          countYamlFiles=$(expr $countYamlFiles + 1)
        fi
      fi
    fi
  fi
done

echo

if [[ "$countYamlFiles" == "0" ]]; then
	logInfo "All CertManagerK8S Certificates have already been applied"
else
  echo
  echo "The script will try to apply following CertManagerK8S Certificates:"
  
  for file in "${yamlFiles[@]}"; do
    certmanagerk8scertificateName=$(yq eval '.metadata.name' $file)
    echo -e "\tCertManagerK8S Certificate \x1B[1m$certmanagerk8scertificateName\x1B[0m  (File: $(basename $file))"
  done

  echo
  printf "OK to apply these CertManagerK8S Certificate definitions? (Yes/No, default Yes): "
  read -rp "" ans
  case "$ans" in
  "n"|"N"|"no"|"No"|"NO")
     echo
     echo -e "Exiting..."
     echo
     exit 0
     ;;
  *)
     echo
     echo -e "OK..."
     ;;
  esac

  for file in "${yamlFiles[@]}"; do
    certmanagerk8scertificateName=$(yq eval '.metadata.name' $file)
    logInfoValue "Defining CertManagerK8S Certificate " ${certmanagerk8scertificateName}
    yq eval 'del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences)' $file | oc apply -f - -n $backupNamespace
  done
fi
echo



################ Restore Issuers ################
if [ -d $BACKUP_DIR/issuer.cert-manager.io ]; then
  logInfo "Processing Issuers ($(ls -A $BACKUP_DIR/issuer.cert-manager.io | wc -l))"
else
  logInfo "Processing Issuers (none)"
fi

yamlFiles=()
countYamlFiles=0
existingissuers=$(oc get issuer.cert-manager.io -o custom-columns=name:.metadata.name --no-headers)

function is_existing_issuer() {
  local existing_issuer=""
  local issuer=$1
  for existing_issuer in $existingissuers; do 
    if [ "$existing_issuer" == "$issuer" ]; then
      return 0
    fi
  done
  return 1
}

for yaml in $BACKUP_DIR/issuer.cert-manager.io/*.yaml; do
  issuerName=$(yq eval '.metadata.name' $yaml)
  issuerNamespace=$(yq eval '.metadata.namespace' $yaml)
  if [[ "$issuerName" != "null" ]]; then
    if [[ "$issuerNamespace" != "null" && "$issuerNamespace" != "$backupNamespace" ]]; then
      logWarning "Skipping Issuer $issuerName in file $(basename $yaml) it has a non-matching namespace: $issuerNamespace"
    else 
      if restore_this_issuer $issuerName $backupDeploymentName; then
        if is_existing_issuer $issuerName; then
          logInfoValue "Issuer already defined: " $issuerName
        else        
          yamlFiles+=($yaml)
          countYamlFiles=$(expr $countYamlFiles + 1)
        fi
      fi
    fi
  fi
done

echo

if [[ "$countYamlFiles" == "0" ]]; then
	logInfo "All Issuers have already been applied"
else
  echo
  echo "The script will try to apply following Issuers:"
  
  for file in "${yamlFiles[@]}"; do
    issuerName=$(yq eval '.metadata.name' $file)
    echo -e "\tIssuer \x1B[1m$issuerName\x1B[0m  (File: $(basename $file))"
  done

  echo
  printf "OK to apply these Issuer definitions? (Yes/No, default Yes): "
  read -rp "" ans
  case "$ans" in
  "n"|"N"|"no"|"No"|"NO")
     echo
     echo -e "Exiting..."
     echo
     exit 0
     ;;
  *)
     echo
     echo -e "OK..."
     ;;
  esac

  for file in "${yamlFiles[@]}"; do
    issuerName=$(yq eval '.metadata.name' $file)
    logInfoValue "Defining Issuer " ${issuerName}
    yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences)' $file | oc apply -f - -n $backupNamespace
  done
fi
echo



################ Restore PVCs ################
if [ -d $BACKUP_DIR/persistentvolumeclaim ]; then
  logInfo "Processing Persistent Volume Claims ($(ls -A $BACKUP_DIR/persistentvolumeclaim | wc -l))"
else
  logInfo "Processing Persistent Volume Claims (none)"
fi

yamlFiles=()
countYamlFiles=0
existingPVCs=$(oc get pvc -o custom-columns=name:.metadata.name --no-headers)

function is_existing_pvc() {
  local existing_pvc=""
  local pvc=$1
  for existing_pvc in $existingPVCs; do 
    if [ "$existing_pvc" == "$pvc" ]; then
      return 0
    fi
  done
  return 1
}

for yaml in $BACKUP_DIR/persistentvolumeclaim/*.yaml; do
  pvcName=$(yq eval '.metadata.name' $yaml)
  pvcNamespace=$(yq eval '.metadata.namespace' $yaml)
  pvcStorageClass=$(yq eval '.spec.storageClassName' $yaml)

  if [[ "$pvcName" != "null" ]]; then
    if [[ "$pvcNamespace" != "null" && "$pvcNamespace" != "$backupNamespace" ]]; then
      logWarning "Skipping Persistent Volume Claim $pvcName in file $(basename $yaml) it has a non-matching namespace: $pvcNamespace"
    else     
      if [[ "$pvcStorageClass" == "null" ]]; then
        logWarning "Skipping Persistent Volume Claim $pvcName in file $(basename $yaml) it does not reference a storage class"
      else
        if oc get storageclass "$pvcStorageClass" > /dev/null 2> /dev/null; then
          if restore_this_pvc $pvcName $backupDeploymentName; then
            if is_existing_pvc $pvcName; then
              logInfoValue "Persistent Volume Claim already defined: " $pvcName
            else
              yamlFiles+=($yaml)
              countYamlFiles=$(expr $countYamlFiles + 1)
            fi
          fi
        else
          logWarning "Skipping Persistent Volume Claim $pvcName in file $(basename $yaml) as it refers to storage class $pvcStorageClass which does not exist."
        fi
      fi
    fi
  fi
done

echo

if [[ "$countYamlFiles" == "0" ]]; then
	logInfo "All Persistent Volume Claims have already been applied"
else

  echo
  echo "The script will try to apply following Persistent Volume Claims (PVC):"

  for file in "${yamlFiles[@]}"; do
    pvcName=$(yq eval '.metadata.name' $file)
    echo -e "\tPVC \x1B[1m$pvcName\x1B[0m  (File: $(basename $file))"
  done
  echo
  printf "OK to apply these PVC definitions? (Yes/No, default Yes): "
  read -rp "" ans
  case "$ans" in
  "n"|"N"|"no"|"No"|"NO")
     echo
     echo -e "Exiting..."
     echo
     exit 0
     ;;
  *)
     echo
     echo -e "OK..."
     ;;
  esac
  
  for file in "${yamlFiles[@]}"; do
    pvcName=$(yq eval '.metadata.name' $file)
    logInfoValue "Defining PVC " ${pvcName}
    yq eval 'del(.status, .metadata.finalizers, .metadata.resourceVersion, .metadata.uid, .metadata.annotations, .metadata.creationTimestamp, .metadata.selfLink, .metadata.managedFields, .metadata.ownerReferences, .spec.volumeMode, .spec.volumeName)' $file | oc apply -f - -n $backupNamespace

  done
fi

waitUntilBound=20

while [ $waitUntilBound -gt 0 ]; do 
  numNotBound=$(oc get pvc -o custom-columns=name:.metadata.name,phase:.status.phase --no-headers -n $backupNamespace | grep -v Bound | wc -l)
  if [ $numNotBound -eq 0 ]; then
    break
  fi
  waitUntilBound=$((waitUntilBound - 1))
  if [ $waitUntilBound -gt 0 ]; then
    echo "PVCs not in bound status: $numNotBound, waiting 10s..."
    sleep 10
  else
    echo "PVs still in bound status: $numNotBound, please check it. Aborting."
    exit 1
  fi
done 

logInfo "All PVCs are now in bound state"

PV_BACKUP_DIR=${pvBackupDirectory}/$(basename $(dirname $BACKUP_DIR))/$(basename $BACKUP_DIR)
logInfoValue "PV Backup Directory: " $PV_BACKUP_DIR

BACKUP_UID=$(cat $BACKUP_DIR/namespace_uid)
RESTORE_UID=$(oc describe project $cp4baProjectName | grep uid-range | cut -d"=" -f2 | cut -d"/" -f1)

logInfoValue "PV UID in backup: " $BACKUP_UID
logInfoValue "PV UID in restored project: " $RESTORE_UID


index=0
for storageclass in ${barStorageClass[@]}; do
    method=${barMethod[$index]}
    configData=${barConfigData[$index]}
    index=$(( index + 1 ))

    if [ "$method" == "ServerBackup" ]; then
	logInfoValue "Restoring PV data for PVs using StorageClass " $storageclass

        rootDirectory=$(echo $configData | jq -r '.rootDirectory')        
        PV_BACKUP_DIR=${pvBackupDirectory}/$(basename $(dirname $BACKUP_DIR))/$(basename $BACKUP_DIR)        

        cat > $BACKUP_DIR/111-restore-pvs-${storageclass}.sh <<EOF
#!/bin/bash

function perform_restore() {
    namespace=\$1
    policy=\$2
    volumename=\$3
    claimname=\$4

    if [ "\$policy" == "${storageclass}" ]; then
        echo "Restoring PVC \$claimname"
        directory="$rootDirectory/\${namespace}-\${claimname}-\${volumename}"
        if [ ! -e \$pvBackupDirectory/\${claimname}.tgz ]; then
            echo "*** Error: Did not find persistent volume backup in \$pvBackupDirectory/\${claimname}.tgz"
        elif [ -d "\$directory" ]; then
            (cd \$directory; tar xfz \$pvBackupDirectory/\${claimname}.tgz)
            if [ "\$backupUid" == "\$restoreUid" ]; then
                echo "    Skipping UID Conversion as they are equal"
            else 
                echo "    Reassigning files belonging to \$backupUid to changed owner \$restoreUid"
                find \$directory -uid \$backupUid -exec chown \$restoreUid {} \; 
            fi
        else
            echo "*** Error: Did not find persistent volume directory \$directory"
        fi
    else
        echo "*** Error: Dont know how to restore storage policy named \$policy"
    fi
}

pvBackupDirectory="${PV_BACKUP_DIR}"

if [ ! -d \$pvBackupDirectory ]; then 
    echo "**** Did not find PV Backup Directory \$pvBackupDirectory"
    exit 1
fi

backupUid="${BACKUP_UID}"
restoreUid="${RESTORE_UID}"

EOF
        for pvc in $(oc get pvc -n $cp4baProjectName -o 'custom-columns=name:.metadata.name' --no-headers); do
	          class=$(oc get pvc $pvc -o 'jsonpath={.spec.storageClassName}')
	          if [ "$class" == "$storageclass" ]; then
                      # exclude cp4a-shared-log-pvc here, we only need the PVC, not the data from it
                      if [ "$pvc" != "cp4a-shared-log-pvc" ]; then
        	          namespace=$(oc get pvc $pvc -o 'jsonpath={.metadata.namespace}')
	                  pv=$(oc get pvc $pvc -o 'jsonpath={.spec.volumeName}')
	                  echo perform_restore $namespace $class $pv $pvc >> $BACKUP_DIR/111-restore-pvs-${storageclass}.sh
        	          chmod +x $BACKUP_DIR/111-restore-pvs-${storageclass}.sh
                      fi
        	  fi
	      done
        logInfoValue "PV Restore Script Generated: " 111-restore-pvs-${storageclass}.sh        
    fi
done



echo
echo "Run the generated PV Restore Script on the storage server with the root user."
read -p "Press Return to continue, CTRL-C to abort" choice
echo

CP4BASubscription=$BACKUP_DIR/subscription.operators.coreos.com/ibm-cp4a-operator.yaml

if [ ! -e $CP4BASubscription ]; then
   logError "CP4BA Operator Subscription not found in backup : " $CP4BASubscription
else
   logInfoValue "CP4BA Operator Subscription: " $CP4BASubscription
   cp4baVersion=$(yq eval '.status.currentCSV' $CP4BASubscription)
   logInfoValue "Version used by backup: " $cp4baVersion
fi
echo

echo "Creating CR for restore..."
#yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.generation, .metadata.resourceVersion, .metadata.uid, .spec.initialize_configuration)' $CR_SPEC > $BACKUP_DIR/$(basename $CR_SPEC)
yq eval 'del(.metadata.annotations, .metadata.creationTimestamp, .metadata.generation, .metadata.resourceVersion, .metadata.uid)' $CR_SPEC > $BACKUP_DIR/$(basename $CR_SPEC)
#yq eval '.spec.shared_configuration.sc_content_initialization = false' -i $BACKUP_DIR/$(basename $CR_SPEC)
yq eval 'del(.status)' -i $BACKUP_DIR/$(basename $CR_SPEC)
# TODO: Case event emitter does still cause some trouble, removing it for the moment!
#yq eval 'del(.spec.workflow_authoring_configuration.case.event_emitter)' -i $BACKUP_DIR/$(basename $CR_SPEC)
# TODO: Disable Case event emitter for Runtime environment, too
#yq eval 'del(.spec.workflow_authoring_configuration.case.event_emitter)' -i $BACKUP_DIR/$(basename $CR_SPEC)
echo

echo "Removing all lines containing null or empty string..."
fileName=${BACKUP_DIR}/${backupDeploymentName}New.yaml
if [ -f "$fileName" ]; then
  rm -f $fileName
fi
pattern1="null"
pattern2="\"\""
pattern3="sc_run_as_user"
while IFS="" read -r p || [ -n "$p" ]
do
  line=$(printf '%s\n' "$p")
  if [[ ! $line =~ $pattern2 ]]; then
    if [[ $line =~ $pattern3 ]]; then
      echo "$line" >> $fileName
    else
      if [[ ! $line =~ $pattern1 ]]; then
        echo "$line" >> $fileName
      fi
    fi
  fi
done < $BACKUP_DIR/$(basename $CR_SPEC)
echo

echo "After deployment of the CP4BA Operator, you should be able to apply the CR from file"
echo "  " $BACKUP_DIR/$(basename $CR_SPEC)
echo "Or"
echo "  " $fileName
echo

# Save some data to Openshift for Post Deployment to pick it up
oc create configmap cp4ba-backup-and-restore \
  --from-literal backup-dir=$BACKUP_DIR \
  --from-literal bar-version=$bar_version
echo
