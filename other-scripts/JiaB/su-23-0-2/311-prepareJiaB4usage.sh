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

# This script is for preparing the JiaB environment on TechZone before being able to use it. It re-starts SDS, resumes OCP updates and scales up pods that were scaled down while the environment was shut down.
#    CP4BA version: 23.0.2 IF002
#    CP4BA template used for deployment: ibm_cp4a_cr_template.201.ent.ClientOnboardingDemoWithADPOneDB.yaml

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
echo -e "\x1B[1mThis script prepares the JiaB environment on TechZone before being able to use it. It re-starts SDS, resumes OCP updates and scales up pods that were scaled down while the environment was shut down. \n \x1B[0m"

printf "Do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Scaling up the CP4BA deployment..."
    ;;
*)
    echo
    echo -e "Exiting..."
    echo
    exit 0
    ;;
esac

echo
echo "Verifying OC CLI is connected to the OCP cluster..."
WHOAMI=$(oc whoami)

if [[ $WHOAMI != "ocadmin" ]]; then
  echo "OC CLI is NOT connected to the OCP cluster. Please log in first with user \"ocadmin\" to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
  echo
  exit 0
fi

echo
echo "Switching to project ${cp4baProjectName}..."
oc project $cp4baProjectName
echo



# First, start SDS
echo "Re-starting SDS..."
sudo systemctl stop sds
sudo systemctl start sds
sleep 15
echo



# Second, resume the OCP updates
echo "Resuming OCP updates..."
oc patch MachineConfigPool master --type merge --patch '{"spec":{"paused":false}}'
oc patch MachineConfigPool worker --type merge --patch '{"spec":{"paused":false}}'
sleep 15
echo



# Third, start the pods of the CP4BA deployment that got scaled down before
# Delete the es route, will get re-generated automatically
echo "Renewing es route..."
oc delete route iaf-system-es
esPod=$(oc get pods -o name | grep ibm-elastic-operator-controller-manager-)
oc delete $esPod
echo

# Delete the common-web-ui pod
cwuiPod=$(oc get pods -o name | grep common-web-ui-)
oc delete $cwuiPod
echo

# Scale up the CP4BA operator first, so that he can create the dba-rr pods
echo "Scaling up the CP4BA operator..."
oc scale deployment ibm-cp4a-operator --replicas=1
echo



# Next, determine if this is a single-user environment (deployment size small) or a multiuser environment (deployment size medium)
replicas=1
if [[ $cp4baDeploymentProfileSize == "medium" ]]; then
  replicas=2
fi

# Scale up the platform services
echo "Scaling up platform services..."
# TODO: Needs changes when zen and common-service are properly scaled up, replicas then will be larger than 1
oc scale deployment platform-auth-service --replicas=$replicas
oc scale deployment platform-identity-provider --replicas=$replicas
oc scale deployment platform-identity-management --replicas=$replicas
authservicepodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-auth-service -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
identityproviderpodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-identity-provider -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
identitymanagementpodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-identity-management -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
RUNNINGANDREADY=false
echo -n "  Waiting..."
while [[ $RUNNINGANDREADY == false ]]
do
  if [[ $authservicepodCount < $replicas ]] || [[ $identityproviderpodCount < $replicas ]] || [[ $identitymanagementpodCount < $replicas ]]; then
    echo -n "."
    sleep 10
    authservicepodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-auth-service -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
    identityproviderpodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-identity-provider -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
    identitymanagementpodCount=$(oc get pod -l=app.kubernetes.io/instance=platform-identity-management -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
  else
    echo
    echo "  Pods platform-auth-service, platform-identity-provider and platform-identity-management are Running and Ready."
    RUNNINGANDREADY=true
  fi
done
echo



# Fix the issue with expired PostgreSQL database license key, see also https://www.ibm.com/support/pages/node/7160230
echo "Fixing issue with expired PostgreSQL database license key..."
oc annotate secret postgresql-operator-controller-manager-config  ibm-bts/skip-updates="true"
oc get job create-postgres-license-config -o yaml | sed -e 's/operator.ibm.com\/opreq-control: "true"/operator.ibm.com\/opreq-control: "false"/' -e 's|\(image: \).*|\1"cp.icr.io/cp/cpd/edb-postgres-license-provider@sha256:c1670e7dd93c1e65a6659ece644e44aa5c2150809ac1089e2fd6be37dceae4ce"|' -e '/controller-uid:/d' | oc replace --force -f - && oc wait --for=condition=complete job/create-postgres-license-config
echo



# Re-create nginx pods
echo "Re-starting nginx pods..."
nginxpods=$(oc get pod -l=app=0030-gateway --no-headers --ignore-not-found | grep nginx | awk '{print $1}')
for pod in ${nginxpods[*]}
do
  oc delete pod $pod
done
echo



# Re-create redis pods if there
rabbitmqhaPODCOUNT=$(oc get pod -l=app=rabbitmq-ha --no-headers --ignore-not-found | awk '{print $1}' | wc -l)
if [[ $rabbitmqhaPODCOUNT > 0 ]]; then
  echo "Re-starting rabbitmq-ha pods..."
  oc delete pod icp4adeploy-rabbitmq-ha-1
  oc delete pod icp4adeploy-rabbitmq-ha-0
  echo
fi



# Re-create navigator pods
echo "Re-starting navigator pods..."
navigatorpods=$(oc get pod -l=app=icp4adeploy-navigator-deploy --no-headers --ignore-not-found | awk '{print $1}')
for pod in ${navigatorpods[*]}
do
  oc delete pod $pod
done
navigatorwatcherpod=$(oc get pod -l=app.kubernetes.io/name=icp4adeploy-navigator-watcher --no-headers --ignore-not-found | awk '{print $1}')
oc delete pod $navigatorwatcherpod
echo



# BAStudio pods - first scale to 1, wait till pod -0 is Running and ready, then scale to 2
echo "Scaling up BAStudio pods to 1..."
oc scale statefulset icp4adeploy-bastudio-deployment --replicas=1
BASTUDIOPOD0COUNT=$(oc get pod -l=statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-0 -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
RUNNINGANDREADY=false
echo -n "  Waiting..."
while [[ $RUNNINGANDREADY == false ]]
do
  if [[ $BASTUDIOPOD0COUNT = 0 ]]; then
    echo -n "."
    sleep 10
    BASTUDIOPOD0COUNT=$(oc get pod -l=statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-0 -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
  else
    echo
    echo "  Pod icp4adeploy-bastudio-deployment-0 is Running and Ready."
    RUNNINGANDREADY=true
  fi
done
echo

if [[ $replicas = 2 ]]; then
  echo "Scaling up BAStudio pods to 2..."
  oc scale statefulset icp4adeploy-bastudio-deployment --replicas=2
  BASTUDIOPOD1COUNT=$(oc get pod -l=statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-1 -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
  RUNNINGANDREADY=false
  echo -n "  Waiting..."
  while [[ $RUNNINGANDREADY == false ]]
  do
    if [[ $BASTUDIOPOD1COUNT = 0 ]]; then
      echo -n "."
      sleep 10
      BASTUDIOPOD1COUNT=$(oc get pod -l=statefulset.kubernetes.io/pod-name=icp4adeploy-bastudio-deployment-1 -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
    else
      echo
      echo "  Pod icp4adeploy-bastudio-deployment-1 is Running and Ready."
      RUNNINGANDREADY=true
    fi
  done
  echo
fi



# Finally, scale up the remaining operators
echo "Scaling up the remaining operators..."
oc scale deployment ibm-zen-operator --replicas=1
oc scale deployment ibm-iam-operator --replicas=1
oc scale deployment ibm-content-operator --replicas=1
oc scale deployment ibm-ads-operator --replicas=1
oc scale deployment ibm-cp4a-wfps-operator --replicas=1
oc scale deployment ibm-dpe-operator --replicas=1
oc scale deployment ibm-odm-operator --replicas=1
oc scale deployment ibm-pfs-operator --replicas=1
# TODO: more operators to be added here?

# TODO: Think about if we want to verify, those pods are really Running and Ready. For now, we'll just wait for 30 seconds.
sleep 30
echo



# Scale up mail
echo "Switching to project mail..."
oc project mail
echo

# Update roundcubedb image url to use specified version
echo "Updating roundcubedb image URL..."
oc patch deployment roundcubedb --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image","value": "postgres:16-alpine"}]'
echo

echo "Scaling up roundcubedb pods..."
oc scale deployment roundcubedb --replicas=1
echo



# Finally, wait till pods ads-rest-api are Running and READY
echo "Switching back to project ${cp4baProjectName}..."
oc project $cp4baProjectName
echo

# Restart iaf-system-entity-operator pod, can cause trouble after a while (dba-rr pods not created as a result, therefore ads-rest-api-pods will not become ready)
echo "Re-starting iaf-system-entity-operator pods..."
iafsystementityoperatorpod=$(oc get pod -l=ibmevents.ibm.com/name=iaf-system-entity-operator --no-headers --ignore-not-found | awk '{print $1}')
oc delete pod $iafsystementityoperatorpod
echo

echo "Waiting till ads-rest-api pods are Running and READY. This can take a while..."
ADSRESTAPIPODCOUNT=$(oc get pod -l=app.kubernetes.io/name=ads-rest-api -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
RUNNINGANDREADY=false
echo -n "  Waiting..."
while [[ $RUNNINGANDREADY == false ]]
do
  if [[ $ADSRESTAPIPODCOUNT < $replicas ]]; then
    echo -n "."
    sleep 20
    ADSRESTAPIPODCOUNT=$(oc get pod -l=app.kubernetes.io/name=ads-rest-api -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | awk '{print $1}' | wc -l)
  else
    echo
    echo "  Pods ads-rest-api are Running and Ready."
    RUNNINGANDREADY=true
  fi
done
echo



# Re-start BAI Flink jobs
echo "Re-starting BAI Flink jobs..."
oc get job icp4adeploy-bai-bpmn -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | oc replace --force -f -
oc get job icp4adeploy-bai-icm -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | oc replace --force -f -
oc get job icp4adeploy-bai-content -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | oc replace --force -f -
echo



# Delete the ads-rr-registration pods in Error state
echo "Deleting ads-rr-registration pods in Error state..."
adsrrregistrationErrorPODs=$(oc get pod -l=app.kubernetes.io/name=ads-rr-registration-cronjob --no-headers --ignore-not-found | grep 'Error' | awk '{print $1}')
for pod in ${adsrrregistrationErrorPODs[*]}
do
  oc delete pod $pod
done
echo

# Re-start running but not ready pods
podsnotready=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready' --no-headers --ignore-not-found | grep 'Running' | grep 'false' | awk '{print $1}')
for podnotready in $podsnotready; do
  # Simply delete these pods
  oc delete pod $podnotready
done
echo

# Re-start navigator-watcher pod
navwatcherpod=$(oc get pod -o name | grep "cp4adeploy-navigator-watcher-")
oc delete $navwatcherpod
echo



echo "All critical components got scaled up / started. Environment is ready for final manual verification and usage. It might be that navigator is not yet working, but will become available after about 15 minutes (affects all navigator based desktops like Workplace or the Client Onboarding Desktop)."
echo
echo -e "\x1B[1mBest regards, the IBM Business Automation and Digital Labor SWAT team. \n \x1B[0m"
