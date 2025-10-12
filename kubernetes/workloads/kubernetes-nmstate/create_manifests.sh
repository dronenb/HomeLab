#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

rm -rf manifests/base
mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

# curl -sL https://api.github.com/repos/nmstate/kubernetes-nmstate/releases | jq -r ".[0].name"
KUBERNETES_NMSTATE_VERSION=v0.84.0

# Download manifests and separate into separate files
content=''
for link in \
  "https://github.com/nmstate/kubernetes-nmstate/releases/download/${KUBERNETES_NMSTATE_VERSION}/nmstate.io_nmstates.yaml" \
  "https://github.com/nmstate/kubernetes-nmstate/releases/download/${KUBERNETES_NMSTATE_VERSION}/namespace.yaml" \
  "https://github.com/nmstate/kubernetes-nmstate/releases/download/${KUBERNETES_NMSTATE_VERSION}/service_account.yaml" \
  "https://github.com/nmstate/kubernetes-nmstate/releases/download/${KUBERNETES_NMSTATE_VERSION}/role.yaml" \
  "https://github.com/nmstate/kubernetes-nmstate/releases/download/${KUBERNETES_NMSTATE_VERSION}/role_binding.yaml" \
  "https://github.com/nmstate/kubernetes-nmstate/releases/download/${KUBERNETES_NMSTATE_VERSION}/operator.yaml";
do
  content=$(printf "%s\n---\n%s" "${content}" "$(curl -sL "${link}")")
done

printf "%s\n" "${content}" | \
  yq --no-colors --prettyPrint '... comments=""' | \
  kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

kustomize create --autodetect

# Format YAML
prettier . --write
popd > /dev/null || exit 1
