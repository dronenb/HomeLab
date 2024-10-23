#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

export NAMESPACE=secrets-store-csi-driver

curl -sL https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml | \
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

yq -i e '.spec.template.spec.containers[].securityContext += {"privileged" : true,"allowPrivilegeEscalation":true}' daemonset.yaml

kustomize create --autodetect --namespace "${NAMESPACE}"
prettier . --write
