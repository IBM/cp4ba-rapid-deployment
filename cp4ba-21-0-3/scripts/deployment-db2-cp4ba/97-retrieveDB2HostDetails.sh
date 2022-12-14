#! /bin/bash -e
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

. ./common-ocp-utils.sh
. ./01-parametersForDb2OnOCP.sh > /dev/null

echo
echo "Use this hostname/IP to access the databases e.g. with IBM Data Studio."
routerCanonicalHostname=$(oc get route console -n openshift-console -o yaml | grep routerCanonicalHostname | cut -d ":" -f2)
workerNodeAddresses=$(get_worker_node_addresses_from_pod c-db2ucluster-db2u-0 $db2OnOcpProjectName)
echo -e "\tHostname:${routerCanonicalHostname}"
echo -e "\tOther possible addresses(If hostname not available above): $workerNodeAddresses"

echo
echo "Use one of these NodePorts to access the databases e.g. with IBM Data Studio (usually the first one is for legacy-server (Db2 port 50000), the second for ssl-server (Db2 port 50001))."
oc get svc -n ${db2OnOcpProjectName} c-db2ucluster-db2u-engn-svc -o json | grep nodePort

echo
echo "Use \"$db2AdminUserName\" and password \"$db2AdminUserPassword\" to access the databases e.g. with IBM Data Studio."
