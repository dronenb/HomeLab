#!/usr/bin/env bash
set -e
kubectl kustomize manifests/overlays/fh/ | kubectl apply -f -
