#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

# Create CRD's and wait til they're installed
kubectl kustomize manifests/base/crds | kubectl apply --server-side -f -
yq '.metadata.name' < manifests/base/crds/customresourcedefinition.yaml | grep -v -- "---" | while IFS='' read -r crd; do
    while ! kubectl get "crd/${crd}" > /dev/null; do
        sleep 1
    done
done

# Install the rest
kubectl kustomize manifests/base/olm | kubectl apply -f -
