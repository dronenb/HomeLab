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
    --namespace="${NAMESPACE}" \
    --version "${EXTERNAL_DNS_CHART_VERSION}" | \
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
