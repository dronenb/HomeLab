#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

kubectl kustomize manifests/base | kubectl apply -f -

crds=(
    "argocds.argoproj.io"
)

echo "Waiting for ArgoCD CRD's to become available..."
for crd in "${crds[@]}"; do
    while ! kubectl get "crd/${crd}" > /dev/null 2>&1; do
        sleep 1
    done
done

kubectl kustomize manifests/overlays/fh | \
    kubectl apply -f -
