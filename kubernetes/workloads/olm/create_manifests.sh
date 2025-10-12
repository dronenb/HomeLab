#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

# https://github.com/operator-framework/operator-lifecycle-manager/releases
OLM_RELEASE=v0.34.0

folders=("crds" "olm")

for folder in "${folders[@]}"; do
    mkdir -p "manifests/base/${folder}"
    pushd "manifests/base/${folder}" > /dev/null || exit 1
    # Download manifests and separate into separate files
    curl -sL "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_RELEASE}/${folder}.yaml" | \
        yq --no-colors --prettyPrint '... comments=""' | \
        kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

    # Iterate over each yaml file
    files=()
    for file in *.yaml; do
        if [[ "${file}" == "kustomization.yaml" ]]; then
            continue
        fi
        files+=("${file}")
        # Prepend ---
        printf -- "---\n# yamllint disable rule:line-length\n%s" "$(cat "${file}")" > "${file}"
    done

    # Create kustomize file
    cat <<EOF > kustomization.yaml
---
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
resources:
$(printf "  - %s\n" "${files[@]}")
EOF

    popd > /dev/null || exit 1
done

set +e
for folder in "${folders[@]}"; do
    pushd "manifests/base/${folder}" > /dev/null || exit 1
    prettier . --write
    popd > /dev/null
done
