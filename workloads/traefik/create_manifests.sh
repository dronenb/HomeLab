#!/bin/bash
NAMESPACE=traefik-v2

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

# Create namespace object
kubectl create namespace "${NAMESPACE}" -o yaml --dry-run=client | \
    yq eval 'del(.metadata.creationTimestamp) | del(.spec) | del(.status)' \
    > namespace.yaml

helm repo add traefik https://traefik.github.io/charts
helm repo update
helm template --namespace="${NAMESPACE}" --include-crds traefik traefik/traefik | \
    grep -v '# Source' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml" -f -

# Iterate over each yaml file
files=()
for file in *.yaml; do
    files+=("${file}")
    # Prepend ---
    echo -e "---\n# yamllint disable rule:line-length\n$(cat "${file}")" > "${file}"
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
