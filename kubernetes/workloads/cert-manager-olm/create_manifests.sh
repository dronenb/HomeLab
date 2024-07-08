#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

# set -x

NAMESPACE="cert-manager"

rm -rf manifests/base
mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1


# Download manifests and separate into separate files
curl -sL https://operatorhub.io/install/cert-manager.yaml | \
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

# Create namespace object
# Append in case above creates a namespace resource for some reason
echo "---" >> namespace.yaml
kubectl create namespace "${NAMESPACE}" -o yaml --dry-run=client | \
    kubectl neat \
    >> namespace.yaml

cat <<EOF >> operatorgroup.yaml
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cert-manager
EOF

files=()

while read -r file; do
    file=$(basename "${file}")
    if [[ "${file}" == "kustomization.yaml" ]]; then
        continue
    fi
    files+=("${file}")
    contents=$(cat "${file}")
    if ! echo "${contents}" | head -n 1 | grep -q -- "^---"; then
        contents=$(printf -- "---\n%s" "${contents}")
    fi
    printf -- "# yamllint disable rule:line-length\n%s" "${contents}" > "${file}"
done < <(find . -name "*.yaml") # https://mywiki.wooledge.org/BashFAQ/024


# Create kustomize file
cat <<EOF > kustomization.yaml
---
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: "${NAMESPACE}"
resources:
$(printf "  - %s\n" "${files[@]}")
EOF

# Format YAML
prettier . --write
popd > /dev/null || exit 1
