# Step 1: Create your IBM Cloud Account (or use existing)

![Overview](images/overview01.jpg "Overview")

1. First, secure the funding for the infrastructure
   - You’ll need ~$300 as a minimum for a small cluster (replica size of 1, means no HA) for ~one week, e.g. for a Customer Demo, Foundation and Content only

2. Check your entitlement on **https://myibm.ibm.com/products-services/containerlibrary**
   - Under **View library** check that you are entitled for **IBM Cloud Pak for Business Automation** (IBMers will see **IBM SOFTWARE ACCESS 1 YEAR - all**)
   - Copy your entitlement key (you will need it later multiple times while the deployment)

3. Access **https://cloud.ibm.com** with your IBM ID
   - IBMers can use their w3 ID

4. Optional: Complete your profile for your own account if needed

5. Optional: In case you plan to run the Infrastructure under another account, swicht to that account
   
   ![Select Account](images/selectAccount.jpg "Select Account")

6. Assign your entitlement key for discount on the OCP cluster (CP4BA license includes a license for OCP)
   - On the top, click **Manage -> Account**
     
     ![Manage Account](images/applyLicense01.jpg "Manage Account")
     
   - On the left-hand side click **Licenses and entitlements**, then click **Assign**
   - Select the CP4BA license and assign it to the account (needed for discount on the OpenShift cluster)
     
     ![Apply License](images/applyLicense02.jpg "Apply License")

## What to do next

Your IBM Cloud account is ready for the next step: **[Step 2: Create new RedHat OpenShift Cluster](02createRedHatOpenShiftCluster.md)**

**[Here](Readme.md)** you can get back to the overview page

Issues or questions? IBMers can use this IBM internal Slack channel: **#dba-swat-asset-qna** (**https://ibm-cloud.slack.com/archives/C026TD1SGCA**)

Everyone else can open a new issue in this github.
