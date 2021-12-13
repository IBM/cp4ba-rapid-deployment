# Step 6: Optional: Install the Process Mining Operator & deploy Process Mining

![Overview](images/overview06.jpg "Overview")

1. Switch to the directory with the deployment scripts for CP4BA and DB2.

   ```
   cd /cp4ba/cp4ba-rapid-deployment/cp4ba-21-0-2/<your-cluster-name>/deployment-db2-cp4ba
   ```
   
2. Make sure you have configured the following variables in `05-parametersForCp4ba.sh`:
   - `cp4baProjectname`, e.g. `ibm-cp4ba`
   - `cp4baReplicaCount`, e.g. `1`
   
3. Run script `21-deployProcessMiningOperator.sh`, it will deploy Process Mining Operator.

   Sample script output:
   
   ```
   ./21-deployProcessMiningOperator.sh 
   
   Found 05-parametersForCp4ba.sh.  Reading in variables from that script.
     Reading 05-parametersForCp4ba.sh ...
   Done!
   
   This script deploys IBM Process Mining operator. 
    
   Is 05-parametersForCp4ba.sh up to date, and do you want to continue? (Yes/No, default: No): y
   
   Preparing the Process Mining operator...
   
   Switching to project ibm-cp4ba...
   Already on project "ibm-cp4ba" on server "https://ocp.example.com".
   Preparing the subscription...
   
   Creating operator subscription...
   subscription.operators.coreos.com/processmining-subscription created
   Done.
   
   All changes got applied. Exiting...

   ```
   
4. Wait untill the Operator and all dependant Operators got installed.

5. Run script `22-deployProcessMining.sh`, it will deploy Process Mining.

   Sample script output:
   ```
   ./22-deployProcessMining.sh 
   
   Found 05-parametersForCp4ba.sh.  Reading in variables from that script.
     Reading 05-parametersForCp4ba.sh ...
   Done!
   
   This script deploys IBM Process Mining. 
    
   Is 05-parametersForCp4ba.sh up to date, and do you want to continue? (Yes/No, default: No): y
   
   Preparing the Process Mining ...
   
   Switching to project ibm-cp4ba...
   Already on project "ibm-cp4ba" on server "https://ocp.example.com".
   
   
   Deploying Process Mining...
   processmining.processmining.ibm.com/processmining created
   Done.
   
   All changes got applied. Exiting...

   ```
   
6. Verify the pods are running and ready.

   ```
   oc get pods |grep processmining
   processmining-analytics-698b4d7cc9-brq2l                          1/1     Running     0          24m
   processmining-bpa-66c795c6c4-pd9mv                                1/1     Running     0          24m
   processmining-connectors-67f7db74bd-2g8xt                         1/1     Running     0          24m
   processmining-dr-7b86d9887d-6fqgt                                 1/1     Running     0          24m
   processmining-engine-658dbd5c6-jv87h                              1/1     Running     0          24m
   processmining-mongo-db-5c6b8b44f6-xdbvr                           1/1     Running     0          28m
   processmining-mysql-6cbcf578df-gpklq                              1/1     Running     0          28m
   processmining-operator-controller-manager-6f468d5b7c-hbc5f        1/1     Running     0          31m
   processmining-processmining-nginx-686969c4c8-9h77q                1/1     Running     0          28m
   processmining-processmining-um-958445d7f-4ff4s                    1/1     Running     0          24m
   processmining-taskbuilder-6469779f77-kvgl7                        1/1     Running     0          19m
   processmining-taskminer-nginx-6b5ff9c6c6-k4nmv                    2/2     Running     0          22m
   processmining-taskprocessor-7cdbf5668b-p86bz                      1/1     Running     0          19m
   ```
   
7. Grant users Automation Analyst role so that they can use Process Mining (if not done previously as part of Step 5).

   Open cpd route, log on with an admin user (e.g. `cp4badmin`). Click `Manage Users`, then switch to `User groups` tab, click `cp4bausers` group. Click `Roles` tab and assign `Automation Analyst` role to this group.
   
## What to do next

- If you are deploying the Client Onboarding template and want to use the **Machine Learning Service for ADS**, please complete as a next step **[Step 7: Optional: Deploy Machine Learning Service for ADS](07deployMLService4ADS.md)**
- If you want to enable the **logging infrastructure**, please complete as a next step **[Step 8: Optional: Setup OpenShift Logging Stack](08setupLogging.md)**
- If you want to enable the **monitoring infrastructure**, please complete as a next step **[Step 9: Optional: Setup OpenShift Monitoring Stack](09setupMonitoring.md)**
- Optionally, you can complete **[Step 10: Optional: Create new VM for RPA  &  install IBM RPA](10createVMForRPA.md)**
- Optionally, you can complete **[Step 11: Optional: Scale up the deployment](11scaleUp.md)**
- **[Here](Readme.md)** you can get back to the overview page

Issues or questions? IBMers can use this IBM internal Slack channel: **#dba-swat-asset-qna** (**https://ibm-cloud.slack.com/archives/C026TD1SGCA**)

Everyone else can open a new issue in this github.
