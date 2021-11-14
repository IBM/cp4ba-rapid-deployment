# Step 11: Optional: Scale up the deployment

In case High-Availability of the deployment is needed and you initially deployed the environment with replicaSize=1, scale up of the various components is needed:

1. RedHat OpenShift Cluster: You might need to add additional worker nodes by increasing the default (e.g., c3c.32x64) worker pool accoring to the OCP Cluster sizing of your selected CP4BA template:

2. LDAP: No scale up needed for Demo & Lab purposes

3. DB2: No scale up needed for Demo & Lab purposes

4. CP4BA: Scale up by using the scripts
   
   - Switch to folder deployment-db2-cp4ba
   - Update properties file `05-parametersForCp4ba.sh` (set parameters cp4baReplicaCount and cp4baBaiJobParallelism to e.g. `2`)
   - Run script `07-createCp4baDeployment.sh` to only re-generate CR YAML (needs entitlement key, when asked to CREATE the CP4BA deployment now, select **No** - by that the YAML files e.g. ibm_cp4a_cr_final.yaml will only get re-created, not applied)
   - In case for some pods a higher replica size is needed, change that in the generated CR YAML manually (for example increase the parameter `replicas` inside `workflow_authoring_configuration` to e.g. `3`)
   - Update CP4BA deployment by running command `oc apply -f ibm_cp4a_cr_final.yaml --overwrite=true`

5. ADS ML Service: Scale up to `2` replicas through OCP Web Console (increase the amout of pods of deployment `ads-ml-service-deployment`)

6. RPA: No scale up needed for Demo & Lab purposes

With that, you have successfully set up your own infrastructure. Congratulations!

## What to do next

You now can proceed to import the Client Onboarding solution as documented in **[this GitHub repo](https://github.com/IBM/cp4ba-client-onboarding-scenario)**

**[Here](Readme.md)** you can get back to the overview page

Issues or questions? IBMers can use this IBM internal Slack channel: **#dba-swat-asset-qna** (**https://ibm-cloud.slack.com/archives/C026TD1SGCA**)

Everyone else can open a new issue in this github.
