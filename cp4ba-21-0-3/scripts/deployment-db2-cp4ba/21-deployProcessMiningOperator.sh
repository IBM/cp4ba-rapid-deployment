#!/bin/bash
# set -x
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

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CP4BA_INPUT_PROPS_FILENAME="05-parametersForCp4ba.sh"
CP4BA_INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${CP4BA_INPUT_PROPS_FILENAME}"

if [[ -f $CP4BA_INPUT_PROPS_FILENAME_FULL ]]; then
   echo
   echo "Found ${CP4BA_INPUT_PROPS_FILENAME}.  Reading in variables from that script."
   . $CP4BA_INPUT_PROPS_FILENAME_FULL

   if [ $cp4baProjectName == "REQUIRED" ] ; then
      echo "File ${CP4BA_INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 0
   fi

   echo "Done!"
else
   echo
   echo "File ${CP4BA_INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 0
fi

echo
echo -e "\x1B[1mThis script deploys IBM Process Mining operator. \n \x1B[0m"

printf "Is ${CP4BA_INPUT_PROPS_FILENAME} up to date, and do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
    echo
    echo -e "Preparing the Process Mining operator..."
    ;;
*)
    echo
    echo -e "Exiting..."
    echo
    exit 0
    ;;
esac

echo
echo "Switching to project ${cp4baProjectName}..."
oc project $cp4baProjectName

echo
echo "Installing the CatalogSource for Process Mining..."
oc apply -f processminingOperatorCatalog.yaml

echo
echo "Preparing the subscription..."
cp processmining-subscription.template.yaml processmining-subscription.yaml
sed -i.bak "s|cp4baProjectName|$cp4baProjectName|g" processmining-subscription.yaml

echo
echo "Creating operator subscription..."
oc apply -f processmining-subscription.yaml
rm processmining-subscription.yaml.bak
echo "Done."


echo
echo "All changes got applied. Exiting..."
echo
