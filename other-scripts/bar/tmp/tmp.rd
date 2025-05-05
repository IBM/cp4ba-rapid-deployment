oc apply -f cr-ibm-cp4ba-qa.yaml



While the deployment, once postgress operator is there, apply the following fix:
oc annotate secret postgresql-operator-controller-manager-config  ibm-bts/skip-updates="true"
oc get job create-postgres-license-config -o yaml | sed -e 's/operator.ibm.com\/opreq-control: "true"/operator.ibm.com\/opreq-control: "false"/' -e 's|\(image: \).*|\1"cp.icr.io/cp/cpd/edb-postgres-license-provider@sha256:c1670e7dd93c1e65a6659ece644e44aa5c2150809ac1089e2fd6be37dceae4ce"|' -e '/controller-uid:/d' | oc replace --force -f - && oc wait --for=condition=complete job/create-postgres-license-config



Finally:
--------
- Create all needed bookmarks in FF
- Cleanup the system
