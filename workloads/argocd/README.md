# ArgoCD

## Create Manifests

```bash
./create_manifests.sh
```

## Apply

```bash
kubectl kustomize manifests/base/ | kubectl apply -f -
```

## Links

- <https://argo-cd.readthedocs.io/en/stable/getting_started/>
