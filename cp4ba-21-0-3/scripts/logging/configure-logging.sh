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

## Load default configuration values
. ./config.sh 

## Initial banner
echo
echo Installing and configuring Logging Stack...

## Create Namespace for the Elasticsearch Operator.
echo
echo Creating Namespace for the Elasticsearch Operator
cp eo-namespace.template.yaml eo-namespace.yaml
oc apply -f eo-namespace.yaml

## Create Namespace for the Cluster Logging Operator
echo
echo Creating Namespace for the Cluster Logging Operator
cp clo-namespace.template.yaml clo-namespace.yaml
oc apply -f clo-namespace.yaml


## Create Operator Group object 
echo
echo Creating Operator Group object for Elasticsearch Operator
cp  eo-operatorgroup.template.yaml  eo-operatorgroup.yaml
oc apply -f eo-operatorgroup.yaml 

## Create Subscription object 
echo
echo Creating Subscription object for Elasticsearch Operator
cp eo-subscription.template.yaml eo-subscription.yaml
oc apply -f eo-subscription.yaml


## Create Operator Group object 
echo
echo Creating Create an Operator Group for Cluster Logging Operator 
cp clo-operatorgroup.template.yaml clo-operatorgroup.yaml
oc apply -f clo-operatorgroup.yaml 


## Create Subscription object
echo
echo Creating Subscription object for Cluster Logging Operator
cp clo-subscription.template.yaml clo-subscription.yaml
oc apply -f clo-subscription.yaml


## Wait for cluster resource definition to be created before continuing
WAIT_TIME=10
TRIES=0
# the next line is a little obscure but basically we are storing the number of instances found by grep.
# zero means it could not find anything. Not finding anything means the custom resource has not been defined by the operator
# just yet. Using || true after the grep command ensures that the script will not exit 
# since we are using -e flag and grep returns a non zero return code if the string we are greping for is not found.
CRD=$(oc get crd | grep -c clusterloggings || true)

echo
echo Waiting up to five minutes for CRD clusterloggings.logging.openshift.io to be available
date

while [ $CRD -eq 0 ] && [ $TRIES -lt 30 ]
do
        sleep $WAIT_TIME
        TRIES=$(( $TRIES + 1 ))
        CRD=$(oc get crd | grep -c clusterloggings || true )
done

if [ $CRD -eq 0 ] 
then
        echo Could not find custom resource clusterloggings.logging.openshift.io. Please check the state of the ClusterLogging operator.
        exit 1

else
        echo Found custom resource clusterloggings.logging.openshift.io.
fi


## Replacing template values for Cluster Logging Instance
cp clo-instance.template.yaml clo-instance.yaml
sed -i.bak "s|paramElasticSearchNodeCount|$paramElasticSearchNodeCount|g" clo-instance.yaml
sed -i.bak "s|paramClusterLoggingStorageClass|$paramClusterLoggingStorageClass|g" clo-instance.yaml
sed -i.bak "s|paramFluentdBufferTotalLimitSize|$paramFluentdBufferTotalLimitSize|g" clo-instance.yaml
sed -i.bak "s|paramFluentDBufferFlushThreadCount|$paramFluentDBufferFlushThreadCount|g" clo-instance.yaml


## Create a Cluster Logging instance.
echo
echo Creating Cluster Logging Instance
oc apply -f clo-instance.yaml


## Wait for ElasticSearch PODs to be Running
echo
echo Waiting up to 10 minutes for all $paramElasticSearchNodeCount elasticsearch PODs to be in Running state.
date

WAIT_TIME=10
TRIES=0  
ES_PODS_RUNNING=$(oc get pods -l component=elasticsearch  --no-headers -n openshift-logging 2>/dev/null | grep -c Running || true)

while [ $ES_PODS_RUNNING -ne $paramElasticSearchNodeCount ] && [ $TRIES -lt 60 ]
do
	sleep 10
 	TRIES=$(( $TRIES + 1 ))
	ES_PODS_RUNNING=$(oc get pods -l component=elasticsearch  --no-headers -n openshift-logging 2>/dev/null | grep -c Running || true)
done

if [ $ES_PODS_RUNNING -eq $paramElasticSearchNodeCount ]
then
	echo All $paramElasticSearchNodeCount elastic search PODs are now Running.
else
	echo Timed out waiting for elastic search PODs to be in Running state. Exiting...
        exit 1
fi 

## Wait for ElasticSearch Cluster to be Ready
echo
echo Waiting up to 10 minutes for elastic search cluster to be ready.
date

WAIT_TIME=10
TRIES=0  
# Find ES pod needed to run command
ES_POD=$(oc get pods -l component=elasticsearch  --no-headers -n openshift-logging | cut -d " " -f1 | head -1)
# Looking for ES cluster to report green.   Using internal es_cluster_health command found in ES pod to find out status 
ES_CLUSTER_UP=$(oc exec -n openshift-logging -c elasticsearch $ES_POD -- es_cluster_health | grep status | grep green || true)
while [ -z "$ES_CLUSTER_UP" ] && [ $TRIES -lt 60 ]
do
	sleep 10
 	TRIES=$(( $TRIES + 1 ))
	ES_CLUSTER_UP=$(oc exec -n openshift-logging -c elasticsearch $ES_POD -- es_cluster_health 2>/dev/null | grep status | grep green || true)
done

if [ -z "$ES_CLUSTER_UP" ]
then
	echo Timed out waiting for elastic search cluster to be ready. Exiting...
        exit 1
else
	echo Elastic search cluster is ready. 
fi 

## Clean up elastic search jobs that may have been triggered before ES cluster was ready.
echo
echo Cleaning failed premature cron job instances

for failedJob in $(oc get pods -l component=indexManagement  --no-headers -n openshift-logging | grep Error | cut -d " "  -f1)
do
        oc delete pod $failedJob -n openshift-logging
done

## Wait for kibana route to be created 
echo 
echo Waiting up to 5 minutes for Kibana route to be created
date

KIBANA_ROUTE_NAME=kibana
EXIST=$(oc get route $KIBANA_ROUTE_NAME -n openshift-logging 2>/dev/null | grep -c $KIBANA_ROUTE_NAME || true) 
WAIT_TIME=10
TRIES=0

while [ $EXIST -eq 0 ] && [ $TRIES -lt 30 ]
do
        echo Could not find route resource for Kibana. Waiting for $WAIT_TIME seconds before trying again
        sleep $WAIT_TIME
        TRIES=$(( $TRIES + 1 ))
        EXIST=$(oc get route $KIBANA_ROUTE_NAME -n openshift-logging 2>/dev/null | grep -c $KIBANA_ROUTE_NAME || true)
done

if [ $EXIST -eq 0 ]
then
        echo Could not find route resource for Kibana. Please check status of ClusterLogging instance.
        exit 1

else
        echo Found route resource for Kibana.  
fi



## Get Kibana service endpoint 
KIBANA=$(oc get route $KIBANA_ROUTE_NAME -n openshift-logging -o  jsonpath='{.spec.host}')

# If we got to this point things have been configured properly.
echo
echo "*********************************************************************************"
echo "*********             Logging Stack configured successfully!            *********"
echo "*********             Please follow manual steps listed below           *********"
echo "*********************************************************************************"
echo 

## Remaining setup is currently manual 
cat << EOF 
MANUAL STEPS TO FOLLOW:
- Go to your Kibana instance found here:
  https://$KIBANA

- Define the following index patters.  Use @timestamp as the timefield for each pattern. 
	app-* 
	infra-*

EOF
