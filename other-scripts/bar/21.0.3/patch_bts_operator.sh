#!/bin/sh

bts_csv=$(oc get csv -o custom-columns=name:.metadata.name | grep bts)

if [ "$bts_csv" == "" ]; then
   echo "bts cluster service version does not yet exist, please wait"
   exit 1
fi

bts_memory=$(oc get csv $bts_csv -o 'jsonpath={.spec.install.spec.deployments[0].spec.template.spec.containers[0].resources.limits.memory}')

if [ "$bts_memory" == "600Mi" ]; then
   echo "BTS operator memory already set to $bts_memory"
   exit 1
fi

echo "BTS operator memory set to $bts_memory, updating it..."

oc patch csv $bts_csv --type='json' -p='[{"op": "replace", "path": "/spec/install/spec/deployments/0/spec/template/spec/containers/0/resources/limits/memory", "value": "600Mi"}, {"op": "replace", "path": "/spec/install/spec/deployments/0/spec/template/spec/containers/0/resources/requests/memory", "value": "600Mi"}]' 


