#!/usr/bin/env bash

NAMESPACE="cert-manager"

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1


# Create namespace object
kubectl create namespace "${NAMESPACE}" -o yaml --dry-run=client | \
    yq eval 'del(.metadata.creationTimestamp) | del(.spec) | del(.status)' \
    > namespace.yaml

# Download manifests and separate into separate files
curl -sL https://operatorhub.io/install/cert-manager.yaml | \
    grep -v "# Source: " | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

# Iterate over each yaml file
files=()
for file in *.yaml; do
    if [[ "${file}" == "kustomization.yaml" ]]; then
        continue
    fi
    files+=("${file}")
    # Prepend ---
    echo -e "---\n# yamllint disable rule:line-length\n$(cat "${file}")" > "${file}"
    # Add namespace to namespace scoped objects
    regex="^clusterrole|clusterrolebinding|clusterissuer|namespace|customresourcedefinition"
    if [[ ! "${file}" =~ $regex ]]; then
        yq eval -i ".metadata.namespace = \"${NAMESPACE}\"" "${file}"
    fi
done

# Create kustomize file
cat <<EOF > kustomization.yaml
---
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
resources:
  - ../additions/
$(printf "  - %s\n" "${files[@]}")
EOF

# Format YAML
prettier . --write
popd > /dev/null || exit 1
