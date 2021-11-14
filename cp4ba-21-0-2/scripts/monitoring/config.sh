#! /bin/sh

##
## Name of the cluster where monitoring rules will be installed.  
## This is an arbitrary name used to identify the environment where alerts are coming from 
## For example JamAmericas, JamEMEA, DemoCluster, etc. 
##
paramClusterName=


##
## Namespace for cp4ba installation 
##
cp4baNamespace=


##
## Space separated list of other namespaces that might be part of the overall cp4ba configuration where alert rules must be also configure.  Keep the double quotes! 
## For example "ibm-db2, ibm-ads-ml-service", etc
##
otherNamespaces=""


##
## Name of the default receiver to use in the configuration. All K8s platform alerts will come through this receiver.   
## This receiver must be configured in the alertmanager.yaml 
## Available options are Default, Platform, JAM. 
## Using the Default receiver will cease to send Platform alerts to Slack
##
paramDefaultReceiver=Default


##
## Time to wait before alerts can be resend use h,m,s to indicate hours, minutes and seconds 
##
paramRepeatInterval=6h


##
## Whether we should configure Slack as a receiver in the Alertmanager's configuration
## If true you will need a Slack Application and a Webhook(URL) from the application.
## For details on how to create Slack Application or to see your 
## existing Slack Applications go to https://api.slack.com/apps
## Possible values for this setting are true or false.  When true Alertmanager will be configured 
## to send all notifications to the predefined Slack channel that is implicit in the Webhook  
##
configureSlackReceiver=false

##
## This parameter represents the Stack URL used to send notifications for 
## the Kubernetes Platform alerts
## If configureSlackReceiver was set to true, this URL must be specified.  This URL comes
## from your Slack Application. 
## DO NOT Check in this file into your git repo once this URL has been specified.   
## Checking-in this URL in a git repo is considered a Security Violation and you will 
## be forced the integration URL from Slack if you publish it.
##
paramSlackApiUrlPlatform=


##
## This parameter represents the Slack URL used to send notifications related to CP4BA components
## Currently set to the same value as the K8s platform alerts  
##
paramSlackApiUrlJAM=$paramSlackApiUrlPlatform


##
## Use Slack @channel handler when sending alerts.  Set to false if alerts sent to the slack channel 
## should not have the @channel handler to automatically notify members of the channel.  Possible values 
## are true or false.   
##
paramUseChannelHandler=false


##
## Number of years to silence alerts that are not necessary
##
silencePeriodInYears=2
