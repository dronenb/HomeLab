#!/usr/bin/env bash
set -e
./terraform.sh pre
export AVP_TYPE=gcpsecretmanager
kubectl kustomize manifests/base | \
    argocd-vault-plugin generate - | \
    kubectl apply -f -
