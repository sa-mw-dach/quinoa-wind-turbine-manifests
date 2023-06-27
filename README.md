# Wind Turbine GitOps repo

## Prerequisites

1. fork this repo
2. run `0-install-operators.sh` - install the needed operators on your cluster. The script also detects, if the operator is already installed.
3. fill your information in the `1-github-and-quay-secrets.yaml`-file. Git Secrets are optional and may be deleted when your forked repo is public.
4. apply the `1-github-and-quay-secrets.yaml`-file to your cluster and namespace
5. copy secrets to all namespaces you want to use.
    ```sh
    oc get secret quay-secret -o json \
    | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid"])' \
    | oc apply -n <destination-namespace> -f -
    ```
6. link secrets to your pipeline
    ```sh
    oc secret link pipeline quay-secret -n <destination-namespace>
    ```

## Installation

1. fill your namespace names etc. in the ArgoCD ApplicationSet yaml file
2. Apply the argocd yaml file
    ```sh
    oc apply -f argoapp.yaml
    ```
3. Create json webhooks in your GitHub application project forks to push to your Event Listener Routes
4. Profit

## Bugfixing:

#### PVC stuck - delete pvc

The pvcs are configured to be not deleted at helm uninstall. You should always delete them manually.

If some pvc gets stuck you can fix this via
```sh
oc patch pvc <pvc-name> -p '{"metadata":{"finalizers": []}}' --type=merge
```

TODO:
- document sealed secret usage -> must be created manually in each namespace/cluster/etc. before