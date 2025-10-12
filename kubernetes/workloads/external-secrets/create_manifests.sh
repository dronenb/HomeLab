#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

rm -rf manifests/base
mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

# helm search repo external-secrets/external-secrets
export VERSION="0.20.2"
export NAMESPACE=external-secrets

helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm template external-secrets \
   external-secrets/external-secrets \
    --namespace "${NAMESPACE}" \
    --include-crds \
    --version "${VERSION}" | \
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

echo "---" > namespace.yaml
kubectl create namespace "${NAMESPACE}" -o yaml --dry-run=client | \
    kubectl neat \
    >> namespace.yaml

kustomize create --autodetect

# Format YAML
prettier . --write
popd > /dev/null || exit 1
