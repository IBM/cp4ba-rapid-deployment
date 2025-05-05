To have BAI working properly, re-start the Flink jobs:

Open Terminal

Log in to oc CLI

Run these commands:

oc get job mycluster-bai-bpmn -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | oc replace --force -f - 

oc get job mycluster-bai-icm -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | oc replace --force -f -

oc get job mycluster-bai-content -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | oc replace --force -f -

Run the health check script to make sure the deployment is healthy now, fix all remaining issues

Get the yq tool:

sudo wget https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
