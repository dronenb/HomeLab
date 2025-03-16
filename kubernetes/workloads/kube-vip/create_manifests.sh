#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

# Download rbac manifests and separate into separate files
links=(
    https://kube-vip.io/manifests/rbac.yaml
    https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
)

tmpvar=""
for link in "${links[@]}"; do
    content=$(curl -sL "${link}")
    tmpvar=$(printf "%s\n---\n%s" "${tmpvar}" "${content}")
done

content=$( \
    podman run --rm "ghcr.io/kube-vip/kube-vip:${KVVERSION}" manifest daemonset \
        --address 10.91.1.8 \
        --interface eth0 \
        --arp \
        --controlplane \
        --enableEndpointSlices \
        --enableLoadBalancer \
        --enableNodeLabeling \
        --lbClassName="kube-vip.io/kube-vip-class" \
        --lbClassOnly \
        --leaderElection \
        --inCluster \
        --services \
        --servicesElection \
        --taint | kubectl neat
)

tmpvar=$(printf "%s\n---\n%s" "${tmpvar}" "${content}")

echo -n "${tmpvar}" |
    yq --no-colors --prettyPrint | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

# Add loadbalancerclass to cloud controller
yq -i '.spec.template.spec.containers[0].env += [{"name":"KUBEVIP_ENABLE_LOADBALANCERCLASS", "value": "true"}]' deployment.yaml

# Remove deprecated node-role.kubernetes.io/master selector
# https://kubernetes.io/docs/reference/labels-annotations-taints/#node-role-kubernetes-io-master-taint
yq -i 'del(.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0])' daemonset.yaml
yq -i 'del(.spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[1])' deployment.yaml

# Explicitly disable UPnP
yq -i '.spec.template.spec.containers[0].env += {"name":"enableUPNP","value":false}' daemonset.yaml

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
