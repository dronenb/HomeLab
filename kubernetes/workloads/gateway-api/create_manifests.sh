#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

GATEWAY_API_VERSION=v1.2.1

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1



curl -sL "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml" |
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

# Iterate over each yaml file
files=()
for file in *.yaml; do
    if [[ "${file}" == "kustomization.yaml" ]]; then
        continue
    fi
    files+=("${file}")
    contents="$(cat "${file}")"
    printf -- "---\n# yamllint disable rule:line-length\n%s" "${contents}" > "${file}"
done

# Create kustomize file
cat <<EOF > kustomization.yaml
---
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
resources:
$(printf "  - %s\n" "${files[@]}")
EOF

# Format YAML
prettier . --write
popd > /dev/null || exit 1
