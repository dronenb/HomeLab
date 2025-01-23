#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

export CILIUM_VERSION="1.16.6"
export NAMESPACE=cilium

helm repo update
helm template cilium cilium/cilium \
    --api-versions gateway.networking.k8s.io/v1/GatewayClass \
    --include-crds \
    --version "${CILIUM_VERSION}" \
    --namespace "${NAMESPACE}" \
    --set routingMode=tunnel \
    --set tunnelProtocol=geneve \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=patchme \
    --set k8sServicePort=6443 \
    --set loadBalancer.mode=dsr \
    --set loadBalancer.dsrDispatch=geneve \
    --set l2announcements.enabled=true \
    --set hubble.relay.enabled=true \
    --set ipam.operator.clusterPoolIPv4PodCIDRList="10.42.0.0/16" \
    --set hubble.ui.enabled=true \
    --set gatewayAPI.enabled=true \
    --set ingressController.enabled=true \
    --set ingressController.loadbalancerMode=shared \
    --set ingressController.service.loadBalancerClass=kube-vip.io/kube-vip-class \
    --set l7Proxy=true \
    --set loadBalancer.l7.backend=envoy \
    --set hubble.tls.auto.enabled=true \
    --set hubble.tls.auto.method=cronJob \
    --set hubble.tls.auto.certValidityDuration=1095 \
    --set hubble.tls.auto.schedule="0 0 1 */4 *" \
    --set envoy.enabled=false | \
    # envoy.enabled won't work with SELinux enabled: https://docs.cilium.io/en/latest/security/network/proxy/envoy/#known-limitations
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
