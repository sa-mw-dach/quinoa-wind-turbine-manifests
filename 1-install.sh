#!/bin/bash

# --- OpenShift Pipelines -----------------------------------------------------
PIPELINES_INSTALLED=$(oc get csv -n openshift-operators | grep openshift-pipelines)

if [[ $PIPELINES_INSTALLED == *"Succeeded"* ]]; then
  echo "✅ OpenShift Pipelines"
else
  echo "Installing openshift pipelines..."

  read -r -d '' YAML_CONTENT <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-pipelines-operator-rh 
  source: redhat-operators 
  sourceNamespace: openshift-marketplace 
EOF
  # Apply the inline YAML using 'oc apply'
  echo "$YAML_CONTENT" | oc apply -f -
  
  oc wait --for=condition=initialized --timeout=60s pods -l app=openshift-pipelines-operator -n openshift-operators
fi

# --- OpenShift GitOps --------------------------------------------------------
GITOPS_INSTALLED=$(oc get csv -n openshift-operators | grep openshift-gitops)

if [[ $GITOPS_INSTALLED == *"Succeeded"* ]]; then
  echo "✅ OpenShift GitOps"
else
  echo "Installing OpenShift GitOps..."

  read -r -d '' YAML_CONTENT <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest 
  installPlanApproval: Automatic
  name: openshift-gitops-operator 
  source: redhat-operators 
  sourceNamespace: openshift-marketplace 
EOF

  # Apply the inline YAML using 'oc apply'
  echo "$YAML_CONTENT" | oc apply -f -
  
  echo "Workaround: Sleep for 3 seconds until roles and service accounts are available"
  sleep 3
  $(oc adm policy add-cluster-role-to-user cluster-admin -z openshift-gitops-argocd-application-controller -n openshift-gitops)
  oc wait --for=condition=initialized --timeout=60s pods -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops
fi

# --- OpenShift Streams -------------------------------------------------------
STREAMS_INSTALLED=$(oc get csv -n openshift-operators | grep amqstreams)
if [[ $STREAMS_INSTALLED == *"Succeeded"* ]]; then
  echo "✅ OpenShift Streams"
else
  echo "Installing OpenShift streams..."

  read -r -d '' YAML_CONTENT <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/amq-streams.openshift-operators: ""
  name: amq-streams
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: amq-streams
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: amqstreams.v2.4.0-0
EOF
  echo "$YAML_CONTENT" | oc apply -f -
  oc wait --for=condition=initialized --timeout=60s pods -l name=amq-streams-cluster-operator -n openshift-operators
fi

# --- Bitnami Sealed Secrets -------------------------------------------------------
SEALEDSECRETS_INSTALLED=$(oc get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets | grep sealed-secrets)

if [[ $SEALEDSECRETS_INSTALLED == *"Running"* ]]; then
  echo "✅ Bitnami Sealed Secrets"
else
  echo "Installing Sealed Secrets ..."
  
  $(helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets)
  $(helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets)
  # $(oc create -f 'https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.22.0/controller.yaml')
  oc wait --for=condition=initialized --timeout=60s pods -l app.kubernetes.io/name=sealed-secrets -n kube-system
fi

# --- Stakater Reloader (for redeploy at changed secrets) -------------------------------------------------------
RELOADER_INSTALLED=$(helm status reloader -n reloader | grep "STATUS:")

if [[ $RELOADER_INSTALLED == *"deployed"* ]]; then
  echo "✅ Stakater Reloader"
else
  echo "Installing Reloader ..."
  
  $(helm repo add stakater https://stakater.github.io/stakater-charts)
  $(helm repo update)

  $(oc new-project reloader)
  $(helm install reloader stakater/reloader -n reloader --set reloader.isOpenshift=true --set reloader.deployment.securityContext.runAsUser=null)
  oc wait --for=condition=initialized --timeout=60s pods -l app=reloader-reloader -n reloader
fi

# --- install namespaces ---
NAMESPACE_DEV_EXISTS=$(oc projects | grep gitops-demo-dev)
if [[ $NAMESPACE_DEV_EXISTS == *"dev"* ]]; then
  echo "✅ Namespace dev"
else
  echo "Creating namespace dev"
  $(oc new-project gitops-demo-dev)
fi

NAMESPACE_STAGE_EXISTS=$(oc projects | grep gitops-demo-stage)
if [[ $NAMESPACE_STAGE_EXISTS == *"stage"* ]]; then
  echo "✅ Namespace stage"
else
  echo "Creating namespace stage"
  $(oc new-project gitops-demo-stage)
fi

NAMESPACE_PROD_EXISTS=$(oc projects | grep gitops-demo-prod)
if [[ $NAMESPACE_PROD_EXISTS == *"prod"* ]]; then
  echo "✅ Namespace prod"
else
  echo "Creating namespace prod"
  $(oc new-project gitops-demo-prod)
fi

# --- pipeline preparation
# install needed secrets
DEV_SECRETS=$(oc get secret -n gitops-demo-dev)
STAGE_SECRETS=$(oc get secret -n gitops-demo-stage)

if [[ $DEV_SECRETS == *"git-user-pass"* ]]; then
  echo "✅ GitHub secret exists on dev"
else
  echo "GitHub secret will be created in dev namespace"
  oc apply -f 0-github-secret.yaml -n gitops-demo-dev
fi

if [[ $STAGE_SECRETS == *"git-user-pass"* ]]; then
  echo "✅ GitHub secret exists on stage"
else
  echo "GitHub secret will be created in stage namespace"
  oc apply -f 0-github-secret.yaml -n gitops-demo-stage
fi

if [[ $DEV_SECRETS == *"quay"* ]]; then
  echo "✅ Quay secret exists on dev"
else
  echo "Quay secret will be created in dev namespace"
  oc apply -f 0-quay-secret.yaml -n gitops-demo-dev
fi

if [[ $STAGE_SECRETS == *"quay"* ]]; then
  echo "✅ Quay secret exists on stage"
else
  echo "Quay secret will be created in stage namespace"
  oc apply -f 0-quay-secret.yaml -n gitops-demo-stage
fi

# --- Service Account of pipelines linking to needed account info
SERVICE_ACCOUNT_LINKED_SECRETS_DEV=$(oc get sa pipeline -o jsonpath='{.secrets}' -n gitops-demo-dev)
if [[ $SERVICE_ACCOUNT_LINKED_SECRETS_DEV == *"git-user-pass"* ]]; then
  echo "✅ ServiceAccount link to github on dev"
else
  oc secret link pipeline git-user-pass -n gitops-demo-dev
fi

if [[ $SERVICE_ACCOUNT_LINKED_SECRETS_DEV == *"quay-push-secret"* ]]; then
  echo "✅ ServiceAccount link to quay on dev"
else
  oc secret link pipeline quay-push-secret -n gitops-demo-dev
fi

SERVICE_ACCOUNT_LINKED_SECRETS_STAGE=$(oc get sa pipeline -o jsonpath='{.secrets}' -n gitops-demo-stage)
if [[ $SERVICE_ACCOUNT_LINKED_SECRETS_STAGE == *"git-user-pass"* ]]; then
  echo "✅ ServiceAccount link to github on stage"
else
  oc secret link pipeline git-user-pass -n gitops-demo-stage
fi

if [[ $SERVICE_ACCOUNT_LINKED_SECRETS_STAGE == *"quay-push-secret"* ]]; then
  echo "✅ ServiceAccount link to quay on stage"
else
  oc secret link pipeline quay-push-secret -n gitops-demo-stage
fi

# --- Deploy applicaton secret
SECRET_FOR_APP_ON_DEV=$(oc get secret -n gitops-demo-dev)
if [[ $SECRET_FOR_APP_ON_DEV == *"quinoa-wind-turbine"* ]]; then
  echo "✅ Secret for application on dev"
else
  echo "Secret for application on dev must be created"
  helm template helm -n gitops-demo-dev --set disableSecretsDeployment=false -s templates/env/gitops-demo-dev/secret.yaml | kubeseal -n gitops-demo-dev - > stages/dev/sealedsecret.yaml
  oc apply -f stages/dev/sealedsecret.yaml
fi

SECRET_FOR_APP_ON_STAGE=$(oc get secret -n gitops-demo-stage)
if [[ $SECRET_FOR_APP_ON_STAGE == *"quinoa-wind-turbine"* ]]; then
  echo "✅ Secret for application on stage"
else
  echo "Secret for application on stage must be created"
  helm template helm -n gitops-demo-stage --set disableSecretsDeployment=false -s templates/env/gitops-demo-stage/secret.yaml | kubeseal -n gitops-demo-stage - > stages/stage/sealedsecret.yaml
  oc apply -f stages/stage/sealedsecret.yaml
fi

SECRET_FOR_APP_ON_DEV=$(oc get secret -n gitops-demo-prod)
if [[ $SECRET_FOR_APP_ON_DEV == *"quinoa-wind-turbine"* ]]; then
  echo "✅ Secret for application on prod"
else
  echo "Secret for application on prod must be created"
  helm template helm -n gitops-demo-prod --set disableSecretsDeployment=false -s templates/env/gitops-demo-prod/secret.yaml | kubeseal -n gitops-demo-prod - > stages/prod/sealedsecret.yaml
  oc apply -f stages/prod/sealedsecret.yaml
fi

# rollout!
oc apply -f wind-turbine-app.yaml

sh 2-show-event-listener-routes.sh