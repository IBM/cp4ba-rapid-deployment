#!/bin/bash -e
# set -x
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

##
## Import common OCP script library
##
. ./common-ocp-utils.sh
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DB2_INPUT_PROPS_FILENAME="01-parametersForDb2OnOCP.sh"
DB2_INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${DB2_INPUT_PROPS_FILENAME}"

##
## Validate input from 01-parametersForDb2OnOCP.sh
##
if [[ -f $DB2_INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${DB2_INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   . $DB2_INPUT_PROPS_FILENAME_FULL
   
   if [ $db2OnOcpProjectName == "REQUIRED" ] || [ $db2AdminUserPassword == "REQUIRED" ] || [ "$db2StandardLicenseKey" == "REQUIRED" ]; then
      echo "File ${DB2_INPUT_PROPS_FILENAME} not fully updated. Pls. update all parameters in the BEFORE running script section."
      echo
      exit 1
   fi
   
   echo "Done!"
else
   echo
   echo "File ${DB2_INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 1
fi

##
## Ask for confirmation and continue
##
echo
echo -e "\x1B[1mThis script installs Db2u on OCP into project ${db2OnOcpProjectName}. For this, you need the jq tool installed and your Entitlement Registry key handy.\n \x1B[0m"

printf "Do you want to continue (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Installing Db2U on OCP..."
    ;;
*)
    echo
    echo -e "Exiting..."
    echo
    exit 1
    ;;
esac

##
## Install storage class definitions upddates in ROKS installations
##
if [ $cp4baDeploymentPlatform == "ROKS" ]; then
  echo
  echo "Installing the storage classes..."
  oc apply -f cp4a-bronze-storage-class.yaml
  oc apply -f cp4a-silver-storage-class.yaml
  oc apply -f cp4a-gold-storage-class.yaml
  kubectl patch storageclass ibmc-block-gold -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
  kubectl patch storageclass cp4a-file-delete-gold-gid -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi

##
## Install storage class definitions upddates in ROKS installations
##
echo
echo "Installing the IBM Operator Catalog..."
oc apply -f ibmOperatorCatalog.yaml

##
## Create DB2 project as specified in 01-parametersForDb2OnOCP.sh
##
echo
echo "Creating project ${db2OnOcpProjectName}..."
cp db2-namespace.template.yaml db2-namespace.yaml
sed -i.bak "s|paramDB2Namespace|$db2OnOcpProjectName|g" db2-namespace.yaml
oc apply -f db2-namespace.yaml
oc project ${db2OnOcpProjectName}

##
## Get entitlement key to download DB2 images from IBM Container Registry.
##
echo
echo "Creating secret ibm-registry. For this, your Entitlement Registry key is needed."
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

##
## Create docker registry secret
##
oc create secret docker-registry ibm-registry --docker-server=${DOCKER_REG_SERVER} --docker-username=${DOCKER_REG_USER} --docker-password=${ENTITLEMENTKEY} --docker-email=${EMAIL} --namespace=${db2OnOcpProjectName} --dry-run=client -o=yaml | oc apply -n ${db2OnOcpProjectName} --filename=-

if [ $cp4baDeploymentPlatform == "ROKS" ]; then
  echo
  echo "Preparing the cluster for Db2..."
  oc get no -l node-role.kubernetes.io/worker --no-headers -o name | xargs -I {} --  oc debug {} -- chroot /host sh -c 'grep "^Domain = slnfsv4.coms" /etc/idmapd.conf || ( sed -i.bak "s/.*Domain =.*/Domain = slnfsv4.com/g" /etc/idmapd.conf; nfsidmap -c; rpc.idmapd )'
fi

##
## Modify the OpenShift Global Pull Secret
##
echo
echo "Modifying the OpenShift Global Pull Secret (you need jq tool for that):"
echo $(oc get secret pull-secret -n openshift-config --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode; oc get secret ibm-registry -n ${db2OnOcpProjectName} --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode) | jq -s '.[0] * .[1]' > dockerconfig_merged
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=dockerconfig_merged

## 
## Creating DB2 Operator Group 
##
echo
echo "Creating Operator Group object for DB2 Operator"
cp  db2-operatorgroup.template.yaml  db2-operatorgroup.yaml
sed -i.bak "s|paramDB2Namespace|$db2OnOcpProjectName|g" db2-operatorgroup.yaml
oc apply -f db2-operatorgroup.yaml

##
## Create Subscription object for the DB2 operator.  The DB2 subscription template used here has
## an install approval policy for Manual and also specifies the channel and version of the DB2 operator to install. 
## This combination makes sure that we install the exact version of the Operator that we
## want, avoiding automatic updates and therefore we can control the actual
## version of DB2 that gets installed in the environments as opposed of just installing whatever is the
## latest operator which could change the supported DB2 versions that can be used. 
##
echo
echo "Creating Subscription object for DB2 Operator"
cp db2-subscription.template.yaml db2-subscription.yaml
sed -i.bak "s|paramDB2Namespace|$db2OnOcpProjectName|g" db2-subscription.yaml
sed -i.bak "s|paramDB2OperatorVersion|$db2OperatorVersion|g" db2-subscription.yaml
sed -i.bak "s|paramDB2OperatorChannel|$db2OperatorChannel|g" db2-subscription.yaml
oc apply -f db2-subscription.yaml

##
## Waiting up to 5 minutes for DB2 Operator install plan to be generated
## The name for the DB2 operator subscription in our template is db2u-operator
## using that to find install plan generated for the subscription
##
echo
echo "Waiting up to 5 minutes for DB2 Operator install plan to be generated."
date
installPlan=$(wait_for_install_plan "db2u-operator" 5 $db2OnOcpProjectName)
if [ -z "$installPlan" ]
then
  echo "Timed out waiting for DB2 install plan. Check status for CSV $db2OperatorVersion"
  exit 1
fi

##
## Approve DB2 Operator install plan.
##
echo
echo "Approving DB2 Operator install plan."
oc patch installplan $installPlan --namespace $db2OnOcpProjectName --type merge --patch '{"spec":{"approved":true}}'

##
## Waiting up to 5 minutes for DB2 Operator installation to complete. 
## The CSV name for the DB2 operator is exactly the version of the CSV hence 
## using db2OperatorVersion as the operator name.
##
echo
echo "Waiting up to 5 minutes for DB2 Operator to install."
date
operatorInstallStatus=$(wait_for_operator_to_install_successfully $db2OperatorVersion 5 $db2OnOcpProjectName)
if [ -z "$operatorInstallStatus" ]
then
  echo "Timed out waiting for DB2 operator to install.  Check status for CSV $db2OperatorVersion"
  exit 1
fi

##
## Create the DB2 Cluster instance using our predefined template
##
echo
echo "Deploying the Db2u cluster."
cp db2.template.yaml db2.yaml
sed -i.bak "s|db2OnOcpProjectName|$db2OnOcpProjectName|g" db2.yaml
sed -i.bak "s|db2AdminUserPassword|$db2AdminUserPassword|g" db2.yaml
sed -i.bak "s|db2InstanceVersion|$db2InstanceVersion|g" db2.yaml
sed -i.bak "s|db2Cpu|$db2Cpu|g" db2.yaml
sed -i.bak "s|db2Memory|$db2Memory|g" db2.yaml
sed -i.bak "s|db2StorageSize|$db2StorageSize|g" db2.yaml
sed -i.bak "s|db2OnOcpStorageClassName|$db2OnOcpStorageClassName|g" db2.yaml
db2License="accept: true"
if [ "$db2StandardLicenseKey" == "" ]; then
   db2License="accept: true"
else
   db2License="value: $db2StandardLicenseKey"
fi
sed -i.bak "s|db2License|$db2License|g" db2.yaml
oc apply -f db2.yaml

##
## Wait for c-db2ucluster-db2u statefulset to be created so that we can apply requried patch.
## This patch removes the tty issue that prevents the db2u pod from starting
##
echo
echo "Waiting up to 15 minutes for c-db2ucluster-db2u statefulset to be created."
date
statefulsetQualifiedName=$(wait_for_resource_created_by_name statefulset c-db2ucluster-db2u 15 $db2OnOcpProjectName)
if [ -z "$statefulsetQualifiedName" ]
then
  echo "Timed out waiting for c-db2ucluster-db2u statefulset to be created by DB2 operator"
  exit 1
fi

echo
echo "Patching c-db2ucluster-db2u statefulset."
oc patch $statefulsetQualifiedName -n=$db2OnOcpProjectName -p='{"spec":{"template":{"spec":{"containers":[{"name":"db2u","tty":false}]}}}}}'

##
## Wait for  c-db2ucluster-restore-morph job to complte. If this job completes successfully
## we can tell that the deployment was completed successfully.
##
echo
echo "Waiting up to 20 minutes for c-db2ucluster-restore-morph job to complete successfully."
date
jobStatus=$(wait_for_job_to_complete_by_name c-db2ucluster-restore-morph 20 $db2OnOcpProjectName)
if [ -z "$jobStatus" ]
then
  echo "Timed out waiting for c-db2ucluster-restore-morph job to complete successfully."
  exit 1
fi

##
## Now that DB2 is running let's update the number of databases allowed 
## This is done by updating the NUMDB property in the ConfigMap c-db2ucluster-db2dbmconfig 
##
echo
echo "Updating number of databases allowed by DB2 installation from 8 to 20."
oc get configmap c-db2ucluster-db2dbmconfig -n $db2OnOcpProjectName -o yaml | sed "s|NUMDB 8|NUMDB 20|" |  oc replace configmap -n $db2OnOcpProjectName --filename=-

echo
echo "Updating database manager running configuration."
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2 update dbm cfg using numdb 20"
sleep 10 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2set DB2_WORKLOAD=FILENET_CM"
sleep 10 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "set CUR_COMMIT=ON"
sleep 30 #let DB2 settle down

echo
echo "Restarting DB2 instance."
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su -c "sudo wvcli system disable"
sleep 30 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2stop"
sleep 30 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2start"
sleep 30 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su -c "sudo wvcli system enable"
sleep 30 #let DB2 settle down

## 
## We are done installing and configuring DB2
## After this point the script should not fail if any of the commands do not complete
## successfully so turning of the -e option 
##
set +e
echo
echo "*********************************************************************************"
echo "********* Installation and configuration of DB2 completed successfully! *********"
echo "*********************************************************************************"

echo
echo "Removing BLUDB from system."
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2 force application all"
sleep 30 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2 deactivate database BLUDB"
sleep 30 #let DB2 settle down
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2 drop database BLUDB"
sleep 30 #let DB2 settle down

echo
echo "Existing databases are:"
oc exec c-db2ucluster-db2u-0 -it -c db2u -- su - $db2AdminUserName -c "db2 list database directory | grep \"Database name\" | cat"

echo
echo "Use this hostname/IP to access the databases e.g. with IBM Data Studio."
#echo -e "\x1B[1mPlease also update in ${DB2_INPUT_PROPS_FILENAME} property \"db2HostName\" with this information (in Skytap, use the IP 10.0.0.10 instead)\x1B[0m"
routerCanonicalHostname=$(oc get route console -n openshift-console -o yaml | grep routerCanonicalHostname | cut -d ":" -f2)
workerNodeAddresses=$(get_worker_node_addresses_from_pod c-db2ucluster-db2u-0 $db2OnOcpProjectName)
echo -e "\tHostname:${routerCanonicalHostname}"
echo -e "\tOther possible addresses(If hostname not available above): $workerNodeAddresses" 

echo
echo "Use one of these NodePorts to access the databases e.g. with IBM Data Studio (usually the first one is for legacy-server (Db2 port 50000), the second for ssl-server (Db2 port 50001))."
#echo -e "\x1B[1mPlease also update in ${DB2_INPUT_PROPS_FILENAME} property \"db2PortNumber\" with this information (legacy-server).\x1B[0m"
oc get svc -n ${db2OnOcpProjectName} c-db2ucluster-db2u-engn-svc -o json | grep nodePort

echo
echo "Use \"$db2AdminUserName\" and password \"$db2AdminUserPassword\" to access the databases e.g. with IBM Data Studio."

echo
echo "Db2u installation complete! Congratulations. Exiting..."
