#!/bin/sh

bts_secrets=$(oc get secrets -o name | grep bts)

for s in $bts_secrets; do
  if [[ $s == secret/ibm-bts-sa-dockercfg-* ]];then
    if [[ $s == secret/ibm-bts-sa-dockercfg-f6thh ]];then
      echo "Skipping" $s
    else
      oc delete $s
    fi
  elif [[ $s == secret/ibm-bts-sa-token-* ]];then
    if [[ $s == secret/ibm-bts-sa-token-pw292 ]];then
      echo "Skipping" $s
    else
      oc delete $s
    fi
  fi
done
