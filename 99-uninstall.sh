#!/bin/bash

echo "🚫 Delete OpenShift GitOps ApplicationSet"
oc delete -f wind-turbine-app.yaml
echo "🚫 Delete Sealed Secrets"
oc delete -f stages/dev/sealedsecret.yaml
oc delete -f stages/stage/sealedsecret.yaml
oc delete -f stages/prod/sealedsecret.yaml
echo "🚫 Unlink Secrets"
oc secret unlink pipeline git-user-pass -n gitops-demo-dev
oc secret unlink pipeline git-user-pass -n gitops-demo-stage
oc secret unlink pipeline git-user-pass -n gitops-demo-prod
oc secret unlink pipeline quay-push-secret -n gitops-demo-dev
oc secret unlink pipeline quay-push-secret -n gitops-demo-stage
oc secret unlink pipeline quay-push-secret -n gitops-demo-prod
echo "🚫 Delete Secrets"
oc delete -f 0-github-secret.yaml -n gitops-demo-dev
oc delete -f 0-github-secret.yaml -n gitops-demo-stage
oc delete -f 0-github-secret.yaml -n gitops-demo-prod
oc delete -f 0-quay-secret.yaml -n gitops-demo-dev
oc delete -f 0-quay-secret.yaml -n gitops-demo-stage
oc delete -f 0-quay-secret.yaml -n gitops-demo-prod
echo "🚫 Delete Secrets"
oc delete project gitops-demo-dev
oc delete project gitops-demo-stage
oc delete project gitops-demo-prod

echo "--------------------------------------------------------------------------------"
echo "Disclaimer: This script just uninstalls the application with all their resources" 
echo "Not uninstalled:"
echo "--------------------------------------------------------------------------------"
echo "✅ Operator: OpenShift Pipelines"
echo "✅ Operator: OpenShift GitOps"
echo "✅ Operator: OpenShift Streams"
echo "✅ Helm Chart: Bitnami Sealed Secrets"
echo "✅ Helm Chart: Stakater Reloader"