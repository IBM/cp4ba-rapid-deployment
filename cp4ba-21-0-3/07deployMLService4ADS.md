# Step 7: Optional: Deploy Machine Learning Service for ADS

![Overview](images/overview07.jpg "Overview")

1. Get access to the ml service image, e.g. by building it as documented here: **https://github.com/IBM/open-prediction-service-hub/tree/main/ops-implementations/ads-ml-service**

2. Switch to the directory with the deployment scripts for the ADS ML Service
   
   ```
   cd /cp4ba/cp4ba-rapid-deployment/cp4ba-21-0-3/mycluster/deployment-ads-ml-service
   ```

3. In folder **deployment-ads-ml-service** update the properties file for the ml service **01-parametersForAdsMlService.sh**, provide the following properties:
   
   - `adsMlServiceProjectName`, e.g., `ibm-ads-ml-service`
   - `pgAdminPassword`, e.g., `passw0rd` - you can choose here any password
   - `adsMlServiceImageArchive`, path to the image build before, e.g. `/ads-ml-service.tar`
   
   Also review the other properties, in case changes are needed, e.g., adjust the replica count or Storage Class in case you are not deploying on ROKS.

4. Run script **02-deployPostgres.sh**
   
   Sample script output
   
   ```
   ./02-deployPostgres.sh
   
   * Found 01-parametersForAdsMlService.sh. Reading in variables from that script.
       Reading 01-parametersForAdsMlService.sh ...
   * Done!
   
   * Creating project <your-ibm-ads-ml-service-project>...
   Now using project "<your-ibm-ads-ml-service-project>" on server "https://<hostname>:<port>".
   
   You can add applications to this project with the 'new-app' command. For example, try:
   
       oc new-app ruby~https://github.com/sclorg/ruby-ex.git
   
   to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:
   
       kubectl create deployment hello-node --image=gcr.io/hello-minikube-zero-install/hello-node
   
   * Creating Postgres Service Account
   serviceaccount/postgres created
   
   * Configuring Postgres service account to with anyuid Role Binding clusterrole.rbac.authorization.k8s.io/system:openshift:scc:anyuid added: "postgres"
   
   * Creating Postgres Secret
   secret/postgres-secret created
   
   * Found Storage Class cp4a-file-delete-gold-gid
   * Creating Postgres PersistentVolumeClaim
   persistentvolumeclaim/postgres created
   * Waiting for Postgres PersistentVolumeClaim to be bound
   * Postgres PersistentVolumeClaim is bound
   
   * Creating new Postgres Deployment and Service
   deployment.apps/postgres created
   service/postgres created
   * Waiting for Pods to be created
   * Postgres POD exists: pod/postgres-fc54f76dd-sfb6r
   * Postgres POD is running
   
   * Monitor the log output of the Postgres pod and wait until it is initialized.
   * Wait for log output:
   
           "LOG:  database system is ready to accept connections"
   
   * before you proceed with creating the database.
   ```
   
   **Note:** If the deployment fails because you can't pull the image, follow these steps:
   - Create the following secret using your docker email, password and username (if you don't have a docker account yet, create one here: **https://hub.docker.com/**)
     
     ```
     oc create secret docker-registry docker.registrykey --docker-server 'https://index.docker.io/v1/' --docker-email <your-docker-email> --docker-password <your-docker-password> --docker-username <your-docker-username>
     ```
     
   - Run script **99-deleteAdsMlServiceAndPostgres.sh** to delete the deployment
   - Re-run script **02-deployPostgres.sh**

5. Run script **03-pushAdsMlServiceImage.sh**
   
   Sample script output
   
   ```
   ./03-pushAdsMlServiceImage.sh
   
   * Found 01-parametersForAdsMlService.sh. Reading in variables from that script.
       Reading 01-parametersForAdsMlService.sh ...
   * Done!
   
   Now using project "openshift-image-registry" on server "https://<hostname>:<port>".
   Error from server (NotFound): routes.route.openshift.io "image-registry" not found
   route.route.openshift.io/image-registry created
   * Route: <your-image-registry-route>
   
   * Project <your-ibm-ads-ml-service-project> exists. Switching to it...
   Now using project "<your-ibm-ads-ml-service-project>" on server "https://<hostname>:<port>".
   
   * Docker login
   WARNING! Using --password via the CLI is insecure. Use --password-stdin.
   WARNING! Your password will be stored unencrypted in /home/user/.docker/config.json.
   Configure a credential helper to remove this warning. See https://docs.docker.com/engine/reference/commandline/login/#credentials-store
   
   Login Succeeded
   
   * Docker load
   0e41e5bdb921: Loading layer [==================================================>]  119.2MB/119.2MB
   644448d6e877: Loading layer [==================================================>]  17.18MB/17.18MB
   81496d8c72c2: Loading layer [==================================================>]  17.87MB/17.87MB
   bde301416dd2: Loading layer [==================================================>]    150MB/150MB
   dacb447ffe30: Loading layer [==================================================>]  520.7MB/520.7MB
   04d1717d0e01: Loading layer [==================================================>]  18.51MB/18.51MB
   2cdb72475c99: Loading layer [==================================================>]  47.67MB/47.67MB
   abb35d8edc01: Loading layer [==================================================>]  4.608kB/4.608kB
   0b18c63fe124: Loading layer [==================================================>]   8.55MB/8.55MB
   75c6dfe8ea1f: Loading layer [==================================================>]  30.45MB/30.45MB
   f4fbe59b6dfe: Loading layer [==================================================>]   5.12kB/5.12kB
   0dc6f22674c5: Loading layer [==================================================>]  11.78kB/11.78kB
   567cb9bef5e9: Loading layer [==================================================>]  792.8MB/792.8MB
   7e56ebde7a8e: Loading layer [==================================================>]   5.12kB/5.12kB
   588d9178e5d4: Loading layer [==================================================>]  3.072kB/3.072kB
   7a29cf206a89: Loading layer [==================================================>]  4.096kB/4.096kB
   3823826c43a3: Loading layer [==================================================>]  232.2MB/232.2MB
   Loaded image: localhost/ads-ml-service:latest
   
   * Docker tag
   
   * Docker push
   The push refers to repository [<your-image-registry-route>/<your-ibm-ads-ml-service-project>/ads-ml-service]
   3823826c43a3: Pushed 
   7a29cf206a89: Pushed 
   588d9178e5d4: Pushed 
   7e56ebde7a8e: Pushed 
   567cb9bef5e9: Pushed 
   0dc6f22674c5: Pushed 
   f4fbe59b6dfe: Pushed 
   75c6dfe8ea1f: Pushed 
   0b18c63fe124: Pushed 
   abb35d8edc01: Pushed 
   2cdb72475c99: Pushed 
   04d1717d0e01: Pushed 
   dacb447ffe30: Pushed 
   bde301416dd2: Pushed 
   81496d8c72c2: Pushed 
   644448d6e877: Pushed 
   0e41e5bdb921: Pushed 
   latest: digest: sha256:c09bd5f5744356b1ec48af261448d8911f4ee0c6e03268478c3434e48cf68ace size: 3890
   
   * Docker rmi
   Untagged: <your-image-registry-route>/<your-ibm-ads-ml-service-project>/ads-ml-service:latest
   Untagged: <your-image-registry-route>/<your-ibm-ads-ml-service-project>/ads-ml-service@sha256:c09bd5f5744356b1ec48af261448d8911f4ee0c6e03268478c3434e48cf68ace
   Untagged: localhost/ads-ml-service:latest
   Deleted: sha256:6d71491d7762211cced72c37a146f8c2e1b9805df60098f2cd29db15c5220982
   Deleted: sha256:d5a5b748d5777233681e6bf056c83d545a0fa96190c4976d824e81a8da86238c
   Deleted: sha256:34805e3605c3ba317b1706eee048e295c2d20a895002faecec4b6246f153fb74
   Deleted: sha256:b6bc4cc86a49b812eecd7c618b4daea47fe8c01abc51a3e701506daaf9af680f
   Deleted: sha256:8f86b733b07a04b170c5c9c68ecd432f69fe6d1c7621828aa3c7c0a9e0cdc73c
   Deleted: sha256:799aebf7e847361b7ff4b7a85bd5f058aacfc5f67cbcb43f2ac2bc9104ea3da0
   Deleted: sha256:cbfaa15264fb162b7fab6aaccf3d28c479dcf477f9753fcb711c76757465375f
   Deleted: sha256:51dc06fd7f00ba5ef3716cee9679e120e1f7ff04ef431caa9913a239626ede63
   Deleted: sha256:ab422f3b499d39abacfb4e3cf159ccb52d39df0446d13e444c57d8ae615ddefb
   Deleted: sha256:605701c48cb9ac8464c697a041e56feb67d52e6fd3b5f42fe5185192066756f5
   Deleted: sha256:5916cbbb740d90ae1e59efa57536cc3fd4dcada227ab4968536e56d998827061
   Deleted: sha256:a7168e0661015e4709727946c50095fb8caccebdbf24c4d6cc349675036bed28
   Deleted: sha256:6aad9fdadf44b784c462f2c5ea26ae9406251032307aaca88ef54b774b85b460
   Deleted: sha256:4b6de216586ebb955e783d0dbe852e061c7efd8dceb2a9b070f28ce54e856242
   Deleted: sha256:0bcd25518e8491d5502b8a2a9d201f01fbf0258f2409db923d4af5193a61dd15
   Deleted: sha256:5d7924d7f72827891e5667bae9cff503c77919e7c53208851fc7f3f4ad2b2515
   Deleted: sha256:4247873fcc45ba38f4ee7a23a98b6ebf3874666ee99fe8f2828e6228b4328213
   Deleted: sha256:0e41e5bdb921aea3c3c9bb5eb61c004fdb6286fe8800f266887243e268fb957a
   
   * Done. Exiting...
   ```

6. Verify that the postgress pod shows log message "LOG:  database system is ready to accept connections" before proceeding

7. Run script **04-createAdsMlDb.sh***
   
   Sample script output
   
   ```
   ./04-createAdsMlDb.sh 
   
   * Found 01-parametersForAdsMlService.sh. Reading in variables from that script.
       Reading 01-parametersForAdsMlService.sh ...
   * Done!
   
   * Project <your-ibm-ads-ml-service-project> exists. Switching to it...
   Already on project "<your-ibm-ads-ml-service-project>" on server "https://<hostname>:<port>".
   
   * Configuring ADS ML Service Database in Postgres deployment
   * Postgres POD exists: postgres-fc54f76dd-sfb6r
   ++ mkdir /mnt/mlserving
   ++ chown postgres:postgres /mnt/mlserving
   ++ psql -c 'create database mlserving template template0 encoding UTF8'
   CREATE DATABASE
   
   * Existing databases are:
                                  List of databases
      Name    |  Owner  | Encoding |  Collate   |   Ctype    |  Access privileges  
   -----------+---------+----------+------------+------------+---------------------
    mlserving | pgadmin | UTF8     | en_US.utf8 | en_US.utf8 | 
    pgadmin   | pgadmin | UTF8     | en_US.utf8 | en_US.utf8 | 
    postgres  | pgadmin | UTF8     | en_US.utf8 | en_US.utf8 | 
    template0 | pgadmin | UTF8     | en_US.utf8 | en_US.utf8 | =c/pgadmin         +
              |         |          |            |            | pgadmin=CTc/pgadmin
    template1 | pgadmin | UTF8     | en_US.utf8 | en_US.utf8 | =c/pgadmin         +
              |         |          |            |            | pgadmin=CTc/pgadmin
   (5 rows)
   
   * Done. Exiting...
   ```
   
8. Run script **05-deployAdsMlService.sh***
   
   Sample script output
   
   ```
   ./05-deployAdsMlService.sh 
   
   * Found 01-parametersForAdsMlService.sh. Reading in variables from that script.
       Reading 01-parametersForAdsMlService.sh ...
   * Done!
   
   * Project <your-ibm-ads-ml-service-project> exists. Switching to it...
   Already on project "<your-ibm-ads-ml-service-project>" on server "https://<hostname>:<port>".
   
   * Deploying the ads ml service config map...
   configmap/ads-ml-service-model-conf created
   
   Deploying the ads ml service deployment...
   deployment.apps/ads-ml-service-deployment created
   
   Deploying the ads ml service service...
   service/ads-ml-service-service created
   
   Exposing the ads ml service service...
   route.route.openshift.io/ads-ml-service-service exposed
   
   Deploying the network policy...
   networkpolicy.networking.k8s.io/ads-ml-service-policy created
   
   * Done. Exiting...
   ```

9. Verify that the pods are Running and Ready
   
   ```
   oc get pods
   NAME                                         READY   STATUS    RESTARTS   AGE
   ads-ml-service-deployment-7cd9b7c785-6ljdz   1/1     Running   0          112s
   postgres-fc54f76dd-sfb6r                     1/1     Running   0          20m
   ```

## What to do next

- If you want to enable the **logging infrastructure**, please complete as a next step **[Step 8: Optional: Setup OpenShift Logging Stack](08setupLogging.md)**
- If you want to enable the **monitoring infrastructure**, please complete as a next step **[Step 9: Optional: Setup OpenShift Monitoring Stack](09setupMonitoring.md)**
- Optionally, you can complete **[Step 10: Optional: Create new VM for RPA  &  install IBM RPA](10createVMForRPA.md)**
- Optionally, you can complete **[Step 11: Optional: Scale up the deployment](11scaleUp.md)**
- **[Here](Readme.md)** you can get back to the overview page

Issues or questions? IBMers can use this IBM internal Slack channel: **#dba-swat-asset-qna** (**https://ibm-cloud.slack.com/archives/C026TD1SGCA**)

Everyone else can open a new issue in this github.
