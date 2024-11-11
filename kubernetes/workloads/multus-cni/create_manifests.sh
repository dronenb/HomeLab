#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

multus_tmpdir=$(mktemp -d)
pushd "${multus_tmpdir}" || exit 1
# I am using this to steal the initcontainer from Rancher's distribution of multus
# This way I don't have to mess w/ installing CNI's to /opt/cni/bin myself
helm repo add rke2-charts https://rke2-charts.rancher.io
helm repo update
helm template rke2-multus rke2-charts/rke2-multus | \
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

initContainer=$(yq --no-colors '.spec.template.spec.initContainers[] | del(.env)' daemonset.yaml)
popd || exit 1
rm -rf "${multus_tmpdir}"
mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1


# Download rbac manifests and separate into separate files
links=(
    "https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml"
)

tmpvar=""
for link in "${links[@]}"; do
    content=$(curl -sL "${link}")
    tmpvar=$(printf "%s\n---\n%s" "${tmpvar}" "${content}")
done

# echo "${tmpvar}"

echo -n "${tmpvar}" |
    yq --no-colors --prettyPrint | \
    kubectl-slice -o . --skip-non-k8s --template "{{ .kind | lower }}.yaml"

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

yq -i '.spec.template.spec.initContainers += load("'<(echo -n "${initContainer}")'")' daemonset.yaml

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

mkdir -p manifests/rke2-multus
pushd manifests/rke2-multus || exit 1
