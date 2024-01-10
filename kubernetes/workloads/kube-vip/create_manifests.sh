#!/usr/bin/env bash

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1


# Download rbac manifests and separate into separate files
curl -sL https://kube-vip.io/manifests/rbac.yaml | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

curl -sL https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml | \
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
