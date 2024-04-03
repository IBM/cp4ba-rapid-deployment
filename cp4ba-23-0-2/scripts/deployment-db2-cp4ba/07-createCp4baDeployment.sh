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

CP4BA_VERSION=ibm-cp4a-operator.v23.2.2

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DB2_INPUT_PROPS_FILENAME="01-parametersForDb2OnOCP.sh"
DB2_INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${DB2_INPUT_PROPS_FILENAME}"

if [[ -f $DB2_INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${DB2_INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   . $DB2_INPUT_PROPS_FILENAME_FULL
   
   echo "Done!"
else
   echo
   echo "File ${DB2_INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 0
fi

CP4BA_INPUT_PROPS_FILENAME="05-parametersForCp4ba.sh"
CP4BA_INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${CP4BA_INPUT_PROPS_FILENAME}"

if [[ -f $CP4BA_INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${CP4BA_INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   . $CP4BA_INPUT_PROPS_FILENAME_FULL

   if [ "x$cp4baOcpHostname" == "x" ]; then
       echo Extracting OCP Hostname
       cp4baOcpHostname=$(oc get route console -n openshift-console -o jsonpath={.status.ingress[0].host} | sed s/^[^.]*\.//)
       echo OCPHostname set to $cp4baOcpHostname
   else
       echo OCPHostname defined as $cp4baOcpHostname
   fi
   
   if [ $cp4baProjectName == "REQUIRED" ] || [ "$cp4baTlsSecretName" == "REQUIRED" ] || [ $cp4baAdminPassword == "REQUIRED" ] || [ $ldapAdminPassword == "REQUIRED" ] || [ $ldapServer == "REQUIRED" ]; then
      echo "File ${CP4BA_INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 0
   fi

   echo "Done!"
else
   echo
   echo "File ${CP4BA_INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 0
fi

echo
if oc get subscription ibm-cp4a-operator-catalog-subscription -n $cp4baProjectName > /dev/null 2>&1; then
    
    CP4BAVERSION=$(oc get subscription ibm-cp4a-operator-catalog-subscription  -n $cp4baProjectName -o 'jsonpath={.status.currentCSV}')
else
    if oc get subscription ibm-cp4a-operator -n $cp4baProjectName >/dev/null 2>&1; then
	CP4BAVERSION=$(oc get subscription ibm-cp4a-operator  -n $cp4baProjectName -o 'jsonpath={.status.currentCSV}' -n $cp4baProjectName)
    else
	echo "Cannot find IBM CP4BA Operator Subscription"
    fi
fi

if [ "x$CP4BAVERSION" == "x$CP4BA_VERSION" ]; then
    echo "Using correct cp4ba version."
else
    echo "Missing or incorrect cp4ba version: $CP4BAVERSION"
    echo "Might need to fix catalog sources, apply cp4ba_catalog_sources.yaml"
    read -rp "Continue anyway (Yes/No) ?" ans
    case "$ans" in
	"y"|"Y"|"yes"|"Yes"|"YES")
	    echo "Lets see what happens...";;
	*)
	    echo "Aborting...";
	    exit 1;;
    esac
fi

echo
echo -e "\x1B[1mThis script PREPARES and optionaly CREATES the CP4BA deployment using template ${cp4baTemplateToUse} in project ${cp4baProjectName}. \n \x1B[0m"

printf "Are ${DB2_INPUT_PROPS_FILENAME} and ${CP4BA_INPUT_PROPS_FILENAME} up to date, and do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Preparing the CP4BA deployment..."
    ;;
*)
    echo
    echo -e "Exiting..."
    echo
    exit 0
    ;;
esac

echo
echo "Switching to project ${cp4baProjectName}..."
oc project $cp4baProjectName

echo
echo "Collecting information for secret ibm-entitlement-key. For this, your Entitlement Registry key is needed."
echo
echo "You can get the Entitlement Registry key from here: https://myibm.ibm.com/products-services/containerlibrary"
echo
ENTITLEMENTKEY=""
EMAIL="me@here.com"
DOCKER_REG_SERVER="cp.icr.io"
DOCKER_REG_USER="cp"
printf "\x1B[1mEnter your Entitlement Registry key: \x1B[0m"
while [[ $ENTITLEMENTKEY == '' ]]
do
  read -rsp "" ENTITLEMENTKEY
  if [ -z "$ENTITLEMENTKEY" ]; then
    printf "\n"
    printf "\x1B[1;31mEnter a valid Entitlement Registry key: \x1B[0m"
  else
    DOCKER_REG_KEY=$ENTITLEMENTKEY
    entitlement_verify_passed=""
    while [[ $entitlement_verify_passed == '' ]]
    do
      printf "\n"
      printf "Verifying the Entitlement Registry key...\n"
      if podman login -u "$DOCKER_REG_USER" -p "$DOCKER_REG_KEY" "$DOCKER_REG_SERVER" --tls-verify=false; then
        printf 'Entitlement Registry key is valid.\n'
        entitlement_verify_passed="passed"
      else
        printf '\x1B[1;31mThe Entitlement Registry key verification failed. Enter a valid Entitlement Registry key: \x1B[0m'
        ENTITLEMENTKEY=''
        entitlement_verify_passed="failed"
      fi
    done
  fi
done

echo
echo "Deployment of CP4BA required synchronied clocks among the server nodes."
printf "\x1B[1;31mSynchronize clocks now (y/n) ?\x1B[0m"
read -rsp "" ans
case "$ans" in
    "y"|"Y"|"yes"|"Yes"|"YES")
	echo "Synchronizing clocks on worker nodes..."
	oc get node -l node-role.kubernetes.io/worker --no-headers -o name | xargs -I {} -- oc debug {} -- chroot /host sh -c 'echo restarting chronyd on $HOSTNAME; systemctl restart chronyd'
	echo "Clocks on worker nodes should be synchronzied now"
	echo
	;;
    *)
	echo "Not synchronizing clocks..."
	;;
esac

echo
echo "Preparing the CP4BA secrets..."
cp secrets.template.yaml secrets.yaml
sed -i.bak "s|db2AdminUserName|$db2AdminUserName|g" secrets.yaml
sed -i.bak "s|db2AdminUserPassword|$db2AdminUserPassword|g" secrets.yaml
sed -i.bak "s|cp4baAdminName|$cp4baAdminName|g" secrets.yaml
sed -i.bak "s|cp4baAdminPassword|$cp4baAdminPassword|g" secrets.yaml
sed -i.bak "s|ldapAdminName|$ldapAdminName|g" secrets.yaml
sed -i.bak "s|ldapAdminPassword|$ldapAdminPassword|g" secrets.yaml
sed -i.bak "s|cp4baAdminFullName|$cp4baAdminFullName|g" secrets.yaml
rm secrets.yaml.bak


bawLibertyCustomXml=""

tlsSecretName=
if [ $cp4baDeploymentPlatform == "ROKS" ] && [ "$cp4baTlsSecretName" != "" ]; then
  echo
  echo "Preparing the tls secret..."
  oc project ibm-cert-store
  
  tlsCert=$(oc get secret/$cp4baTlsSecretName -o "jsonpath={.data.tls\.crt}")
  tlsKey=$(oc get secret/$cp4baTlsSecretName -o "jsonpath={.data.tls\.key}")
  
  oc project $cp4baProjectName
  
  cp tlsSecrets.template.yaml tlsSecrets.yaml
  sed -i.bak "s|tlsCert|$tlsCert|g" tlsSecrets.yaml
  sed -i.bak "s|tlsKey|$tlsKey|g" tlsSecrets.yaml
  tlsSecretName=icp4a-tls-secret
  rm tlsSecrets.yaml.bak
fi

echo
echo "Preparing the CR YAML for deployment..."

cp $cp4baTemplateToUse ibm_cp4a_cr_final.yaml

sed -i.bak "s|db2HostName|TODO|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|db2HostIp|TODO|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|db2PortNumber|TODO|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|db2SslEnabled|$db2SslEnabled|g" ibm_cp4a_cr_final.yaml

DBINSTANCES=$(sed -n '/Database Instances:/{
	  s,^.*:,,g
	  p
}' $cp4baTemplateToUse)

dbinst=1
while [ $dbinst -le $DBINSTANCES ]; do
    SEDCOMMAND=$(printf '/DBs on Instance %1d:/p' $dbinst)
    DBs=$(sed -n "$SEDCOMMAND" $cp4baTemplateToUse | sed 's,^.*:,,g' | sed 's, ,x,g' | sed 's,$,x,g')

    if [ $db2UseOnOcp == "true" ]; then
	DB2HOSTNAME=$(printf 'c-db2-inst%1d-db2u-engn-svc.%s.svc' $dbinst $db2OnOcpProjectName)
	DB2PORTNUMBER=50000
	DB2HOSTIP=$DB2HOSTNAME
    else
	DB2HOSTNAME=${db2HostName[$dbinst]}
	DB2PORTNUMBER=${db2PortNumber[$dbinst]}
	DB2HOSTIP=${db2HostIp[$dbinst]}
    fi
    
    DB2SSLSECRETNAME=${db2SslSecretName[$dbinst]}
    
    if [[ $DBs =~ xICNx ]]; then
	sed -i.bak "s|db2IcndbName|$db2IcndbName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2IcndbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2IcndbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2IcndbHostIp|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2IcndbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xCLOSx ]]; then
	sed -i.bak "s|db2ClosName|$db2ClosName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2ClosdbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2ClosdbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2ClosdbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2ClosdbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
        sed -i.bak "s|db2ClosdbSchemaName|$db2AdminUserName|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xDEVOS1x ]]; then    
	sed -i.bak "s|db2Devos1Name|$db2Devos1Name|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2Devos1dbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2Devos1dbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2Devos1dbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2Devos1dbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
        sed -i.bak "s|db2Devos1dbSchemaName|$db2AdminUserName|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xAEOSx ]]; then
	sed -i.bak "s|db2AeosName|$db2AeosName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AeosdbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AeosdbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AeosdbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AeosdbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
        sed -i.bak "s|db2AeosdbSchemaName|$db2AdminUserName|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xBAWDOCSx ]]; then
	sed -i.bak "s|db2BawDocsName|$db2BawDocsName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawDocsdbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawDocsdbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawDocsdbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawDocsdbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
        sed -i.bak "s|db2BawDocsdbSchemaName|$db2AdminUserName|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xBAWDOSx ]]; then  
	sed -i.bak "s|db2BawDosName|$db2BawDosName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawDosdbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawDosdbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawDosdbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawDosdbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
        sed -i.bak "s|db2BawDosdbSchemaName|$db2AdminUserName|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xBAWTOSx ]]; then       
	sed -i.bak "s|db2BawTosName|$db2BawTosName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawTosdbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawTosdbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawTosdbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawTosdbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
        sed -i.bak "s|db2BawTosdbSchemaName|$db2AdminUserName|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xBAWx ]]; then
	# Yes, this uses db2BwaDbName, and below ones use lowercase "db", must be consistent with all templates
	sed -i.bak "s|db2BawDbName|$db2BawDbName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawdbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawdbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawdbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BawdbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xAPPx ]]; then
	sed -i.bak "s|db2AppdbName|$db2AppdbName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AppdbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AppdbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AppdbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AppdbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xAEx ]]; then
	sed -i.bak "s|db2AedbName|$db2AedbName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AedbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AedbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AedbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2AedbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xBASx ]]; then
	sed -i.bak "s|db2BasdbName|$db2BasdbName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BasdbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BasdbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BasdbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2BasdbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xGCDx ]]; then
	sed -i.bak "s|db2GcddbName|$db2GcddbName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2GcddbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2GcddbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2GcddbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2GcddbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml
    fi
    if [[ $DBs =~ xODMx ]]; then
	sed -i.bak "s|db2OdmdbName|$db2OdmdbName|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2OdmdbHostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2OdmdbPortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2OdmdbHostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|db2OdmdbSslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml	
    fi
    if [[ $DBs =~ xADPx ]]; then
	sed -i.bak "s|adpDb2HostName|$DB2HOSTNAME|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|adpDb2PortNumber|$DB2PORTNUMBER|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|adpDb2Hostip|$DB2HOSTIP|g" ibm_cp4a_cr_final.yaml
	sed -i.bak "s|adpDb2SslSecretName|$DB2SSLSECRETNAME|g" ibm_cp4a_cr_final.yaml	
    fi
    dbinst=$(( $dbinst + 1 ))
done

sed -i.bak "s|ldapName|$ldapName|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapType|$ldapType|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapServer|$ldapServer|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapPort|$ldapPort|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapSslEnabled|$ldapSslEnabled|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapSslSecretName|$ldapSslSecretName|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapBaseDn|$ldapBaseDn|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapUserNameAttribute|$ldapUserNameAttribute|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapUserDisplayNameAttr|$ldapUserDisplayNameAttr|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapGroupBaseDn|$ldapGroupBaseDn|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapGroupNameAttribute|$ldapGroupNameAttribute|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapGroupDisplayNameAttr|$ldapGroupDisplayNameAttr|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapGroupMembershipSearchFilter|$ldapGroupMembershipSearchFilter|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapGroupMemberIdMap|$ldapGroupMemberIdMap|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapAdGcHost|$ldapAdGcHost|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapAdGcPort|$ldapAdGcPort|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapAdUserFilter|$ldapAdUserFilter|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapAdGroupFilter|$ldapAdGroupFilter|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapTdsUserFilter|$ldapTdsUserFilter|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|ldapTdsGroupFilter|$ldapTdsGroupFilter|g" ibm_cp4a_cr_final.yaml

sed -i.bak "s|cp4baDeploymentPlatform|$cp4baDeploymentPlatform|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baOcpHostname|$cp4baOcpHostname|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baScSlow|$cp4baScSlow|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baScMedium|$cp4baScMedium|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baScFast|$cp4baScFast|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baBlockScFast|$cp4baBlockScFast|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baReplicaCount|$cp4baReplicaCount|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baBaiJobParallelism|$cp4baBaiJobParallelism|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baDeploymentProfileSize|$cp4baDeploymentProfileSize|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baADPDeploymentProfileSize|$cp4baADPDeploymentProfileSize|g" ibm_cp4a_cr_final.yaml

sed -i.bak "s|cp4baAdminName|$cp4baAdminName|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baAdminPassword|$cp4baAdminPassword|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baAdminGroup|$cp4baAdminGroup|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baUsersGroup|$cp4baUsersGroup|g" ibm_cp4a_cr_final.yaml

sed -i.bak "s|cp4baAdminFullName|$cp4baAdminFullName|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|cp4baGroupAdminFullName|$cp4baGroupAdminFullName|g" ibm_cp4a_cr_final.yaml

sed -i.bak "s|bawLibertyCustomXml|$bawLibertyCustomXml|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|tlsSecretName|$tlsSecretName|g" ibm_cp4a_cr_final.yaml

sed -i.bak "s|contentOSname|$contentOSname|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|contentOSasa|$contentOSasa|g" ibm_cp4a_cr_final.yaml
sed -i.bak "s|contentOSsd|$contentOSsd|g" ibm_cp4a_cr_final.yaml

if [ $cp4baDeploymentPlatform == "ROKS" ] && [ "$cp4baTlsSecretName" != "" ]; then
  sed -i.bak "s|trustedCertificateList|- $tlsSecretName|g" ibm_cp4a_cr_final.yaml
else
  sed -i.bak "s|trustedCertificateList||g" ibm_cp4a_cr_final.yaml
fi
rm ibm_cp4a_cr_final.yaml.bak

# finally, create all the prepared artifacts on OCP if user decides to do that
echo
echo -e "\x1B[1mAll artefacts for deployment are prepared. \n \x1B[0m"

printf "Do you want to CREATE the CP4BA deployment in project ${cp4baProjectName} now? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Creating the CP4BA deployment..."
    ;;
*)
    echo
    echo -e "Exiting without creating the deployment..."
    echo
    exit 0
    ;;
esac

echo "Creating secret ibm-entitlement-key in project $cp4baProjectName..."
if oc get secret ibm-entitlement-key -n $cp4baProjectName  > /dev/null 2>&1; then
    echo "Already exists"
else
    oc create secret docker-registry ibm-entitlement-key  --docker-server=${DOCKER_REG_SERVER} --docker-username=${DOCKER_REG_USER} --docker-password=${ENTITLEMENTKEY} --docker-email=${EMAIL} --namespace=$cp4baProjectName
    echo "Done."
fi

oc project $cp4baProjectName

echo
echo "Creating CP4BA secrets..."
oc apply -f secrets.yaml -n $cp4baProjectName
echo "Done."

if [ $cp4baDeploymentPlatform == "ROKS" ] && [ "$cp4baTlsSecretName" != "" ]; then
  echo
  echo "Creating the tls secret..."
  oc apply -f tlsSecrets.yaml -n $cp4baProjectName
  echo "Done."
fi

echo
echo "Creating the CP4BA deployment..."
oc apply -f ibm_cp4a_cr_final.yaml -n $cp4baProjectName
echo "Done."

echo
echo "All changes got applied. Exiting..."
echo