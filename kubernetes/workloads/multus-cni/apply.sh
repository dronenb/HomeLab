#!/usr/bin/env bash
kubectl kustomize manifests/overlays/fh | kubectl apply -f -
