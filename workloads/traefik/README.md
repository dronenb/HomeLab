# Traefik

## Create Manifests

```bash
./create_manifests.sh
```

## Apply

```bash
kubectl kustomize manifests/base/ | kubectl apply -f -
```

## Links

- <https://doc.traefik.io/traefik/getting-started/install-traefik/#use-the-helm-chart>
