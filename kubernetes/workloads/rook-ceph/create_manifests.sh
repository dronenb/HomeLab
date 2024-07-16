#!/usr/bin/env bash

# https://rook.io/docs/rook/latest-release/Helm-Charts/operator-chart/#installing

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

NAMESPACE=rook-ceph
# EXTERNAL_DNS_CHART_VERSION=1.14.5

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

helm repo add rook-release https://charts.rook.io/release

helm template rook-ceph rook-release/rook-ceph \
    --namespace="${NAMESPACE}" \
    --set hostpathRequiresPrivileged=true | \
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

echo "---" >> namespace.yaml
kubectl create namespace "${NAMESPACE}" -o yaml --dry-run=client | \
    kubectl neat \
    >> namespace.yaml

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
