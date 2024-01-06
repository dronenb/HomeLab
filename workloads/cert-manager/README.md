# cert-manager

## Create Manifests

```bash
./create_manifests.sh
```

## Create Secrets

```bash
./terraform.sh pre
```

## Deploy

```bash
export AVP_TYPE=gcpsecretmanager
kubectl kustomize manifests/base | \
    argocd-vault-plugin generate - | \
    kubectl apply -f -
```

## Links

- <https://cert-manager.io/docs/installation/kubectl/>
