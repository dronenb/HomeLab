#!/usr/bin/env bash
set -e

# CILIUM_VERSION="1.15.4"

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

# Need to figure out why this doesn't work
# Would prefer to use helm instead of their own CLI
# helm template cilium cilium/cilium \
#     --include-crds \
#     --version "${CILIUM_VERSION}" \

cilium install --dry-run \
    --namespace kube-system \
    --set routingMode=tunnel \
    --set tunnelProtocol=geneve \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=patchme \
    --set k8sServicePort=6443 \
    --set loadBalancer.mode=dsr \
    --set loadBalancer.dsrDispatch=geneve \
    --set l2announcements.enabled=true \
    --set gatewayAPI.enabled=true \
    --set envoy.enabled=true \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true  | \
    yq --no-colors --prettyPrint | \
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
