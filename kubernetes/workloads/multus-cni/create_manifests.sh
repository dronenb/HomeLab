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
helm template rke2-multus rke2-charts/rke2-multus \
    --set manifests.dhcpDaemonSet=true \
    --namespace kube-system | \
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

initContainer=$(yq --no-colors 'select(di==0) | .spec.template.spec.initContainers[] | del(.env)' daemonset.yaml)
dhcpDaemonSet=$(yq 'select(di==1)' daemonset.yaml)
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

yq -i '.spec.template.spec.initContainers += load("'<(echo -n "${initContainer}")'")' daemonset.yaml
echo -e "\n---\n${dhcpDaemonSet}" >> daemonset.yaml
# Create kustomize file
kustomize create --autodetect

# Format YAML
prettier . --write
popd > /dev/null || exit 1

mkdir -p manifests/rke2-multus
pushd manifests/rke2-multus || exit 1
