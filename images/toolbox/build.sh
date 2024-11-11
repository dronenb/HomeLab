#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

podman build --platform linux/amd64 -t docker.io/dronenb/toolbox:latest .
podman push docker.io/dronenb/toolbox:latest
