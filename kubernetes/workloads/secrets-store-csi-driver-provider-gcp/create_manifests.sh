#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

NAMESPACE=secrets-store-csi-driver
COMMIT_SHA=c640ef4395f9953ea93516e18f968769bcc52776 # v1.7.0

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

curl -sL "https://raw.githubusercontent.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/${COMMIT_SHA}/deploy/provider-gcp-plugin.yaml" |
    yq --no-colors --prettyPrint '... comments=""' | \
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

# because of SELinux, need to write custom policy... a TODO
yq -i e '.spec.template.spec.initContainers[].securityContext += {"privileged" : true, "allowPrivilegeEscalation":true}' daemonset.yaml
yq -i e '.spec.template.spec.containers[].securityContext += {"privileged" : true,"allowPrivilegeEscalation":true}' daemonset.yaml
yq -i e '.subjects[].namespace = "'"${NAMESPACE}"'"' clusterrolebinding.yaml

PROJECT_NUMBER=805422933562
POOL_ID=k3s-homelab-wif
PROVIDER_ID=k3s-homelab-wif

mkdir config
# https://cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes#deploy
gcloud iam workload-identity-pools create-cred-config \
    "projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}" \
    --credential-source-file=/var/run/secrets/kubernetes.io/serviceaccount/token \
    --credential-source-type=text \
    --output-file=./config/credential-configuration.json

# https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/blob/main/docs/fleet-wif-notes.md
yq -i e '.spec.template.spec.volumes += [{"name":"gcp-ksa","projected":{"defaultMode":420,"sources":[{"serviceAccountToken":{"audience":"k3s","expirationSeconds":3600,"path":"token"}},{"configMap":{"items":[{"key":"credential-configuration.json","path":"credential-configuration.json"}],"name":"default-creds-config","optional":false}}]}}]' daemonset.yaml
yq -i e '.spec.template.spec.containers[0].volumeMounts += [{"mountPath":"/var/run/secrets/tokens/gcp-ksa","name":"gcp-ksa","readOnly":true}]' daemonset.yaml
yq -i e '.spec.template.spec.containers[0].env += [{"name":"GOOGLE_APPLICATION_CREDENTIALS","value":"/var/run/secrets/tokens/gcp-ksa/credential-configuration.json"}]' daemonset.yaml
# https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/blob/main/docs/fleet-wif-notes.md#set-gaia_token_exchange_endpoint-and-appropriate-audience
yq -i e '.spec.template.spec.containers[0].env += [{"name":"GAIA_TOKEN_EXCHANGE_ENDPOINT","value":"https://sts.googleapis.com/v1/token"}]' daemonset.yaml
yq -i e '.spec.template.spec.containers[0].args += ["-v=5"]' daemonset.yaml
# Create kustomize file
cat <<EOF > kustomization.yaml
---
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: ${NAMESPACE}
resources:
$(printf "  - %s\n" "${files[@]}")
configMapGenerator:
- name: default-creds-config
  files:
    - config/credential-configuration.json
EOF

# Format YAML
prettier . --write
popd > /dev/null || exit 1
