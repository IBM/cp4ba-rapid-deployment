#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2024. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# This script is for preparing the JiaB environment on TechZone before being able to use it. It downloads the latest version of the real script from the rapid-deployment-github and executes it.
#    CP4BA version: 23.0.2 IF002
#    CP4BA template used for deployment: ibm_cp4a_cr_template.201.ent.ClientOnboardingDemoWithADPOneDB.yaml

git clone --depth 1 --no-checkout https://github.com/IBM/cp4ba-rapid-deployment.git
cd cp4ba-rapid-deployment
git sparse-checkout set other-scripts/JiaB/mt-23-0-2
git checkout

cd other-scripts/JiaB/mt-23-0-2
./301-prepareJiaB4shutdown.sh

cd ../../../..
rm -r -f cp4ba-rapid-deployment
