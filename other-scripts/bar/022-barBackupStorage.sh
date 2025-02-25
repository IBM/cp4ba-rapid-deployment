#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2025. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# This script is for preparing the Backup And Restore (BAR) process, performing backup on all CP4BA components in the given namespace.
#    Only tested with CP4BA version: 21.0.3 IF034, dedicated common services set-up

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import common utilities
source ${CUR_DIR}/common.sh
DATETIMESTR=$(date +'%Y%m%d_%H%M%S')

INPUT_PROPS_FILENAME="001-barParameters.sh"
INPUT_PROPS_FILENAME_FULL="${CUR_DIR}/${INPUT_PROPS_FILENAME}"
echo

if [[ -f $INPUT_PROPS_FILENAME_FULL ]]; then
   echo "Found ${INPUT_PROPS_FILENAME}. Reading in variables from that script."
   
   . $INPUT_PROPS_FILENAME_FULL
   
   if [ $cp4baProjectName == "REQUIRED" ]; then
      echo "File ${INPUT_PROPS_FILENAME} not fully updated. Pls. update all REQUIRED parameters."
      echo
      exit 1
   fi

   echo "Done!"
else
   echo "File ${INPUT_PROPS_FILENAME_FULL} not found. Pls. check."
   echo
   exit 1
fi

echo -e "\x1B[1mThis script will generate a script to backup the persistent volumes used by CP4BA environment deployed in ${cp4baProjectName}.\n \x1B[0m"

printf "Do you want to continue? (Yes/No, default: No): "
read -rp "" ans
case "$ans" in
"y"|"Y"|"yes"|"Yes"|"YES")
   echo
   echo -e "Generating the backup script for persistent volumes in namespace ${cp4baProjectName}..."
   ;;
*)
   echo
   echo -e "Exiting..."
   echo
   exit 0
   ;;
esac

BACKUP_ROOT_DIRECTORY_FULL="${CUR_DIR}/${cp4baProjectName}"
if [[ -d $BACKUP_ROOT_DIRECTORY_FULL ]]; then
   echo
else
   echo
   mkdir "$BACKUP_ROOT_DIRECTORY_FULL"
fi

LOG_FILE="$BACKUP_ROOT_DIRECTORY_FULL/Backup_${DATETIMESTR}.log"
logInfo "Details will be logged to $LOG_FILE."
echo



##### Preparation ##############################################################
# Verify OCP Connecction
logInfo "Verifying OC CLI is connected to the OCP cluster..."
WHOAMI=$(oc whoami)
logInfo "WHOAMI =" $WHOAMI

if [[ "$WHOAMI" == "" ]]; then
   logError "OC CLI is NOT connected to the OCP cluster. Please log in first with an admin user to OpenShift Web Console, then use option \"Copy login command\" and log in with OC CLI, before using this script."
   echo
   exit 1
fi
echo

# switch to CP4BA project
project=$(oc project --short)
logInfo "project =" $project
if [[ "$project" != "$cp4baProjectName" ]]; then
   logInfo "Switching to project..."
   logInfo $(oc project $cp4baProjectName)
fi
echo

# Create the backup script header

cat > 023-backup-pvs.sh <<EOF
#!/bin/bash

// Assisted by watsonx Code Assistant 
function perform_backup() {
    namespace=\$1
    policy=\$2
    volumename=\$3
    claimname=\$4

    if [ "\$policy" == "nfs-client" ]; then
        echo "Backing up PVC \$claimname"
        directory="/export/\${namespace}-\${claimname}-\${volumename}"
        if [ -d "\$directory" ]; then
            (cd \$directory; tar cfz \$pvBackupDirectory/\${claimname}.tgz .)
        else
            echo "*** Error: Did not find persistent volume data in directory \$directory"
        fi
    else
        echo "*** Error: Dont know how to backup storage policy named \$policy"
    fi
}

pvBackupDirectory="${pvBackupDirectory}/${DATETIMESTR}"

mkdir -p \$pvBackupDirectory

EOF

# Iterate over all persistent volume claims in the project
oc get pvc -n $cp4baProjectName -o 'custom-columns=ns:.metadata.namespace,class:.spec.storageClassName,pv:.spec.volumeName,name:.metadata.name' --no-headers | sed 's/^/perform_backup /g' >> 023-backup-pvs.sh

echo "Run the generated backup script 023-backup-pvs.sh on the storage server to backup the persistent volumes"

