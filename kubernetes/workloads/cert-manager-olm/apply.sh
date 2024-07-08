#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

./tofu.sh pre
export AVP_TYPE=gcpsecretmanager
kubectl kustomize manifests/base | \
    kubectl apply -f -

crds=(
    "clusterissuers.cert-manager.io"
)

echo "Waiting for cert-manager CRD's to become available..."
for crd in "${crds[@]}"; do
    while ! kubectl get "crd/${crd}" > /dev/null 2>&1; do
        sleep 1
    done
done

kubectl kustomize manifests/additions | \
    argocd-vault-plugin generate - | \
    kubectl apply -f -
