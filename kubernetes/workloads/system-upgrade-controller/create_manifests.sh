#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

VERSION=$(curl -sL https://api.github.com/repos/rancher/system-upgrade-controller/releases | jq -r ".[0].name")

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

# Download rbac manifests and separate into separate files
links=(
    "https://github.com/rancher/system-upgrade-controller/releases/download/${VERSION}/system-upgrade-controller.yaml"
)

tmpvar=""
for link in "${links[@]}"; do
    content=$(curl -sL "${link}")
    tmpvar=$(printf "%s\n---\n%s" "${tmpvar}" "${content}")
done

echo -n "${tmpvar}" |
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
