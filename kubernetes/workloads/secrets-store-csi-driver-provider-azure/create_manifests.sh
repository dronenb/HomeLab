#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

# helm search repo csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --versions
export VERSION="1.5.6"
export NAMESPACE=secrets-store-csi-driver

helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
helm repo update
helm template csi-secrets-store-provider-azure csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
    --include-crds \
    --version "${VERSION}" \
    --namespace "${NAMESPACE}" \
    --set secrets-store-csi-driver.syncSecret.enabled=true \
    --set linux.providersDir=/etc/kubernetes/secrets-store-csi-providers \
    --set secrets-store-csi-driver.install=false | \
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

yq -i e '.spec.template.spec.containers[].securityContext += {"privileged" : true,"allowPrivilegeEscalation":true}' daemonset.yaml

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
