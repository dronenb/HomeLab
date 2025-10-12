#!/usr/bin/env bash

# https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/blob/master/helm/README.md

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

# helm search repo sig-storage-local-static-provisioner/local-static-provisioner
VERSION=2.8.0
NAMESPACE=local-static-provisioner

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

helm repo add sig-storage-local-static-provisioner https://kubernetes-sigs.github.io/sig-storage-local-static-provisioner

helm template local-static-provisioner sig-storage-local-static-provisioner/local-static-provisioner \
    --version "${VERSION}" \
    --namespace="${NAMESPACE}" -f ../../values.yaml | \
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

echo "---" >> namespace.yaml
kubectl create namespace "${NAMESPACE}" -o yaml --dry-run=client | \
    kubectl neat \
    >> namespace.yaml

cat <<EOF > storageclass.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

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
