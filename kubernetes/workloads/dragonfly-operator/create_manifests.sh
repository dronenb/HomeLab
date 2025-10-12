#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

# https://github.com/dragonflydb/dragonfly-operator/releases/latest
VERSION=1.3.0
# NAMESPACE=dragonfly-operator-system

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

curl -sL "https://raw.githubusercontent.com/dragonflydb/dragonfly-operator/refs/tags/v${VERSION}/manifests/dragonfly-operator.yaml" | \
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
