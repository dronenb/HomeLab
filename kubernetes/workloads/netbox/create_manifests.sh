#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

rm -rf manifests/base
mkdir -p manifests/base
pushd manifests/base > /dev/null || exit 1

export NAMESPACE="netbox"

# https://artifacthub.io/packages/helm/netbox/netbox
# The startupProbe.failureThreshold is super high because it initializes the database on first run and takes ages
helm template netbox oci://ghcr.io/netbox-community/netbox-chart/netbox \
    --namespace "${NAMESPACE}" \
    --include-crds \
    --set 'cachingRedis.existingSecretKey=redis-password' \
    --set 'cachingRedis.existingSecretName=redis-password' \
    --set 'existingSecret=netbox-config' \
    --set 'externalDatabase.existingSecretKey=password' \
    --set 'externalDatabase.existingSecretName=netbox-postgresql-credentials' \
    --set 'externalDatabase.host=netbox-postgresql-ha.netbox.svc' \
    --set 'externalDatabase.user=netbox' \
    --set 'ingress.className=cilium' \
    --set 'ingress.enabled=true' \
    --set 'ingress.hosts[0].host=netbox.fh.dronen.house' \
    --set 'ingress.hosts[0].paths[0]="/"' \
    --set 'ingress.tls[0].hosts[0]=netbox.fh.dronen.house' \
    --set 'ingress.tls[0].secretName=netbox-server-tls' \
    --set 'postgresql.enabled=false' \
    --set 'valkey.enabled=false' \
    --set 'startupProbe.failureThreshold=60' \
    --set 'superuser.existingSecret=netbox-superuser' \
    --set 'cachingDatabase.existingSecretName=redis-password' \
    --set 'tasksDatabase.existingSecretName=redis-password' \
    --set 'cachingDatabase.existingSecretKey=redis-password' \
    --set 'tasksDatabase.existingSecretKey=redis-password' | \
    yq --no-colors --prettyPrint '... comments=""' | \
    kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

# Remove the test pod
rm pod.yaml

echo "---" > namespace.yaml
kubectl create namespace "${NAMESPACE}" -o yaml --dry-run=client | \
    kubectl neat \
    >> namespace.yaml

kustomize create --autodetect

# Format YAML
prettier . --write
popd > /dev/null || exit 1
