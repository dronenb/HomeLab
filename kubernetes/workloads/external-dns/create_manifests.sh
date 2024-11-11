#!/usr/bin/env bash

# https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

NAMESPACE=external-dns
EXTERNAL_DNS_CHART_VERSION=1.14.5

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm template external-dns external-dns/external-dns \
    --values ../../values.yaml \
    --namespace="${NAMESPACE}" \
    --version "${EXTERNAL_DNS_CHART_VERSION}" | \
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
