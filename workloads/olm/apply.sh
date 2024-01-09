#!/usr/bin/env bash
kubectl kustomize manifests/base/crds | kubectl create -f -
kubectl kustomize manifests/base/olm | kubectl apply -f -
