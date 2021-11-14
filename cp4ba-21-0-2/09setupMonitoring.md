# Step 9: Optional: Setup OpenShift Monitoring Stack

## Introduction

The OpenShift monitoring stack provides monitoring capabilities for core platform components and user defined projects.  By default the out-of-the-box deployment, found under the openshift-monitoring project, only monitors core OpenShift Container Platform systems and other essential kubernetes services but it can be configured to monitor custom deployments.

The following set of instructions will provide a simplified way to setup the monitoring stack in your Openshift installation so that we can leverage custom metrics, alerts and Slack notifications for IBM Cloud Pak for Business Automation components. For a more detailed explanation on OpenShift's monitoring stack see [Understanding the Monitoring Stack](https://docs.openshift.com/container-platform/4.6/monitoring/understanding-the-monitoring-stack.html).

## Pre-Requisites

- OpenShift cluster already deployed.
- User with cluster-admin role.
- OpenShift's `oc` command installed on system where script is going to run.
- The `sed` command installed on system where script is going to run.  

## Step 1: Modify default deployment parameters

As a simplified version of a monitoring stack deployment our scripts support a small subset of configuration parameters. All parameters can be specified in the `monitoring/config.sh` script.  The table provided below describes the configuration parameters that can be changed using our scripts and the default values assigned to each setting.  

|Parameter|Description|Default|
|---------|-----------|-------|
|paramClusterName|Name of the cluster where the monitoring stack will be installed. This is an arbitrary name used to identify the environment where alerts are coming from. For example `tech-jam-emea`||
|cp4baNamespace|Namespace where CP4BA components are installed.|ibm-cp4ba|
|otherNamespaces|Space separated list of namespaces that are part of the overall cp4ba configuration where alert rules must be configured. For example the namespace where DB2 and ADS ML services are installed, "ibm-db2 ibm-ads-ml-service".  This parameter must be specified using double quotes. Leave empty if none.|"ibm-db2 ibm-common-services"|
|paramRepeatInterval|Time to wait before a repeated group of alerts can be resend use h,m,s to indicate hours, minutes and seconds respectively|6h|
|configureSlackReceiver|Whether we should configure Slack as a receiver in the Alertmanager's configuration. If true Alertmanager will send alerts to a specific Slack channel based on the `paramSlackApiUrlPlatform` parameter|false|
|paramSlackApiUrlPlatform|This parameter represents the Stack URL that Alertmanager will use to send notifications.  This URL is provided as a Webhook created in your Slack application for the specific channel where you want notifications to be sent. See [Create Slack Application](#CreateSlackApplication) section for additional details. ||
|paramUseChannelHandler|Use this parameter to turn on or off the use of the @channel Slack handler when Alertmanager sends alerts to channel.|false|

To modify any of the configuration parameters:

1. Open the `config.sh` file found under the `monitoring` directory and specify the new values.  

Once configuration parameters have been specified, we can move on to the next steps to configure the monitoring stack.  Make sure to pay special attention to `paramClusterName` and `otherNamespaces` since those parameters have no default values.

## Step 2: Run Configuration Script

To configure the Monitoring Stack on your OpenShift cluster:

1. Log in to the OpenShift cluster using the `oc loggin` command.
2. Run the `configure-monitoring.sh` command found under the `monitoring` directory and wait for completion.
3. If the following banner is displayed **all** Monitoring Stack components have been deployed successfully.

    ```bash
    *********************************************************************************
    *********           Monitoring Stack configured successfully!           *********
    *********************************************************************************
    ```

**Note:** The `configure-monitoring.sh` script is idempotent and it is configured to stop immediately if an error is found during the deployment process. Should errors arise, you can re-run the script once the problems are corrected.

## Create Slack Application

If you are configuring Slack as a receiver for Alertmanager's notifications you have to create a Slack Application for the IBM Slack Workspace where the target Slack channel is found.  To create a Slack Application do the following:

1. Go to [api.slack.com](https://api.slack.com/apps)
2. Click on *Create New App* button
3. Select the *From scratch* option.
4. Enter a name for your new application.  For example *AlertManager Alerts*.
5. Select the Slack IBM Workspace where the target channel to post Alertmanager's notifications is found.  
6. Under the *Add Features and Functionality* section click on *Incoming Webhooks*
7. Click on the *Activate Incoming Webhooks* toggle button to turn this capability on for your application.
8. Request permission for your application to run in the IBM Workspace by clicking the *Request to Add New Webhook* button at the bottom of the page.
9. Wait for the approval of your application.  The admin of the IBM Workspace will contact you via Slack.

Once application has been approved by the administrators of the IBM workspace:

1. Go back to [api.slack.com](https://api.slack.com/apps)
2. Drill down into the details of your application by clicking on the application name.
3. Click on the *Incoming Webhooks* link found on the left side of the page.
4. Scroll down to the *Webhook URLs for Your Workspace* section.
5. Click *Add New Webhook to Workspace* button.
6. On the new dialog displayed, select the channel where you want Alertmanager's notifications to go.
7. Click the *Allow* button.
8. Once Webhook has been created, go back to the  *Incoming Webhooks* link, scroll down to the *Webhook URLs for Your Workspace* section and copy the new webhook URL provided for your channel.
9. Use the new webhook as the value for the `paramSlackApiUrlPlatform` parameter in the `monitoring/config.sh` file.  

## Other Details

### Resource files

During the deployment and configuration of the Openshift monitoring stack we create a set of yaml files with the configuration for each of the resources created.  The files generated during the deployment are:

*Monitoring Stack General Configuration:*

|File|Description|
|----|-----------|
|`alertmanager.yaml`|Overall Alertmanager configuration|
|`cluster-monitoring-config.yaml`|Monitoring stack configuration to enable monitoring of user defined projects|
|`user-workload-monitoring-config.yaml`|Configuration of user defined projects monitoring|

*Alert Rules Created:*

|File|Description|
|----|-----------|
|`cp4ba-setup-pod-close-to-cpu-limit.yaml`|Alert rule to notify when PODs are close to their CPU limit.|
|`cp4ba-setup-pod-crash-looping.yaml`|Alert rule to notify when PODs are crashing.|
|`cp4ba-setup-pod-close-to-mem-limit.yaml`|Alert rule to notify when PODs are close to their Memory limit.|
|`cp4ba-setup-pod-not-healthy.yaml`|Alert rule to notify when PODs are not in Ready state.|

All these rules are deployed on each namespace listed in the `cp4baNamespace` and `otherNamespaces` parameters.

*Silencers Created:*

|File|Description|
|----|-----------|
|`ads-download-silence.json`|Silencer created to prevent high memory utilization alerts coming from the ADS Download component. We have found out that this issue auto-corrects.|
|`bai-management-silence.json`|Silencer created to prevent high memory utilization alerts coming from the BAI Management component. We have found out that this issue auto-corrects.|

*Service Monitors Created:*

|File|Description|
|----|-----------|
|`cp4ba-ecm-cmis-monitor.yaml`|Service monitor to get CMIS custom metrics into Prometheus|
|`cp4ba-ecm-css-monitor.yaml`|Service monitor to get CSS custom metrics into Prometheus|
|`cp4ba-operator-monitor.yaml`|Service monitor to get CP4BA Operator's custom metrics into Prometheus|
|`cp4ba-ecm-cpe-monitor.yaml`|Service monitor to get CPE custom metrics into Prometheus|
|`cp4ba-ecm-graphql-monitor.yaml`|Service monitor to get GraphQL custom metrics into Prometheus|

Service Monitors are created on each of the namespaces specified by the `cp4baNamespace`. Currently we do not support creating service monitors for projects listed on the `otherNamespaces` parameter.

All files are generated under the `monitoring`, `monitoring/alerts`, `monitoring/silence`, `monitoring/monitors` directories respectively. Save or keep these files under source control if you would like to keep track of resources deployed in your cluster.  If you configured Slack as a Receiver for your alerts, you should not check-in the `alertmanager.yaml` file in your github repo (even the IBM Internal one).  Having the Webhook for your Slack application in your repo is considered a *Security Violation*.

### Configured Resources

The `configure-monitoring.sh` changes the following resources in your Openshift cluster. Backup files for these resource are created with the extension `.bak`.

- ConfigMap `cluster-monitoring-config` under the `openshift-monitoring` namespace
- ConfigMap `user-workload-monitoring-config` under the `openshift-user-workload-monitoring` namespace.

## What to do next

- Optionally, you can complete **[Step 10: Optional: Create new VM for RPA  &  install IBM RPA](10createVMForRPA.md)**
- Optionally, you can complete **[Step 11: Optional: Scale up the deployment](11scaleUp.md)**
- **[Here](Readme.md)** you can get back to the overview page

Issues or questions? IBMers can use this IBM internal Slack channel: **#dba-swat-asset-qna** (**https://ibm-cloud.slack.com/archives/C026TD1SGCA**)

Everyone else can open a new issue in this github.
