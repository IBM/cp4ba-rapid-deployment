# Step 0: Select the CP4BA template for deployment

This project provides you the following CP4BA templates to select from:

- **[Client Onboarding Demo with ADP](#template-for-the-client-onboarding-demo-with-adp)** (ibm_cp4a_cr_template.200.ent.ClientOnboardingDemoWithADP.yaml)

- **[Foundation only](#foundation-only)** (ibm_cp4a_cr_template.001.ent.Foundation.yaml)
- **[Foundation, Content](#foundation-content)** (ibm_cp4a_cr_template.002.ent.FoundationContent.yaml)

All these templates are tested on IBM Cloud / ROKS. In addition, you can create your own template if needed.

## Template for the Client Onboarding Demo with ADP

**Name:**
- ibm_cp4a_cr_template.200.ent.ClientOnboardingDemoWithADP.yaml

**CP4BA deployment patterns included:**
- foundation
  - IAF (IBM Automation Foundation) components needed, for example IBM Event Streams
  - RR (Resource Registry)
  - BTS (Business Teams Service)
  - BAS (Business Automation Studio)
  - AE (Application Engine, data persistence enabled)
  - BAN (Business Automation Navigator)
  - BAI (Business Automation Insights)
- content
  - CPE (Content Platform Engine)
  - GraphQL (Content Services GraphQL)
  - CSS (Content Search Services)
  - CMIS (Content Management Interoperability Services)
- application
  - Application Designer
- decisions_ads
  - ADS (Automation Decision Services)
    - Decision Designer
    - Decision Runtime
- workflow
  - Workflow Authoring
    - Workflow Authoring Server (JMS included)
    - PFS (Process Federation Server)
    - Elasticsearch
  - BAML (Business Automation Machine Learning Server)
    - ITP (Intelligent Task Prioritization)
    - WFI (Workforce Insights)
- document_processing
  - ADP (Automation Document Processing)
    - Document Processing Designer
    - Content Analyzer

**VM for LDAP needed:**
- LDAP needed: Yes

**DB2 needed / license / resources:**
- DB2 needed: Yes
- DB2 Standard license: Required / strongly recommended
- CPU for DB2: 16
- RAM for DB2: 110Gi

**OCP Cluster sizing:**
- Minimum configuration (no High-Availabilty, select a replica size of 1, e.g., for Demo only purposes)
  - Three worker nodes with 32 CPUs and 64Gi RAM (e.g., flavor c3c.32x64 on ROKS)
  - One db2 worker node with 32 CPUs and 128Gi RAM (e.g., flavor b3c.32x128 on ROKS)
- Configuration used while CP4BA Tech Jams (replica size of 2, e.g., for > 10 participants)
  - Add one additional worker node with 32 CPUs and 64Gi RAM

**[What to do next](#what-to-do-next)**

## Foundation only

**Name:**
- ibm_cp4a_cr_template.001.ent.Foundation.yaml

**CP4BA deployment patterns included:**
- foundation
  - IAF (IBM Automation Foundation) components needed
  - RR (Resource Registry)
  - BAN (Business Automation Navigator)

**VM for LDAP needed:**
- LDAP needed: Yes

**DB2 needed / license / resources:**
- DB2 needed: Yes
- DB2 Standard license: not needed (DB2 Community Edition license is sufficient)
- CPU for DB2: 4
- RAM for DB2: 16Gi

**OCP Cluster sizing:**
- Minimum configuration (no High-Availabilty, select a replica size of 1)
  - Three worker nodes with 16 CPUs and 32Gi RAM
- Same configuration can be used when you want to use a higher replica size, e.g., 2

**[What to do next](#what-to-do-next)**

## Foundation, Content

**Name:**
- ibm_cp4a_cr_template.002.ent.FoundationContent.yaml

**CP4BA deployment patterns included:**
- foundation
  - IAF (IBM Automation Foundation) components needed
  - RR (Resource Registry)
  - BAN (Business Automation Navigator)
- content
  - CPE (Content Platform Engine)
  - GraphQL (Content Services GraphQL)
  - CSS (Content Search Services)
  - CMIS (Content Management Interoperability Services)

**VM for LDAP needed:**
- LDAP needed: Yes

**DB2 needed / license / resources:**
- DB2 needed: Yes
- DB2 Standard license: not needed (DB2 Community Edition license is sufficient)
- CPU for DB2: 4
- RAM for DB2: 16Gi

**OCP Cluster sizing:**
- Minimum configuration (no High-Availabilty, select a replica size of 1)
  - Three worker nodes with 16 CPUs and 32Gi RAM
- Configuration when you want to use a higher replica size, e.g., 2
  - Add one additional worker node with 16 CPUs and 32Gi RAM

**[What to do next](#what-to-do-next)**

## What to do next

Now that you selected a template and know the resource and other requirements, you can proceed with **[Step 1: Create your IBM Cloud Account (or use existing)](01createIBMCloudAccount.md)**

**If you plan to not use IBM Cloud / ROKS complete the following steps:**
- Install / create your own OpenShift cluster (or use existing)
- Install LDAP (or use existing)
- Proceed with **[Step 4: Deploy IBM DB2 Containers  &  create needed databases](04deployIBMDB2.md)**

**[Here](Readme.md)** you can get back to the overview page

Issues or questions? IBMers can use this IBM internal Slack channel: **#dba-swat-asset-qna** (**https://ibm-cloud.slack.com/archives/C026TD1SGCA**)

Everyone else can open a new issue in this github.
