#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

CERT_MANAGER_VERSION=1.16.1

# Download manifests and separate into separate files
curl -sL "https://github.com/cert-manager/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.yaml" | \
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

# Split the deployment up
kubectl-slice -o . --template "{{ .kind | lower }}-{{ .metadata.name | lower }}.yaml" < deployment.yaml
rm deployment.yaml

volumes=$( \
cat <<EOF
- name: gcp-ksa
  projected:
    defaultMode: 420
    sources:
      - serviceAccountToken:
          audience: k3s
          expirationSeconds: 3600
          path: token
      - configMap:
          items:
            - key: credential-configuration.json
              path: credential-configuration.json
          name: default-creds-config
          optional: false
EOF
)
volumeMounts=$( \
cat <<EOF
- mountPath: /var/run/secrets/tokens/gcp-ksa
  name: gcp-ksa
  readOnly: true
EOF
)
yq -i '.spec.template.spec.volumes=load("'<(echo "${volumes}")'")' deployment-cert-manager.yaml
yq -i '.spec.template.spec.containers[].volumeMounts=load("'<(echo "${volumeMounts}")'")' deployment-cert-manager.yaml
yq -i '.spec.template.spec.containers[].env += {"name":"GOOGLE_APPLICATION_CREDENTIALS","value":"/var/run/secrets/tokens/gcp-ksa/credential-configuration.json"}' deployment-cert-manager.yaml
curl -sL "https://github.com/cert-manager/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.crds.yaml" | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

kustomize create --autodetect

# Format YAML
prettier . --write
popd > /dev/null || exit 1
