#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

kubectl kustomize manifests/base | kubectl apply -f -
