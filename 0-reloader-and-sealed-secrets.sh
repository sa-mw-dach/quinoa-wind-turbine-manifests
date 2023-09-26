helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
oc new-project reloader
helm install reloader stakater/reloader -n reloader --set reloader.isOpenshift=true --set reloader.deployment.securityContext.runAsUser=null

helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets

oc new-project gitops-demo-dev
oc new-project gitops-demo-stage
oc new-project gitops-demo-prod

oc apply -f 1-github-and-quay-secrets_filled.yaml -n gitops-demo-dev
oc apply -f 1-github-and-quay-secrets_filled.yaml -n gitops-demo-stage

oc secret link pipeline github-oauth-config -n gitops-demo-dev
oc secret link pipeline github-oauth-config -n gitops-demo-stage

oc secret link pipeline quay-push-secret -n gitops-demo-dev
oc secret link pipeline quay-push-secret -n gitops-demo-stage

kubeseal -f stages/dev/secret.yaml -n gitops-demo-dev > stages/dev/sealedsecret.yaml 
kubeseal -f stages/stage/secret.yaml -n gitops-demo-stage > stages/stage/sealedsecret.yaml 
kubeseal -f stages/prod/secret.yaml -n gitops-demo-prod > stages/prod/sealedsecret.yaml 