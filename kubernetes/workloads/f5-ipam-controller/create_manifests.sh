#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

NAMESPACE=f5-ipam-controller

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

helm repo add f5-ipam-stable https://f5networks.github.io/f5-ipam-controller/helm-charts/stable
helm repo update
helm template --include-crds f5-ipam-stable f5-ipam-stable/f5-ipam-controller -f ../../values.yaml | \
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

cat <<EOF > kustomization.yaml
---
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: ${NAMESPACE}
resources:
$(printf "  - %s\n" "${files[@]}")
EOF

prettier --write .
