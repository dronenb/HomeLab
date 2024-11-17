#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

export AVP_TYPE=gcpsecretmanager
kubectl kustomize manifests/overlays/fh | argocd-vault-plugin generate - | kubectl apply -f -
