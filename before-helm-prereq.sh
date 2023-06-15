#!/bin/bash

PIPELINES_INSTALLED=$(oc get csv -n openshift-operators | grep openshift-pipelines)
GITOPS_INSTALLED=$(oc get csv -n openshift-operators | grep openshift-gitops)

if [[ $PIPELINES_INSTALLED == *"Succeeded"* ]]; then
  echo "OpenShift Pipelines is installed!"
else
  echo "OpenShift Pipelines is not installed."
  echo "Installing openshift pipelines..."

  read -r -d '' YAML_CONTENT <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/openshift-pipelines-operator-rh.openshift-operators: ""
  name: openshift-pipelines-operator-rh
  namespace: openshift-operators
spec:
  channel: latest
  installPlanApproval: Automatic
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

  # Apply the inline YAML using 'oc apply'
  echo "$YAML_CONTENT" | oc apply -f -
  
  $(oc wait --for=condition=initialized --timeout=60s pods -l app=openshift-pipelines-operator -n openshift-operators)
fi


