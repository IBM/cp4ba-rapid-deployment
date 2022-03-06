# Step 4: Deploy IBM DB2 Containers & create needed databases

![Overview](images/overview04.jpg "Overview")

1. On your bastion host create a new directory for the scripts needed and switch to it
   
   **Note:** As part of this doc, it is assumed that you create new directory `/cp4ba`. If you select a different directory, you have to change some of the commands in this and following steps accordingly, otherwise you can simply copy/paste them.
   
   ```
   mkdir /cp4ba
   ```
   
   ```
   cd /cp4ba
   ```
   
2. Clone this git repository onto your bastion host and copy the deployment scripts
   
   **Note:** As part of this doc, it is assumed that you copy the deployment scripts into directory `mycluster`. If you select a different directory, you have to change some of the commands in this and following steps accordingly, otherwise you can simply copy/paste them.

   ```
   git clone https://github.com/IBM/cp4ba-rapid-deployment
   ```
   
   ```
   cd /cp4ba/cp4ba-rapid-deployment/cp4ba-21-0-3
   ```
   
   ```
   cp -r scripts mycluster
   ```
   
   ```
   cd mycluster/deployment-db2-cp4ba
   ```
   
3. Optional: Dependant on the CP4BA template selected in **[Step 0: Select the CP4BA template for deployment](00selectTemplate.md)**, get a DB2 Standard Edition license key to enable containerized DB2 to use more CPUs and RAM compared to the Community Edition
   
   **Note:** In case you don't have access to a DB2 Standard Edition license key, you can install DB2 with the Community Edition license that is included by default. But, this might result in issues when deploying some of the provided CP4BA templates later on, as it might happen that the CPE Object Stores can't be automatically initialized while the deployment as the DB connections might not be able to be created. In that case, scale down the operator to zero after the Object Store initialization failed and create the missing DB connections manually. Then, scale up the operator to one and it will successfully initialize the Object Stores.
   
   - On PPA or XL SW, search for part number CC36WML and download DB2_DSE_Activation_11.5.zip
   - Extract db2std_vpc.lic from the archive (can be found in DB2_DSE_Activation_11.5.zip/std_vpc/db2/license)
   - Base64 encode your Db2 license by running the following commands:
     
     ```
     LICENSE_KEY="./db2std_vpc.lic"
     ```
     
     ```
     cat ${LICENSE_KEY} | base64 | tr -d '\n'
     ```
     
   - Save the encoded output, as you will add it to your properties file in the next step
   
   **Note:** More background on this topic can be found here: **https://www.ibm.com/support/producthub/db2/docs/content/SSEPGG_11.5.0/com.ibm.db2.luw.qb.server.doc/doc/c0061199.html**

4. In folder **/cp4ba/cp4ba-rapid-deployment/cp4ba-21-0-3/mycluster/deployment-db2-cp4ba** update the properties file for DB2, **01-parametersForDb2OnOCP.sh**, and provide the following properties:
   
   - `cp4baTemplateToUse` - Name of CP4BA deployment template that will be used e.g. `ibm_cp4a_cr_template.002.ent.FoundationContent.yaml`
   - `db2OnOcpProjectName` - Namespace where DB2 should be installed e.g. `ibm-db2`
   - `db2AdminUserPassword` - Password that will be assigned to the db2 instance user e.g. `passw0rd`
   - `db2StandardLicenseKey` - provide the encoded licence key from previous step if needed, otherwise leave empty, means remove the default value `REQUIRED`
   - `db2Cpu` - Number of CPUs for DB2 pod according to the selected CP4BA template
   - `db2Memory` - Amount of memory for DB2 pod according to the selected CP4BA template
   
   Also review the other properties, in case changes are needed, e.g., if you are not deploying on ROKS, specify `cp4baDeploymentPlatform=OCP` and also provide the `db2OnOcpStorageClassName` available on your own OpenShift cluster (must be RWX). For ROKS a `db2StorageSize` of `500Gi` is optimal as the size also defines the IOPS. If you are not deploying on ROKS and your storage provider gives you good IO speed with smaller storage size, you can reduce that value to `150Gi`.

5. If not done already, login to your OCP cluster through OC CLI, for example:
   
   ```
   oc login --token=<your-token> --server=https://<your-server>:<your-port>
   ```
   
   **Note:** You can copy the login command from the OCP Web console.
   
   Verify that the version of the OC CLI and cluster version are similar:
   
   ```
   oc version
   ```
   
   Sample output:
   
   ```
   oc version
   Client Version: 4.8.0-202111041632.p0.git.88e7eba.assembly.stream-88e7eba
   Server Version: 4.8.26
   Kubernetes Version: v1.21.6+bb8d50a
   ```
   
   **Note:** If the version is not similar, download the appropriate OC CLI and install it on your bastion host.

6. Run script **02-createDb2OnOCP.sh**.  This script will install and configure DB2 for you.  If the script displays the following banner **all** DB2 components have been deployed and configured properly.

   ```bash
   *********************************************************************************
   ********* Installation and configuration of DB2 completed successfully! *********
   *********************************************************************************
   ```

   After this banner is displayed it is possible for the script to fail on some post deployment clean up work.  Failing the cleanup work does not impact the successful deployment and configuration of DB2.

   **Notes:**
   - To successfully run the script you need the **jq tool** and **podman** installed - if not yet installed, install them before running the script
   - You need your **Entitlement Registry key** handy, see also **[Step 1: Create your IBM Cloud Account (or use existing)](01createIBMCloudAccount.md)**
   - This script will exit if errors are hit during the installation.
   - This script is idempotent.
   
   Sample script output:
   ```
   ./02-createDb2OnOCP.sh
   
   Found 01-parametersForDb2OnOCP.sh.  Reading in variables from that script.
     Reading 01-parametersForDb2OnOCP.sh ...
   Done!
   
   Installing DB instance for CloudPak.
   
   This script installs Db2u on OCP into project ibm-db2. For this, you need the jq tool installed and your Entitlement Registry key handy.
   
   Do you want to continue (Yes/No, default: No): y
   
   Installing Db2U on OCP...
   
   Installing the storage classes...
   W0215 08:00:00.000000   12241 warnings.go:70] storage.k8s.io/v1beta1 StorageClass is deprecated in v1.19+, unavailable in v1.22+; use storage.k8s.io/v1 StorageClass
   W0215 08:00:00.000001   12241 warnings.go:70] storage.k8s.io/v1beta1 StorageClass is deprecated in v1.19+, unavailable in v1.22+; use storage.k8s.io/v1 StorageClass
   storageclass.storage.k8s.io/cp4a-file-delete-bronze-gid created
   W0215 08:00:00.000002   12257 warnings.go:70] storage.k8s.io/v1beta1 StorageClass is deprecated in v1.19+, unavailable in v1.22+; use storage.k8s.io/v1 StorageClass
   W0215 08:00:00.000003   12257 warnings.go:70] storage.k8s.io/v1beta1 StorageClass is deprecated in v1.19+, unavailable in v1.22+; use storage.k8s.io/v1 StorageClass
   storageclass.storage.k8s.io/cp4a-file-delete-silver-gid created
   W0215 08:00:00.000004   12269 warnings.go:70] storage.k8s.io/v1beta1 StorageClass is deprecated in v1.19+, unavailable in v1.22+; use storage.k8s.io/v1 StorageClass
   W0215 08:00:00.000005   12269 warnings.go:70] storage.k8s.io/v1beta1 StorageClass is deprecated in v1.19+, unavailable in v1.22+; use storage.k8s.io/v1 StorageClass
   storageclass.storage.k8s.io/cp4a-file-delete-gold-gid created
   storageclass.storage.k8s.io/ibmc-block-gold patched
   storageclass.storage.k8s.io/cp4a-file-delete-gold-gid patched
   
   Installing the IBM Operator Catalog...
   catalogsource.operators.coreos.com/ibm-operator-catalog created
   
   Creating project ibm-db2...
   namespace/ibm-db2 created
   Now using project "ibm-db2" on server "https://<your-server>:<your-port>".
   
   Creating secret ibm-registry. For this, your Entitlement Registry key is needed.
   
   You can get the Entitlement Registry key from here: https://myibm.ibm.com/products-services/containerlibrary
   
   Enter your Entitlement Registry key: 
   Verifying the Entitlement Registry key...
   Login Succeeded!
   Entitlement Registry key is valid.
   secret/ibm-registry created
   
   Preparing the cluster for Db2...
   Starting pod/1013523118-debug ...
   To use host binaries, run `chroot /host`
   
   Removing debug pod ...
   Starting pod/1013523126-debug ...
   To use host binaries, run `chroot /host`
   
   Removing debug pod ...
   Starting pod/101352317-debug ...
   To use host binaries, run `chroot /host`
   
   Removing debug pod ...
   
   Modifying the OpenShift Global Pull Secret (you need jq tool for that):
   secret/pull-secret data updated
   
   Creating Operator Group object for DB2 Operator
   operatorgroup.operators.coreos.com/ibm-db2-group created
   
   Creating Subscription object for DB2 Operator
   subscription.operators.coreos.com/db2u-operator created
   
   Waiting up to 5 minutes for DB2 Operator install plan to be generated.
   Sat Jan 01 08:00:01 PST 2022
   
   Approving DB2 Operator install plan.
   installplan.operators.coreos.com/install-bwdq7 patched
   
   Waiting up to 5 minutes for DB2 Operator to install.
   Sat Jan 01 08:00:02 PST 2022
   
   Deploying the Db2u cluster.
   db2ucluster.db2u.databases.ibm.com/db2ucluster created
   
   Waiting up to 15 minutes for c-db2ucluster-db2u statefulset to be created.
   Sat Jan 01 08:00:03 PST 2022
   
   Patching c-db2ucluster-db2u statefulset.
   statefulset.apps/c-db2ucluster-db2u patched (no change)
   
   Waiting up to 15 minutes for c-db2ucluster-restore-morph job to complete successfully.
   Sat Jan 01 08:00:04 PST 2022
   
   Updating number of databases allowed by DB2 installation from 8 to 30.
   configmap/c-db2ucluster-db2dbmconfig replaced
   
   Updating database manager running configuration.
   DB20000I  The UPDATE DATABASE MANAGER CONFIGURATION command completed 
   successfully.
   
   Removing BLUDB from system.
   DB20000I  The DEACTIVATE DATABASE command completed successfully.
   DB20000I  The DROP DATABASE command completed successfully.
   
   Restarting DB2 instance.
   01/01/2022 08:00:05     0   0   SQL1064N  DB2STOP processing was successful.
   SQL1064N  DB2STOP processing was successful.
   01/01/2022 08:00:06     0   0   SQL1063N  DB2START processing was successful.
   SQL1063N  DB2START processing was successful.
   
   *********************************************************************************
   ********* Installation and configuration of DB2 completed successfully! *********
   *********************************************************************************
   
   Existing databases are:
   
   Use this hostname/IP to access the databases e.g. with IBM Data Studio.
   Please also update in 01-parametersForDb2OnOCP.sh property "db2HostName" with this information (in Skytap, use the IP 10.0.0.10 instead)
     Hostname: <your-hostname>
     Other possible addresses(If hostname not available above): <your-addresses>
   
   Use one of these NodePorts to access the databases e.g. with IBM Data Studio (usually the first one is for legacy-server (Db2 port 50000), the second for ssl-server (Db2 port 50001)).
                   "nodePort": <your-http-port>,
                   "nodePort": <your-https-port>,
   
   Use "db2inst1" and password "<your-password>" to access the databases e.g. with IBM Data Studio.
   
   Db2u installation complete! Congratulations. Exiting...
   ```

7. Run script **03-createCp4baDBs4Db2OnOCP.sh** to create the databases needed for the CP4BA template that you selected
   
   **Note:** You can ignore the following errors / warnings:
   ```
   DB21034E  The command was processed as an SQL statement because it was not a
   valid Command Line Processor command.  During SQL processing it returned:
   SQL0554N  An authorization ID cannot grant a privilege or authority to itself.
   SQLSTATE=42502
   ```
   
   and
   ```
   SQL1363W  One or more of the parameters submitted for immediate modification
   were not changed dynamically. For these configuration parameters, the database
   must be shutdown and reactivated before the configuration parameter changes
   become effective.
   ```
   
   **Note:** In case you got errors **creating** DBs, please use script **99-dropCp4baDBs4Db2OnOCP.sh** to drop all DBs - then re-run script **03-createCp4baDBs4Db2OnOCP.sh**

   **Note:** In case you got errors **activating** DBs, please use script **04-activateDBs.sh** to try to activate them again - if your DB2 pod got enough memory assigned (e.g., `110Gi` for the Client Onboarding template) and you are using a DB2 Standard Edition license, activation of all DBs should be successful

   **Note:** In case you are not using the DB2 Standard Edition license or have assigned less memory to DB2 than specified for the selected CP4BA template, it might happen that not all databases got activated which might lead to other issues later while the deployment of CP4BA

8. Review the output of the script and make sure there were no errors, all databases got created and activated

## What to do next

Now, that all the prerequisites for IBM Cloud Pak for Business Automation are there, you can run **[Step 5: Install IBM Cloud Pak for Business Automation Operator  &  deploy IBM Cloud Pak for Business Automation (Production)](05installCP4BA.md)**

**[Here](Readme.md)** you can get back to the overview page

Issues or questions? IBMers can use this IBM internal Slack channel: **#dba-swat-asset-qna** (**https://ibm-cloud.slack.com/archives/C026TD1SGCA**)

Everyone else can open a new issue in this github.
