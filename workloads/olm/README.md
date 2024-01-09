# Operator Lifecycle Management

## Install

```bash
# Intentionally do a create operation on the CRD's
kubectl kustomize manifests/base/crds | kubectl create -f -
kubectl kustomize manifests/base/olm | kubectl apply -f -
```
