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

# This script is for preparing the Backup And Restore (BAR) process, performing health check on all CP4BA components in the given namespace.
#    Only tested with CP4BA version: 21.0.3 IF034, dedicated common services set-up

# TODO: We also should check the subscritions, that they are set to manual approval. This is recommended if there are multiple CP deployments. If set to automatic approval, we might want to issue a warning, that user should set them to manual if multiple CPs are installed on this cluster.

# TODO: At the end of the script, we atm only give the number of errors found. We should extend that to list once more all warnings and errors found.

# Check if jq is installed
type jq > /dev/null 2>&1
if [ $? -eq 1 ]; then
  echo "Please install jq to continue."
  exit 1
fi

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import common utilities
source ${CUR_DIR}/common.sh

INPUT_PROPS_FILENAME="001-barParameters.sh"
INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${INPUT_PROPS_FILENAME}"

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${INPUT_PROPS_FILENAME}. Reading in variables from that script."
   
   . $INPUT_PROPS_FILENAME_FULL
   
   if [ $cp4baProjectName == "REQUIRED" ]; then
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

BACKUP_ROOT_DIRECTORY_FULL="${CUR_DIR}/${cp4baProjectName}"
if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo
else
   echo
   mkdir "$BACKUP_ROOT_DIRECTORY_FULL"
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/HealthCheck_$(date +'%Y%m%d_%H%M%S').log"
logInfo "Details will be logged to $LOG_FILE."
echo

echo -e "\x1B[1mThis script will perform the health check for CP4BA environment deployed in ${cp4baProjectName}.\n \x1B[0m"

printf "Do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
   echo
   echo -e "Checking CP4BA deployment in namespace ${cp4baProjectName}..."
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
   echo
   exit 1
fi
echo

# switch to CP4BA project
project=$(oc project --short)
logInfo "project =" $project
if [[ "$project" != "$cp4baProjectName" ]]; then
   logInfo "Switching to project ${cp4baProjectName}..."
   logInfo $(oc project $cp4baProjectName)
fi
echo

##### Operator #################################################################
# Check CP4BA operator version
logInfo "Looking for CP4BA operator..."

if oc get csv -n $cp4baProjectName|grep "ibm-cp4a-operator" > /dev/null 2>&1; then
  CP4BA_OPERATOR_NAME=$(oc get csv -o name |grep ibm-cp4a-operator)
  logInfo "  Found CP4BA operator $CP4BA_OPERATOR_NAME"
  
  CP4BA_OPERATOR_VERSION=$(oc get $CP4BA_OPERATOR_NAME -o 'jsonpath={.spec.version}')
  logInfo "  CP4BA Operator version: $CP4BA_OPERATOR_VERSION"

  CP4BA_VERSION=$(convertVersionNumber "$CP4BA_OPERATOR_VERSION")
  logInfo "  CP4BA version: $CP4BA_VERSION"
else 
  logError "  Cannot find CP4BA Operator!"
  exit 1
fi
echo

# TODO log Error if the CP4BA version is not expected

# Get CP4BA depoyment name
CP4BA_NAME=$(oc get ICP4ACluster -o name |cut -d "/" -f 2)
logInfo "CP4BA deployment name: $CP4BA_NAME"

# Save the CR to local disk
logInfo "Saving CP4BA CR to ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json..."
oc get ICP4ACluster $CP4BA_NAME -o json > ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json
echo

##### CP4BA Overall status #####################################################
# Check CP4BA deploymnet status
logInfo "Checking CP4BA Deployment overall status..."

CP4BA_DEPLOYMENT_STATUS=$(jq -r .status.conditions ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json | jq -r '.[] |select(.type == "Ready") | .status')
checkResult $CP4BA_DEPLOYMENT_STATUS "True" "CP4BA deployment status"

CP4BA_RECONCILIATION_STATUS=$(jq -r .status.conditions ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json | jq -r '.[] |select(.type == "Running") | .status')
checkResult $CP4BA_RECONCILIATION_STATUS "True" "CP4BA reconciliation running"

CP4BA_PREREQ_STATUS=$(jq -r .status.conditions ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json | jq -r '.[] |select(.type == "PrereqReady") | .status')
if [ -z $CP4BA_PREREQ_STATUS ]; then
  # sometimes there's no such value in CR
  logInfo "  CP4BA prereq ready not found"
else 
  checkResult $CP4BA_PREREQ_STATUS "True" "CP4BA prereq ready"
fi
echo

# Find what components have been installed
logInfo "Finding CP4BA components installed..."

CP4BA_COMPONENTS=$(jq -r .spec.shared_configuration.sc_deployment_patterns ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
logInfo "  CP4BA deployment patterns: $CP4BA_COMPONENTS"

CP4BA_OPTIONAL_COMPONENTS=$(jq -r .spec.shared_configuration.sc_optional_components ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
logInfo "  CP4BA optional components: $CP4BA_OPTIONAL_COMPONENTS"
echo

##### CP4BA component status ###################################################
# Prereq

logInfo "Checking Prereq..."
CP4BA_PREREQ_IAF=$(jq -r .status.components.prereq.iafStatus ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
checkResult $CP4BA_PREREQ_IAF "Ready" "CP4BA Prereq iafStatus"

CP4BA_PREREQ_IAM=$(jq -r .status.components.prereq.iamIntegrationStatus ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
checkResult $CP4BA_PREREQ_IAM "Ready" "CP4BA Prereq iamIntegrationStatus"
echo

##### Foundation pattern #######################################################
if [[ $CP4BA_COMPONENTS =~ "foundation" ]] || [[ $CP4BA_COMPONENTS =~ "workflow" ]]; then
  # RR
  logInfo "Checking Resource Registry..."
  CP4BA_RR=$(oc get ICP4ACluster $CP4BA_NAME -o 'jsonpath={.status.components.resource-registry.rrService}')
  checkResult $CP4BA_RR "Ready" "CP4BA Resource Registry Service"
  echo
  
  # Navigator
  logInfo "Checking Navigator..."
  CP4BA_NAVIGATOR_DEPLOYMENT=$(jq -r .status.components.navigator.navigatorDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_NAVIGATOR_DEPLOYMENT "Ready" "CP4BA Navigator Deployment"
  
  CP4BA_NAVIGATOR_SERVICE=$(jq -r .status.components.navigator.navigatorService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_NAVIGATOR_SERVICE "Ready" "CP4BA Navigator Service"

  CP4BA_NAVIGATOR_STORAGE=$(jq -r .status.components.navigator.navigatorStorage ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_NAVIGATOR_STORAGE "Ready" "CP4BA Navigator Storage"

  CP4BA_NAVIGATOR_ZENINTEGRATION=$(jq -r .status.components.navigator.navigatorZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_NAVIGATOR_ZENINTEGRATION "Ready" "CP4BA Navigator Zen Integration"
  echo

  # BTS
  logInfo "Checking Business Team Service.."
  CP4BA_BTS_DEPLOY_STATUS=$(oc get BusinessTeamsServices cp4ba-bts -o 'jsonpath={.status.deployStatus}')
  checkResult $CP4BA_BTS_DEPLOY_STATUS "ready" "CP4BA Business Team Deploy Status"

  CP4BA_BTS_SERVICE_STATUS=$(oc get BusinessTeamsServices cp4ba-bts -o 'jsonpath={.status.serviceStatus}')
  checkResult $CP4BA_BTS_SERVICE_STATUS "ready" "CP4BA Business Team Service Status"
  echo
  
  # BTS CNPG
  logInfo "Checking BTS Cloud Native PostgreSQL Status..."
  CP4BA_CNPG_STATUS=$(oc get Cluster ibm-bts-cnpg-${cp4baProjectName}-cp4ba-bts -o 'jsonpath={.status.conditions}'|jq -r '.[] |select(.type == "Ready") | .status')
  checkResult $CP4BA_CNPG_STATUS "True" "CP4BA Cloud Native PostgreSQL cluster ready"
  echo

  # BAS
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "bas" ]] || [[ $CP4BA_OPTIONAL_COMPONENTS =~ "baw_authoring" ]]; then
    logInfo "Checking Business Automation Studio..."
    if [[ ! $CP4BA_VERSION =~ "21.0.3" ]]; then
      # 21.0.3 doesn't have this property
      CP4BA_BAS_CAPABILITIES=$(jq -r .status.components.bastudio.capabilities ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
      logInfo "  Business Automation Studio capabilities enabled: $CP4BA_BAS_CAPABILITIES"
    fi
    CP4BA_BAS_STATUS=$(jq -r .status.components.bastudio.service ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_BAS_STATUS "Ready" "CP4BA Business Automation Studio service"
    echo
  fi

  # BAI
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "bai" ]]; then
    logInfo "Checking Business Automation Insights..."
    CP4BA_BAI_STATUS=$(jq -r .status.components.bai.bai_deploy_status ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_BAI_STATUS "Ready" "CP4BA Business Automation Insights deployment status"

    CP4BA_BAI_INSIGHTS_ENGINE_STATUS=$(jq -r .status.components.bai.insightsEngine ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_BAI_INSIGHTS_ENGINE_STATUS "Ready" "CP4BA Business Automation Insights Engine status"
    echo
  fi
fi

##### Content pattern ##########################################################
if [[ $CP4BA_COMPONENTS =~ "content" ]] || [[ $CP4BA_COMPONENTS =~ "workflow" ]]; then
  # CPE
  logInfo "Checking Content Platform Engine..."
  CP4BA_CPE_DEPLOYMENT=$(jq -r .status.components.cpe.cpeDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_CPE_DEPLOYMENT "Ready" "CP4BA Content Platform Engine Deployment"
  
  CP4BA_CPE_SERVICE=$(jq -r .status.components.cpe.cpeService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_CPE_SERVICE "Ready" "CP4BA Content Platform Engine Service"

  CP4BA_CPE_STORAGE=$(jq -r .status.components.cpe.cpeStorage ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_CPE_STORAGE "Ready" "CP4BA Content Platform Engine Storage"

  CP4BA_CPE_ZENINTEGRATION=$(jq -r .status.components.cpe.cpeZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_CPE_ZENINTEGRATION "Ready" "CP4BA Content Platform Engine Zen Integration"
  echo

  # GraphQL
  logInfo "Checking GraphQL..."
  CP4BA_GRAPHQL_DEPLOYMENT=$(jq -r .status.components.graphql.graphqlDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_GRAPHQL_DEPLOYMENT "Ready" "CP4BA GraphQL Deployment"
  
  CP4BA_GRAPHQL_SERVICE=$(jq -r .status.components.graphql.graphqlService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_GRAPHQL_SERVICE "Ready" "CP4BA GraphQL Service"

  CP4BA_GRAPHQL_STORAGE=$(jq -r .status.components.graphql.graphqlStorage ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_GRAPHQL_STORAGE "Ready" "CP4BA GraphQL Storage"
  echo

  # CSS
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "css" ]]; then
    logInfo "Checking Content Search Service..."
    CP4BA_CSS_DEPLOYMENT=$(jq -r .status.components.css.cssDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_CSS_DEPLOYMENT "Ready" "CP4BA Content Search Service Deployment"

    CP4BA_CSS_SERVICE=$(jq -r .status.components.css.cssService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_CSS_SERVICE "Ready" "CP4BA Content Search Service Service"

    CP4BA_CSS_STORAGE=$(jq -r .status.components.css.cssStorage ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_CSS_STORAGE "Ready" "CP4BA Content Search Service Storage"
    echo
  fi

  # CMIS
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "cmis" ]]; then
    logInfo "Checking CMIS..."
    CP4BA_CMIS_DEPLOYMENT=$(jq -r .status.components.cmis.cmisDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_CMIS_DEPLOYMENT "Ready" "CP4BA CMIS Deployment"

    CP4BA_CMIS_SERVICE=$(jq -r .status.components.cmis.cmisService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_CMIS_SERVICE "Ready" "CP4BA CMIS Service"

    CP4BA_CMIS_STORAGE=$(jq -r .status.components.cmis.cmisStorage ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_CMIS_STORAGE "Ready" "CP4BA CMIS Storage"

    CP4BA_CMIS_ZENINTEGRATION=$(jq -r .status.components.cmis.cmisZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_CMIS_ZENINTEGRATION "Ready" "CP4BA CMIS Zen Integration"
    echo
  fi
  
  # TM
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "tm" ]]; then
    logInfo "Checking Task Manager..."
    CP4BA_TM_DEPLOYMENT=$(jq -r .status.components.tm.tmDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_TM_DEPLOYMENT "Ready" "CP4BA Task Manager Deployment"

    CP4BA_TM_SERVICE=$(jq -r .status.components.tm.tmService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_TM_SERVICE "Ready" "CP4BA Task Manager Service"

    CP4BA_TM_STORAGE=$(jq -r .status.components.tm.tmStorage ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_TM_STORAGE "Ready" "CP4BA Task Manager Storage"
    echo
  fi
  
  # IER
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "ier" ]]; then
    logInfo "Checking IER..."
    CP4BA_IER_DEPLOYMENT=$(jq -r .status.components.ier.ierDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_IER_DEPLOYMENT "Ready" "CP4BA IER Deployment"

    CP4BA_IER_SERVICE=$(jq -r .status.components.ier.ierService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_IER_SERVICE "Ready" "CP4BA IER Service"

    CP4BA_IER_STORAGE=$(jq -r .status.components.ier.ierStorageCheck ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_IER_STORAGE "Ready" "CP4BA IER Storage Check"
    echo
  fi
  
  # ICCSAP
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "iccsap" ]]; then
    logInfo "Checking ICCSAP..."
    CP4BA_ICCSAP_DEPLOYMENT=$(jq -r .status.components.iccsap.iccsapDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ICCSAP_DEPLOYMENT "Ready" "CP4BA ICCSAP Deployment"

    CP4BA_ICCSAP_SERVICE=$(jq -r .status.components.iccsap.iccsapService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ICCSAP_SERVICE "Ready" "CP4BA ICCSAP Service"

    CP4BA_ICCSAP_STORAGE=$(jq -r .status.components.iccsap.iccsapStorageCheck ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ICCSAP_STORAGE "Ready" "CP4BA ICCSAP Storage Check"
    echo
  fi
  
  # External Share
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "extshare" ]]; then
    logInfo "Checking External Share..."
    CP4BA_EXTSHARE_DEPLOYMENT=$(jq -r .status.components.extshare.extshareDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_EXTSHARE_DEPLOYMENT "Ready" "CP4BA External Share Deployment"

    CP4BA_EXTSHARE_SERVICE=$(jq -r .status.components.extshare.extshareService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_EXTSHARE_SERVICE "Ready" "CP4BA External Share Service"

    CP4BA_EXTSHARE_STORAGE=$(jq -r .status.components.extshare.extshareStorage ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_EXTSHARE_STORAGE "Ready" "CP4BA External Share Storage"
    echo
  fi
fi

##### Application Pattern ######################################################
if [[ $CP4BA_COMPONENTS =~ "application" ]]; then
  # Application Engine
  # TODO there may have more than 1 appengine
  logInfo "Checking application engine..."
  CP4BA_APPENGINE_COUNT=$(oc get ICP4ACluster $CP4BA_NAME -o 'jsonpath={.status.components.app-engine.instance_count}')
  logInfo "  Application Engine instance count: $CP4BA_APPENGINE_COUNT"

  CP4BA_APPENGINE_SERVICE=$(oc get ICP4ACluster $CP4BA_NAME -o "jsonpath={.status.components.ae-"$CP4BA_NAME"-workspace-aae.service}")
  checkResult $CP4BA_APPENGINE_SERVICE "Ready" "CP4BA Application Engine service"
  echo

  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "app_designer" ]]; then
    logInfo "Checking Application Engine Playback Server..."
    CP4BA_PLAYBACK_SERVICE=$(oc get ICP4ACluster $CP4BA_NAME -o "jsonpath={.status.components.ae-"$CP4BA_NAME"-pbk.service}")
    checkResult $CP4BA_PLAYBACK_SERVICE "Ready" "CP4BA Application Engine Playback Server service"
    echo
  fi
fi

##### decision_ads Pattern #####################################################
if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "ads_runtime" ]]; then
  logInfo "Checking Automation Decision Service runtime service..."
  CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT=$(jq -r .status.components.adsRuntimeService.adsRuntimeServiceDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT "Ready" "CP4BA Automation Decision Service deployment status"

  CP4BA_ADS_RUNTIME_SERVICE_SERVICE=$(jq -r .status.components.adsRuntimeService.adsRuntimeServiceService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_ADS_RUNTIME_SERVICE_SERVICE "Ready" "CP4BA Automation Decision Service runtime service status"

  CP4BA_ADS_RUNTIME_SERVICE_ZENINTEGRATION=$(jq -r .status.components.adsRuntimeService.adsRuntimeServiceZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_ADS_RUNTIME_SERVICE_ZENINTEGRATION "Ready" "CP4BA Automation Decision Service Zen integration status"

  logInfo "Checking Automation Decision Service Rest-API..."
  CP4BA_ADS_REST_APU_DEPLOYMENT=$(jq -r .status.components.adsRestApi.adsRestApiDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_ADS_REST_APU_DEPLOYMENT "Ready" "CP4BA Automation Decision Service Rest-API deployment status"

  CP4BA_ADS_REST_API_SERVICE=$(jq -r .status.components.adsRestApi.adsRestApiService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_ADS_REST_API_SERVICE "Ready" "CP4BA Automation Decision Service Rest-API service status"

  CP4BA_ADS_REST_API_ZENINTEGRATION=$(jq -r .status.components.adsRestApi.adsRestApiZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_ADS_REST_API_ZENINTEGRATION "Ready" "CP4BA Automation Decision Service Rest-API Zen integration status"
  
  #TODO is it necessary to check other ADS services ? They change every release.
fi


##### Decision Pattern #########################################################
if [[ ${CP4BA_COMPONENTS/decisions_ads/} =~ "decisions" ]]; then
  logInfo "Checking Operational Decision Manager.."

  # Decision Center
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "decisionCenter" ]]; then
    logInfo "Checking Decision Center..."
    CP4BA_ODM_DECISION_CENTER_SERVICE=$(jq -r .status.components.odm.odmDecisionCenterService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_CENTER_SERVICE "Ready" "CP4BA Operational Decision Manager Decision Center service status"

    CP4BA_ODM_DECISION_CENTER_DEPLOYMENT=$(jq -r .status.components.odm.odmDecisionCenterDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_CENTER_DEPLOYMENT "Ready" "CP4BA Operational Decision Manager Decision Center deployment status"

    CP4BA_ODM_DECISION_CENTER_ZENINTEGRATION=$(jq -r .status.components.odm.odmDecisionCenterZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_CENTER_ZENINTEGRATION "Ready" "CP4BA Operational Decision Manager Decision Center Zen integration status"
  fi

  # Decision Runner
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "decisionRunner" ]]; then
    logInfo "Checking Decision Runner..."
    CP4BA_ODM_DECISION_RUNNER_SERVICE=$(jq -r .status.components.odm.odmDecisionRunnerService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_RUNNER_SERVICE "Ready" "CP4BA Operational Decision Manager Decision Runner service status"

    CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT=$(jq -r .status.components.odm.odmDecisionRunnerDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT "Ready" "CP4BA Operational Decision Manager Decision Runner deployment status"

    CP4BA_ODM_DECISION_RUNNER_ZENINTEGRATION=$(jq -r .status.components.odm.odmDecisionRunnerZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_RUNNER_ZENINTEGRATION "Ready" "CP4BA Operational Decision Manager Decision Runner Zen integration status"
  fi

  # Decision Server Runtime and Decision Server Console
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "decisionServerRuntime" ]]; then
    logInfo "Checking Decision Server Runtime..."
    CP4BA_ODM_DECISION_SERVER_RUNTIME_SERVICE=$(jq -r .status.components.odm.odmDecisionServerRuntimeService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_SERVER_RUNTIME_SERVICE "Ready" "CP4BA Operational Decision Manager Decision Server Runtime service status"

    CP4BA_ODM_DECISION_SERVER_RUNTIME_DEPLOYMENT=$(jq -r .status.components.odm.odmDecisionServerRuntimeDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_SERVER_RUNTIME_DEPLOYMENT "Ready" "CP4BA Operational Decision Manager Decision Server Runtime deployment status"

    CP4BA_ODM_DECISION_SERVER_RUNTIME_ZENINTEGRATION=$(jq -r .status.components.odm.odmDecisionServerRuntimeZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_SERVER_RUNTIME_ZENINTEGRATION "Ready" "CP4BA Operational Decision Manager Decision Server Runtime Zen integration status"
    
    logInfo "Checking Decision Server Runtime..."
    CP4BA_ODM_DECISION_SERVER_CONSOLE_SERVICE=$(jq -r .status.components.odm.odmDecisionServerConsoleService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_SERVER_CONSOLE_SERVICE "Ready" "CP4BA Operational Decision Manager Decision Server Console service status"

    CP4BA_ODM_DECISION_SERVER_CONSOLE_DEPLOYMENT=$(jq -r .status.components.odm.odmDecisionServerConsoleDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_SERVER_CONSOLE_DEPLOYMENT "Ready" "CP4BA Operational Decision Manager Decision Server Console deployment status"

    CP4BA_ODM_DECISION_SERVER_CONSOLE_ZENINTEGRATION=$(jq -r .status.components.odm.odmDecisionServerConsoleZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ODM_DECISION_SERVER_CONSOLE_ZENINTEGRATION "Ready" "CP4BA Operational Decision Manager Decision Server Console Zen integration status"
  fi
fi

##### Workflow Pattern #########################################################
if [[ $CP4BA_COMPONENTS =~ "workflow" ]]; then
  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "baw_authoring" ]]; then
    #Workflow Authoring, only for 21.0.3
    if [[ $CP4BA_VERSION =~ "21.0.3" ]]; then
      logInfo "Checking Business Automation Workflow Authoring..."
      CP4BA_BAW_AUTHORING_SERVICE=$(oc get ICP4ACluster $CP4BA_NAME -o 'jsonpath={.status.components.workflow-authoring.service}')
      checkResult $CP4BA_BAW_AUTHORING_SERVICE "Ready" "CP4BA Business Automation Workflow Authoring service status"
      echo
    fi
 else
    logInfo "Checking Business Automation Workflow Runtime..."
    # BAW may have 1 or more instances.
    CP4BA_BAW_TYPE=$(jq -r .status.components.baw ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json | jq 'type')
    if [[ "$CP4BA_BAW_TYPE" == "object" ]]; then
      # only 1 baw instance
        CP4BA_BAW_DEPLOYMENT=$(jq -r .status.components.baw.bawDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
        checkResult $CP4BA_BAW_DEPLOYMENT "Ready" "CP4BA Business Automation Workflow Runtime deployment status"

        CP4BA_BAW_SERVICE=$(jq -r .status.components.baw.bawService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
        checkResult $CP4BA_BAW_SERVICE "Ready" "CP4BA Business Automation Workflow Runtime service status"

        CP4BA_BAW_ZENINTEGRATION=$(jq -r .status.components.baw.bawZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
        checkResult $CP4BA_BAW_ZENINTEGRATION "Ready" "CP4BA Business Automation Workflow Runtime Zen Integration status"
        echo
    else
      # check how many instances
      CP4BA_BAW_INSTANCE_COUNT=$(jq -r .status.components.baw ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json | jq 'length')
      echo
      for ((i=0; i<$CP4BA_BAW_INSTANCE_COUNT; i++)); do
        CP4BA_BAW_NAME=$(jq -r .status.components.baw[$i].name ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
        logInfo "  Business Automation Workflow Runtime instance name: $CP4BA_BAW_NAME"

        CP4BA_BAW_DEPLOYMENT=$(jq -r .status.components.baw[$i].bawDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
        checkResult $CP4BA_BAW_DEPLOYMENT "Ready" "CP4BA Business Automation Workflow Runtime deployment status"

        CP4BA_BAW_SERVICE=$(jq -r .status.components.baw[$i].bawService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
        checkResult $CP4BA_BAW_SERVICE "Ready" "CP4BA Business Automation Workflow Runtime service status"

        CP4BA_BAW_ZENINTEGRATION=$(jq -r .status.components.baw[$i].bawZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
        checkResult $CP4BA_BAW_ZENINTEGRATION "Ready" "CP4BA Business Automation Workflow Runtime Zen Integration status"
        echo
      done
    fi
  fi

#TODO is it necessary to check BAML ?
fi

##### Document Processing Pattern ##############################################
if [[ $CP4BA_COMPONENTS =~ "document_processing" ]]; then
  logInfo "Checking Automation Document Processing..."
  CP4BA_ADP_DEPLOYMENT=$(jq -r .status.components.ca.caDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_ADP_DEPLOYMENT "Successful" "CP4BA Automation Document Processing deployment status"

  CP4BA_ADP_SERVICE=$(jq -r .status.components.ca.caService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_ADP_SERVICE "Ready" "CP4BA Automation Document Processing service status"

  CP4BA_ADP_ZEN_REGISTRATION=$(jq -r .status.components.ca.caZenRegistration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
  checkResult $CP4BA_ADP_ZEN_REGISTRATION "Ready" "CP4BA Automation Document Processing Zen registration status"

  if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "document_processing_designer" ]]; then
    # CDS
    logInfo "Checking Automation Document Processing Designer..."
    CP4BA_ADP_CDS_DEPLOYMENT=$(jq -r .status.components.contentDesignerService.cdsDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ADP_CDS_DEPLOYMENT "Ready" "CP4BA Automation Document Processing Designer deployment status"

    CP4BA_ADP_CDS_SERVICE=$(jq -r .status.components.contentDesignerService.cdsService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ADP_CDS_DEPLOYMENT "Ready" "CP4BA Automation Document Processing Designer service status"

    CP4BA_ADP_CDS_ZENINTEGRATION=$(jq -r .status.components.contentDesignerService.cdsZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ADP_CDS_ZENINTEGRATION "Ready" "CP4BA Automation Document Processing Designer Zen integration status"

    #CDRA
    logInfo "Checking Automation Document Processing Content Designer REPO API..."
    CP4BA_ADP_CDRA_DEPLOYMENT=$(jq -r .status.components.contentDesignerRepoAPI.cdraDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ADP_CDRA_DEPLOYMENT "Ready" "CP4BA Automation Document Processing Content Designer Repo API deployment status"

    CP4BA_ADP_CDRA_SERVICE=$(jq -r .status.components.contentDesignerRepoAPI.cdraService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ADP_CDRA_SERVICE "Ready" "CP4BA Automation Document Processing Content Designer Repo API service status"

    CP4BA_ADP_CDRA_ZENINTEGRATION=$(jq -r .status.components.contentDesignerRepoAPI.cdraZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_ADP_CDRA_ZENINTEGRATION "Ready" "CP4BA Automation Document Processing Content Designer Repo API Zen integration status"
  fi
fi

##### Process Federation Server ################################################
if [[ $CP4BA_OPTIONAL_COMPONENTS =~ "pfs" ]]; then
  if [[ $CP4BA_VERSION =~ "21.0.3" ]]; then
    # only check PFS on 21.0.3
    logInfo "Checking Process Federation Server..."
    CP4BA_PFS_DEPLOYMENT=$(jq -r .status.components.pfs.pfsDeployment ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_PFS_DEPLOYMENT "Ready" "CP4BA Process Federation Server deployment status"

    CP4BA_PFS_SERVICE=$(jq -r .status.components.pfs.pfsService ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_PFS_SERVICE "Ready" "CP4BA Process Federation Server service status"

    CP4BA_PFS_ZENINTEGRATION=$(jq -r .status.components.pfs.pfsZenIntegration ${BACKUP_ROOT_DIRECTORY_FULL}/CR.json)
    checkResult $CP4BA_PFS_ZENINTEGRATION "Ready" "CP4BA Process Federation Server Zen integration status"
  fi
fi

##### Elastic Search / Open Search #############################################
#TODO is it always installed ?
if [[ $CP4BA_VERSION =~ "24.0" ]]; then
  # OpenSearch for 24.0 and later
  logInfo "Trying to connect to OpenSearch..."
  OPENSEARCH_ROUTE=$(oc get route opensearch-route -o jsonpath='{.spec.host}')
  OPENSEARCH_PASSWORD=$(oc get secret opensearch-ibm-elasticsearch-cred-secret --no-headers --ignore-not-found -o jsonpath={.data.elastic} | base64 -d)
  OPENSEARCH_CURL_RESULT=$(curl -sk -w "%{http_code}" -o /dev/null -u elastic:$OPENSEARCH_PASSWORD https://$OPENSEARCH_ROUTE)
  checkHTTPCode $OPENSEARCH_CURL_RESULT "200" $OPENSEARCH_ROUTE
  echo
else
  # ElasticSearch
  logInfo "Trying to connect to ElasticSearch..."
  ELASTICSEARCH_ROUTE=$(oc get route iaf-system-es -o jsonpath='{.spec.host}')
  ELASTICSEARCH_PASSWORD=$(oc get secret iaf-system-elasticsearch-es-default-user --no-headers --ignore-not-found -o jsonpath={.data.password} | base64 -d)
  ELASTICSEARCH_CURL_RESULT=$(curl -sk -w "%{http_code}" -o /dev/null -u elasticsearch-admin:$ELASTICSEARCH_PASSWORD https://$ELASTICSEARCH_ROUTE)
  checkHTTPCode $ELASTICSEARCH_CURL_RESULT "200" $ELASTICSEARCH_ROUTE
  echo
fi


##### Zen Resources ############################################################
if [[ $CP4BA_VERSION =~ "21.0.3" ]]; then
  logInfo "Checking Automation UIConfig..."
  ZEN_AUTOMATIONUICONFIG_STATUS=$(oc get AutomationUIConfig iaf-system -o jsonpath='{.status.conditions}'|jq -r '.[] |select(.type == "Ready") | .status')
  checkResult $ZEN_AUTOMATIONUICONFIG_STATUS "True" "Automation UIConfig iaf-system status"
  echo

  logInfo "Checking Cartridge..."
  ZEN_CARTRIDGE_READY=$(oc get Cartridge icp4ba -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "Ready") | .status')
  checkResult $ZEN_CARTRIDGE_READY "True" "Cartridge icp4ba ready"

  ZEN_CARTRIDGE_BEDROCK_READY=$(oc get Cartridge icp4ba -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "BedrockReady") | .status')
  checkResult $ZEN_CARTRIDGE_BEDROCK_READY "True" "Cartridge icp4ba bedrock ready"

  ZEN_CARTRIDGE_ZENREADY=$(oc get Cartridge icp4ba -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "ZenReady") | .status')
  checkResult $ZEN_CARTRIDGE_ZENREADY "True" "Cartridge icp4ba zenready"
  echo

  logInfo "Checking AutomationBase..."
  ZEN_AUTOMATIONBASE_READY=$(oc get AutomationBase foundation-iaf -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "Ready") |.status')
  checkResult $ZEN_AUTOMATIONBASE_READY "True" "AutomationBase foundation-iaf ready"

  ZEN_AUTOMATIONBASE_CS_READY=$(oc get AutomationBase foundation-iaf -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "CommonServicesReady") |.status')
  checkResult $ZEN_AUTOMATIONBASE_CS_READY "True" "AutomationBase foundation-iaf CommonService ready"

  ZEN_AUTOMATIONBASE_KAFKA_READY=$(oc get AutomationBase foundation-iaf -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "KafkaReady") |.status')
  checkResult $ZEN_AUTOMATIONBASE_KAFKA_READY "True" "AutomationBase foundation-iaf Kafka ready"

  ZEN_AUTOMATIONBASE_ELASTIC_READY=$(oc get AutomationBase foundation-iaf -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "ElasticReady") |.status')
  checkResult $ZEN_AUTOMATIONBASE_ELASTIC_READY "True" "AutomationBase foundation-iaf Elastic ready"

  ZEN_AUTOMATIONBASE_APICURIO_READY=$(oc get AutomationBase foundation-iaf -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "ApicurioReady") |.status')
  checkResult $ZEN_AUTOMATIONBASE_APICURIO_READY "True" "AutomationBase foundation-iaf Apicurio ready"
  echo

  logInfo "Checking CartridgeRequirement insights-engine..."
  ZEN_CARTRIDGEREQUIREMENT_INSIGHTSENGINE_READY=$(oc get CartridgeRequirements insights-engine -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "Ready") |.status')
  checkResult $ZEN_CARTRIDGEREQUIREMENT_INSIGHTSENGINE_READY "True" "CartridgeRequirement insights-engine ready"

  ZEN_CARTRIDGEREQUIREMENT_INSIGHTSENGINE_ELASTICUSER=$(oc get CartridgeRequirements insights-engine -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "ElasticUserReady") |.status')
  checkResult $ZEN_CARTRIDGEREQUIREMENT_INSIGHTSENGINE_ELASTICUSER "True" "CartridgeRequirement insights-engine elastic user ready"

  ZEN_CARTRIDGEREQUIREMENT_INSIGHTSENGINE_KAFKAUSER=$(oc get CartridgeRequirements insights-engine -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "KafkaUserReady") |.status')
  checkResult $ZEN_CARTRIDGEREQUIREMENT_INSIGHTSENGINE_KAFKAUSER "True" "CartridgeRequirement insights-engine kafka user ready"
  echo

  logInfo "Checking CartridgeRequirement icp4ba..."
  ZEN_CARTRIDGEREQUIREMENT_ICP4BA_READY=$(oc get CartridgeRequirements icp4ba -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "Ready") |.status')
  checkResult $ZEN_CARTRIDGEREQUIREMENT_ICP4BA_READY "True" "CartridgeRequirement icp4ba ready"

  ZEN_CARTRIDGEREQUIREMENT_ICP4BA_ELASTICUSER=$(oc get CartridgeRequirements icp4ba -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "ElasticUserReady") |.status')
  checkResult $ZEN_CARTRIDGEREQUIREMENT_ICP4BA_ELASTICUSER "True" "CartridgeRequirement icp4ba elastic user ready"

  ZEN_CARTRIDGEREQUIREMENT_ICP4BA_KAFKAUSER=$(oc get CartridgeRequirements icp4ba -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "KafkaUserReady") |.status')
  checkResult $ZEN_CARTRIDGEREQUIREMENT_ICP4BA_KAFKAUSER "True" "CartridgeRequirement icp4ba kafka user ready"
  echo
fi

# only check ZenService for 24.0
if [[ $CP4BA_VERSION =~ "24.0" ]]; then
  logInfo "Checking ZenService..."
  ZENSERVICE_STATUS=$(oc get ZenService iaf-zen-cpdservice -o jsonpath='{.status.zenStatus}')
  checkResult $ZENSERVICE_STATUS "Completed" "ZenService iaf-zen-cpdservice status"

  ZENSERVICE_PROGRESS=$(oc get ZenService iaf-zen-cpdservice -o jsonpath='{.status.Progress}')
  checkResult $ZENSERVICE_PROGRESS "100%" "ZenService iaf-zen-cpdservice progress"
fi


##### Kafka ####################################################################
logInfo "Checking Kafka..."
KAFKA_STATUS=$(oc get kafka.ibmevents.ibm.com iaf-system -o jsonpath='{.status.conditions}' | jq -r '.[] |select(.type == "Ready") |.status')
checkResult $KAFKA_STATUS "True" "Kafka ready"
echo

##### Flink ####################################################################
if oc get FlinkDeployment $CP4BA_NAME"-insights-engine-flink" > /dev/null 2>&1; then
  # 24.0
  logInfo "Checking Flink Deployment..."
  FLINK_JOBS_TATUS=$(oc get FlinkDeployment $CP4BA_NAME"-insights-engine-flink" -o 'jsonpath={.status.jobManagerDeploymentStatus}')
  checkResult $FLINK_JOBS_TATUS "READY" "Flink Job Manager Deployment Status"

  FLINK_LIFECYCLE_STATE=$(oc get FlinkDeployment $CP4BA_NAME"-insights-engine-flink" -o 'jsonpath={.status.lifecycleState}')
  checkResult $FLINK_LIFECYCLE_STATE "STABLE" "Flink Lifecycle Status"

  FLINK_RECONCILE_STATE=$(oc get FlinkDeployment $CP4BA_NAME"-insights-engine-flink" -o 'jsonpath={.status.reconciliationStatus.state}')
  checkResult $FLINK_RECONCILE_STATE "DEPLOYED" "Flink Reconcile State"
fi

if oc get FlinkCluster > /dev/null 2>&1; then
  # 21.0.3
  FLINK_CLUSTER_NAME=$(oc get FlinkCluster --no-headers |awk {'print $1'})
  logInfo "Checking Flink Cluster $FLINK_CLUSTER_NAME..."
  FLINK_CLUSTER_TATUS=$(oc get FlinkCluster $FLINK_CLUSTER_NAME -o 'jsonpath={.status.state}')
  checkResult $FLINK_CLUSTER_TATUS "Running" "Flink Cluster Status"
fi

# Insights Engine
if oc get insightsengine > /dev/null 2>&1; then
  INSIGHTS_ENGINE=$(oc get insightsengine --no-headers | awk {'print $1'})
  MANAGEMENT_URL=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].uri}')
  logInfo "  Insights Engine $INSIGHTS_ENGINE Management: $MANAGEMENT_URL"
  MANAGEMENT_AUTH_SECRET=$(oc get insightsengine $INSIGHTS_ENGINE -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].authentication.secret.secretName}')
  MANAGEMENT_USERNAME=$(oc get secret ${MANAGEMENT_AUTH_SECRET} -o jsonpath='{.data.username}' | base64 -d)
  MANAGEMENT_PASSWORD=$(oc get secret ${MANAGEMENT_AUTH_SECRET} -o jsonpath='{.data.password}' | base64 -d)
  logInfo "  Retrieving flink jobs..."
  FLINK_JOBS=$(curl -sk -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} $MANAGEMENT_URL/api/v1/processing/jobs/list)
  FLINK_JOBS_COUNT=$(echo $FLINK_JOBS |jq '.jobs' | jq 'length')
  if [[ $FLINK_JOBS_COUNT == "0" ]]; then {
    logError "    No flink jobs are running, please check !!"
  } else
      for ((i=0; i<$FLINK_JOBS_COUNT; i++)); do
      FLINK_JOB_ID=$(echo $FLINK_JOBS | jq ".jobs[$i].jid")
      FLINK_JOB_NAME=$(echo $FLINK_JOBS | jq ".jobs[$i].name")
      FLINK_JOB_STATE=$(echo $FLINK_JOBS | jq ".jobs[$i].state")
      logInfo "    FLINK JOB ID: $FLINK_JOB_ID, Name: $FLINK_JOB_NAME, State: $FLINK_JOB_STATE"
    done
  fi
fi


##### OCP jobs #################################################################

##### OCP Node #################################################################


##### FileNet health ###########################################################
#TODO ping page?


##### Workflow health ##########################################################
#TODO check portal, case client connection ?

##### ODM health ###############################################################


##### ADS health ###############################################################


##### BAI health ###############################################################


##### Navigator health #########################################################


##### ADP health ###############################################################


##### Pod health ###############################################################
logInfo "Checking Pod Health..."
# logInfo $(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready' --no-headers --ignore-not-found)

# Pending verified
podsinpending=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase' --no-headers --ignore-not-found | grep 'Pending' | awk '{print $1}')
if [[ $podsinpending != "" ]]; then
  logError "Pending pods found:" $podsinpending
fi

# Terminating
podsinterminating=$(oc get pod | grep 'Terminating' | awk '{print $1}')
if [[ $podsinterminating != "" ]]; then
  logError "Terminating pods found:" $podsinterminating
fi

# CrashLoopBackOff verified
podsincrashloopbackoff=$(oc get pod --no-headers --ignore-not-found | grep 'CrashLoopBackOff' | awk '{print $1}')
if [[ $podsincrashloopbackoff != "" ]]; then
  logError "CrashLoopBackOff pods found:" $podsincrashloopbackoff
fi

# Failed
podsinfailed=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase' --no-headers --ignore-not-found | grep 'Error' | awk '{print $1}')
if [[ $podsinfailed != "" ]]; then
  logError "Failed pods found:" $podsinfailed
fi

# Unknown
podsinunknown=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase' --no-headers --ignore-not-found | grep 'Unknown' | awk '{print $1}')
if [[ $podsinunknown != "" ]]; then
  logError "Unknown pods found:" $podsinunknown
fi

# Running but not Ready verified
podsnotready=$(oc get pod -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready' --no-headers --ignore-not-found | grep 'Running' | grep 'false' | awk '{print $1}')
if [[ $podsnotready != "" ]]; then
  logError "Non-Ready pods found:" $podsnotready
fi
echo



ERROR_COUNT=$(grep ERROR $LOG_FILE | wc -l)
if [ $ERROR_COUNT -ne 0 ]; then
  logError "Found $ERROR_COUNT error(s), please check the log for details !!"
else
  logInfo "No errors found."
fi
echo
