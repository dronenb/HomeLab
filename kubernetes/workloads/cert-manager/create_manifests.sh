#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

rm -rf manifests/base
mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

helm repo add jetstack https://charts.jetstack.io
helm repo update

# helm search repo jetstack/cert-manager
CERT_MANAGER_VERSION=1.16.2
NAMESPACE=cert-manager

# Download manifests and separate into separate files
helm template cert-manager jetstack/cert-manager \
  --include-crds \
  --version "${CERT_MANAGER_VERSION}" \
  --namespace "${NAMESPACE}" \
  --values ../../values.yaml | \
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
