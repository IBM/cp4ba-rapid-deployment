#! /bin/sh -e 
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

## Load configuration parameters
. ./config.sh

## Start banner
echo
echo Starting configuration of Monitoring Stack...

## Verify if cluster-monitoring-config ConfigMap object exists
## This is a little obscrue but since we are using the -e flag in this script grep will abort the script if it cannot find what it is looking for. 
## The || true will prevent that from happening. 
echo
echo Checking for conflicts with ConfigMap cluster-monitoring-config 
COUNT=$(oc -n openshift-monitoring get configmap cluster-monitoring-config 2>/dev/null | grep -c config || true ) 

if [ $COUNT -ne 0 ]
then
	echo Warning: ConfigMap cluster-monitoring-config already exists in cluster.  Creating copy. 
	oc -n openshift-monitoring get configmap cluster-monitoring-config -o yaml > cluster-monitoring-config.yaml.bak
else
	echo Conflicts with existing cluster-monitoring-config ConfigMap not detected. 
fi


## Get cluster monitoring configuration from template and replace parameters
cp cluster-monitoring-config.template.yaml cluster-monitoring-config.yaml
sed -i.bak "s|paramClusterName|$paramClusterName|g" cluster-monitoring-config.yaml 


## Apply the configuration to create the ConfigMap object. This will enable user defined project monitoring.
echo
echo Applying templated cluster-monitoring-config ConfigMap
oc apply -f cluster-monitoring-config.yaml


## Verify if user-workload-monitoring-config ConfigMap object exists 
echo
echo Checking for conflicts with ConfigMap user-workload-monitoring-config
COUNT=$(oc -n openshift-user-workload-monitoring get configmap user-workload-monitoring-config 2>/dev/null |  grep -c config || true )
if [ $COUNT -ne 0 ]
then
        echo Warning: ConfigMap openshift-user-workload-monitoring already exists in cluster.  Creating copy.
        oc -n openshift-user-workload-monitoring get configmap user-workload-monitoring-config -o yaml > user-workload-monitoring-config.yaml.bak
else
        echo Conflicts with existing openshift-user-workload-monitoring ConfigMap not detected. 
fi


## Get user level monitoring configuration from template and replace parameters
cp user-workload-monitoring-config.template.yaml user-workload-monitoring-config.yaml 
sed -i.bak "s|paramClusterName|$paramClusterName|g" user-workload-monitoring-config.yaml

## Apply the configuration to create the ConfigMap object. 
echo
echo Applying templated user-workload-monitoring-config ConfigMap 
oc apply -f user-workload-monitoring-config.yaml


## Get AlertManager configuration template
if $configureSlackReceiver 
then
	cp alertmanager.template.yaml alertmanager.yaml
else
	cp alertmanager.noslack.template.yaml alertmanager.yaml
fi

## Update parameters
sed -i.bak "s|paramClusterName|$paramClusterName|g" alertmanager.yaml
sed -i.bak "s|paramDefaultReceiver|$paramDefaultReceiver|g" alertmanager.yaml
sed -i.bak "s|paramRepeatInterval|$paramRepeatInterval|g" alertmanager.yaml

if $configureSlackReceiver
then
	sed -i.bak "s|paramSlackApiUrlPlatform|$paramSlackApiUrlPlatform|g" alertmanager.yaml
	sed -i.bak "s|paramSlackApiUrlJAM|$paramSlackApiUrlJAM|g" alertmanager.yaml
	sed -i.bak "s|paramUseChannelHandler|$paramUseChannelHandler|g" alertmanager.yaml
fi


## Apply new AlertManager  configuration
echo
echo Applying configuration to AlertManager
oc -n openshift-monitoring create secret generic alertmanager-main --from-file=alertmanager.yaml --dry-run=true -o=yaml |  oc -n openshift-monitoring replace secret --filename=-


## Deploy project specific alert rules for namespaces defined in config.sh
echo
echo Deploy custom alert rules for projects
for namespace in $cp4baNamespace $otherNamespaces
do
        echo "Defining custom alerts for project $namespace"
        mkdir -p alerts/$namespace

        # Parse alert rule template and deploy each rule in project
        for alertFile in $(ls ./alert-templates)
        do
                # Get basename of alert rule template and create yaml file based on it
                BASENAME=$(echo $alertFile | cut -d "." -f1 )
                cp ./alert-templates/$alertFile ./alerts/$namespace/${BASENAME}.yaml
                sed -i.bak "s|paramNamespace|$namespace|g" ./alerts/$namespace/${BASENAME}.yaml
                sed -i.bak "s|paramClusterName|$paramClusterName|g" ./alerts/$namespace/${BASENAME}.yaml
                oc apply -f ./alerts/$namespace/${BASENAME}.yaml
        done
done

## We are going to remove custom silences that we may have created before
## We look for silences where the label is group=cp4basetup
## For that, we are going to use the amtool in the AlertManager's POD
# Name of Alert Manager POD where amtool resides 
ALERT_MANAGER_POD=alertmanager-main-0
# URL internal to the POD that will be used to communicate with AlertManager
ALERT_MANAGER_IN_POD_URL=http://localhost:9093
# Command to find silences
AM_TOOL_QUERY="amtool --alertmanager.url ${ALERT_MANAGER_IN_POD_URL} silence query group=cp4basetup" 
AM_TOOL_REMOVE="amtool --alertmanager.url ${ALERT_MANAGER_IN_POD_URL} silence expire"

# Disabling silences that may had been configured before 
echo
echo Looking for silences configured previously by this script
for id in $(oc exec $ALERT_MANAGER_POD -n openshift-monitoring -c alertmanager -i -- $AM_TOOL_QUERY | grep -v ^ID | cut -d " " -f1)
do
	echo Disabling silence with id $id 
	oc exec $ALERT_MANAGER_POD -n openshift-monitoring -c alertmanager -i -- $AM_TOOL_REMOVE $id
done

## Deploy custom silences.  We are silencing some alerts that are not important for us at the moment. 
YEAR=$(date +%Y)
TARGET_YEAR=$(( $YEAR + $silencePeriodInYears ))
MONTH=$(date +%m)
DAY=$(date +%d)
USER=$(oc whoami)
AM_TOOL_IMPORT="amtool --alertmanager.url ${ALERT_MANAGER_IN_POD_URL} silence import"

# Parse silence file and deploy silence rules
echo
echo Deploy custom silence rules
mkdir -p silence
for silenceFile in $(ls ./silence-templates)
do
	# Get basename of silence file and create json file based on it 
	BASENAME=$(echo $silenceFile | cut -d "." -f1 )
	cp ./silence-templates/$silenceFile ./silence/${BASENAME}.json
	sed -i.bak "s|paramYear|$YEAR|g" ./silence/${BASENAME}.json
	sed -i.bak "s|paramMonth|$MONTH|g" ./silence/${BASENAME}.json
	sed -i.bak "s|paramDay|$DAY|g" ./silence/${BASENAME}.json
	sed -i.bak "s|paramCreatedBy|$USER|g" ./silence/${BASENAME}.json
	sed -i.bak "s|paramTargetYear|$TARGET_YEAR|g" ./silence/${BASENAME}.json

	# Use the amtool command installed on one of the AlertManager PODs to configure the silence 
	# The silence configuration is passed via the stdin into the amtool silence import command 
	cat ./silence/${BASENAME}.json | oc exec $ALERT_MANAGER_POD -n openshift-monitoring -c alertmanager -i -- $AM_TOOL_IMPORT
done

## Configure ServiceMonitors for predefined components 
## ServiceMonitors allows Prometheus to scrape metrics from our CloudPak components 
echo
echo Deploy custom service monitors
mkdir -p monitors
for namespace in $cp4baNamespace
do
        echo "Defining custom Service Monitors for project $namespace"
        mkdir -p monitors/$namespace
	for monitorFile in $(ls ./monitor-templates)
	do
        	# Get basename of ServiceMonitor file and create yaml file based on it
        	BASENAME=$(echo $monitorFile | cut -d "." -f1 )	
		cp ./monitor-templates/$monitorFile ./monitors/$namespace/${BASENAME}.yaml
		sed -i.bak "s|paramNamespace|$namespace|g" ./monitors/$namespace/${BASENAME}.yaml	
		oc apply -f ./monitors/$namespace/${BASENAME}.yaml		
	done
done

# If we got to this point things have been configured properly.
echo
echo "*********************************************************************************"
echo "*********           Monitoring Stack configured successfully!           *********"
echo "*********************************************************************************"
