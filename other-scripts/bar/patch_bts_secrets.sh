#!/bin/sh

# Latest set of secrets to keep, must be set before running this script
dockercfgToKeep=		# for example secret/ibm-bts-sa-dockercfg-f6thh
tokenToKeep=			# for example secret/ibm-bts-sa-token-pw292

if [[ -z $dockercfgToKeep ]] || [[ -z $tokenToKeep ]]; then
  echo "Please set dockercfgToKeep and tokenToKeep!"
  exit 0
fi

bts_secrets=$(oc get secrets -o name | grep bts)

for s in $bts_secrets; do
  if [[ $s == secret/ibm-bts-sa-dockercfg-* ]];then
    if [[ $s == $dockercfgToKeep ]];then
      echo "Skipping" $s
    else
      oc delete $s
    fi
  elif [[ $s == secret/ibm-bts-sa-token-* ]];then
    if [[ $s == $tokenToKeep ]];then
      echo "Skipping" $s
    else
      oc delete $s
    fi
  fi
done
