#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# OKD_BIN=$(mktemp -d)
OKD_BIN="/tmp/okd"
if [[ $(uname) == "Darwin" ]]; then
    PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:${PATH}"
    PATH="$(brew --prefix)/opt/gnu-tar/libexec/gnubin:${PATH}"
    export PATH
fi
# mkdir -p "${OKD_BIN}"
OKD_VERSION_INFO=$(curl --silent --request GET --url "https://quay.io/api/v1/repository/okd/scos-release/tag/" | jq -r '.tags[0]')
OKD_VERSION=$(jq -r '.name' <<< "${OKD_VERSION_INFO}")
OKD_SHA=$(jq -r '.manifest_digest' <<< "${OKD_VERSION_INFO}")
OKD_URL="quay.io/okd/scos-release:${OKD_VERSION}@${OKD_SHA}"
echo "Using OKD URL: ${OKD_URL}"
if [[ ! -d "${OKD_BIN}" ]]; then
    mkdir -p "${OKD_BIN}"
    echo "Extracting OKD tools for version ${OKD_VERSION} to ${OKD_BIN}"
    oc adm release extract --tools "${OKD_URL}" --to="${OKD_BIN}"
fi
ls "${OKD_BIN}"
tar xvzf "${OKD_BIN}"/openshift-install-*-4* -C "${OKD_BIN}"
tar xvzf "${OKD_BIN}"/openshift-client-*-4* -C "${OKD_BIN}"
# rm "${OKD_BIN}"/*.txt README.md *.tar.gz
# rm "${OKD_BIN}"/*.txt "${OKD_BIN}/README.md"
export PATH="${OKD_BIN}:${PATH}"
OKD_IMAGE=$(grep -i machine-os-image <<< "${OKD_BIN}/releast.txt" | awk '{print $2}')
pushd "${OKD_BIN}"
# https://github.com/openshift/machine-os-images/blob/fd32b76410f84ea18ddb75a8498d6d89d78d495d/README.md#retrieving-the-machine-os
podman run --platform linux/amd64 --rm -v "$(realpath "${OKD_BIN}")":/data:bind "${OKD_IMAGE}" /bin/copy-iso /data
qemu-img convert -f raw -O qcow2 coreos-x86_64.iso scos-x86_64.qcow2
