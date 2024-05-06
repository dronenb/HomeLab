#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# set -x

# Arguments
vmid="${1:-107}"
phase="${2:-pre-start}"

# global vars
COREOS_FILES_PATH=/var/lib/vz/snippets
BUTANE_BINARY="/usr/local/bin/butane"
YQ_BINARY="/usr/local/bin/yq"

function install_butane {
    local BUTANE_VERSION="0.20.0"
    local BUTANE_CHECKSUM="28003c61b991d17d66c23cd3f305202ae14736b8e7fd941986b6086cf931ed4b"
    local ARCH="x86_64"
    local DOWNLOAD_URL="https://github.com/coreos/butane/releases/download/v${BUTANE_VERSION}/butane-${ARCH}-unknown-linux-gnu"

    if [[ -x "${BUTANE_BINARY}" && "$(${BUTANE_BINARY} --version | awk '{print $NF}')" == "${BUTANE_VERSION}" ]]; then
        return 0
    fi
    echo "Installing Butane..."
    rm -f "${BUTANE_BINARY}"
    curl --silent --location --url "${DOWNLOAD_URL}" --output "${BUTANE_BINARY}"
    echo -n "${BUTANE_CHECKSUM} ${BUTANE_BINARY}" | sha256sum --check > /dev/null
    chmod 755 "${BUTANE_BINARY}"
}

function install_yq {
    local YQ_VERSION="4.43.1"
    local YQ_CHECKSUM="cfbbb9ba72c9402ef4ab9d8f843439693dfb380927921740e51706d90869c7e1"
    local ARCH="amd64"
    local DOWNLOAD_URL="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH}"

    if [[ -x "${YQ_BINARY}" && "$("${YQ_BINARY}" --version | awk '{print $NF}')" == "v${YQ_VERSION}" ]]; then
        return 0
    fi
    echo "Installing yq..."
    rm -f "${YQ_BINARY}"
    curl --silent --location --url "${DOWNLOAD_URL}" --output "${YQ_BINARY}"
    echo -n "${YQ_CHECKSUM} ${YQ_BINARY}" | sha256sum --check > /dev/null
    chmod 755 "${YQ_BINARY}"
}

function main {
    # Install prerequisites
    install_butane
    install_yq

    # CD to our working dir
    pushd "${COREOS_FILES_PATH}" > /dev/null

    # Pre-start
    if [[ "${phase}" == "pre-start" ]]; then
        # Extract Cloud Init instance ID
        instance_id=$(qm cloudinit dump "${vmid}" meta | "${YQ_BINARY}" -r '.instance-id')

        [[ "${instance_id}" == "null" ]] && exit 1
        
        # Gather information to dump into our butane file
        # Default username "core"
        # Default hostname "localhost"
        cloudinit_user_data=$(qm cloudinit dump "${vmid}" user)
        ciuser=$(echo -n "${cloudinit_user_data}" | "${YQ_BINARY}" -M '.user // "core"')
        cihostname=$(echo -n "${cloudinit_user_data}" | "${YQ_BINARY}" -M '.hostname // "localhost"')
        butane_conf=$( cat \
<<EOF
variant: fcos
version: 1.5.0
ignition:
  config:
    merge:
      - local: ${cihostname}-base.ign
passwd:
  users:
    - name: ${ciuser}
      groups:
        - sudo
        - wheel
      shell: /bin/bash
      should_exist: true
      no_create_home: false
storage:
  files:
    - path: /etc/hostname
      mode: 0644
      overwrite: true
      contents:
        inline: ${cihostname}
EOF
        )
        cipasswordhash=$(echo -n "${cloudinit_user_data}" | "${YQ_BINARY}" -M '.password // ""')
        cisshkeys=$(echo -n "${cloudinit_user_data}" | "${YQ_BINARY}" -M '.ssh_authorized_keys // ""')
        if [[ -z "${cipasswordhash}" && -z "${cisshkeys}" ]]; then
            echo "Either a password or SSH key MUST be included in the CloudInit config" 1>&2
            exit 1
        fi

        if [[ -n "${cisshkeys}" ]]; then
            # Neat trick: https://tldp.org/LDP/abs/html/process-sub.html
            butane_conf=$(echo -n "${butane_conf}" | "${YQ_BINARY}" '.passwd.users[0].ssh_authorized_keys = load("'<(echo "${cisshkeys}")'")')
        fi

        if [[ -n "${cipasswordhash}" ]]; then
            butane_conf=$(echo -n "${butane_conf}" | "${YQ_BINARY}" '.passwd.users[0].password_hash = "'"${cipasswordhash}"'"')
        fi
        # echo -n "${butane_conf}" | "${BUTANE_BINARY}" --strict --files-dir /var/lib/vz/snippets /dev/stdin
        echo -n "${butane_conf}" | "${BUTANE_BINARY}" --strict --files-dir /var/lib/vz/snippets /dev/stdin > "/var/lib/vz/snippets/${cihostname}.ign"

        # TODO: add network config here...
    fi
}

#shellcheck disable=SC2068
main
