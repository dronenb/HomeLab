#!/usr/bin/env bash
kubectl kustomize manifests/base | kubectl apply -f -
