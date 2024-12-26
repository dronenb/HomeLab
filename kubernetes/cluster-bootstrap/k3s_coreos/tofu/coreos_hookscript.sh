#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# set -x

# Arguments
vmid="${1:-103}"
phase="${2:-pre-start}"

# global vars
COREOS_FILES_PATH=/var/lib/vz/snippets
BUTANE_BINARY="/usr/local/bin/butane"
YQ_BINARY="/usr/local/bin/yq"
NMSTATECTL_BINARY="/usr/local/bin/nmstatectl"

function install_butane {
    local BUTANE_VERSION="0.23.0"
    local BUTANE_CHECKSUM="5833ce9f9c2932d9b02bc05821ffb6927d1e896a524c8dd53a4c9d2d90c47e2c"
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
    local YQ_VERSION="4.44.6"
    local YQ_CHECKSUM="0c2b24e645b57d8e7c0566d18643a6d4f5580feeea3878127354a46f2a1e4598"
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

function install_nmstatectl {
    local NMSTATECTL_VERSION="2.2.39"
    local NMSTATECTL_CHECKSUM="8b563db85c145d814f531e1d998dc0db53c4c16d8b7cf73da89308dda82913c6"
    local ARCH="x64"
    local DOWNLOAD_URL="https://github.com/nmstate/nmstate/releases/download/v${NMSTATECTL_VERSION}/nmstatectl-linux-${ARCH}.zip"

    if [[ -x "${NMSTATECTL_BINARY}" && "$("${NMSTATECTL_BINARY}" --version | awk '{print $NF}')" == "${NMSTATECTL_VERSION}" ]]; then
        return 0
    fi
    echo "Installing nmstatectl..."
    rm -f "${NMSTATECTL_BINARY}"
    curl --silent --location --url "${DOWNLOAD_URL}" --output "${NMSTATECTL_BINARY}.zip"
    echo -n "${NMSTATECTL_CHECKSUM} ${NMSTATECTL_BINARY}.zip" | sha256sum --check > /dev/null
    pushd "$(dirname "${NMSTATECTL_BINARY}")" > /dev/null || exit 1
    unzip "${NMSTATECTL_BINARY}.zip"
    rm "${NMSTATECTL_BINARY}.zip"
    popd > /dev/null || exit 1
    chmod 755 "${NMSTATECTL_BINARY}"
}

function mask_to_prefix {
    local mask="${1}"
    # Convert the subnet mask to binary form and count the number of 1s
    local prefix
    prefix=$( \
        echo "${mask}" | tr "." "\n" | while read -r octet; do
            # Convert each octet to binary and count the number of 1s
            printf "%08d\n" "$(/usr/bin/bc <<< "obase=2; ${octet}")" | \
                grep -o "1" | \
                wc -l
        done | /usr/bin/paste -sd+ - | /usr/bin/bc \
    )
    echo -n "${prefix}"
}

function main {
    # Install prerequisites
    install_butane
    install_yq
    install_nmstatectl

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
version: 1.6.0
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

        # TODO: add IPv6 support
        network_data=$(qm cloudinit dump "${vmid}" network)
        network_config_indices=$("${YQ_BINARY}" '.config | length' <<< "${network_data}")

        # This works but is hacky, needs attention, and I would rather not do this with kernel arguments
        nameserver=""
        for ((i=0; i<network_config_indices; i++)); do
            entry=$("${YQ_BINARY}" ".config[${i}]" <<< "${network_data}")
            entry_type=$("${YQ_BINARY}" ".type" <<< "${entry}")
            if [[ "${entry_type}" == "physical" ]]; then
                mac_address=$("${YQ_BINARY}" ".mac_address" <<< "${entry}")
                if_name=$("${YQ_BINARY}" ".name" <<< "${entry}")
                # https://docs.fedoraproject.org/en-US/fedora-coreos/customize-nic/
                if_name_kernel_arg="ifname=${if_name}:${mac_address}"
                butane_conf=$(echo -n "${butane_conf}" | "${YQ_BINARY}" '.kernel_arguments.should_exist += [load_str("'<(echo "${if_name_kernel_arg}")'")]')
                subnet_indices=$("${YQ_BINARY}" '.subnets | length' <<< "${entry}")
                for ((j=0; j<subnet_indices; j++)); do
                    subnet_entry=$("${YQ_BINARY}" ".subnets[${j}]" <<< "${entry}")
                    subnet_type=$("${YQ_BINARY}" '.type' <<< "${subnet_entry}")
                    if [[ "${subnet_type}" == "static" ]]; then
                        gateway=$("${YQ_BINARY}" '.gateway' <<< "${subnet_entry}")
                        address=$(echo -n "${subnet_entry}" | "${YQ_BINARY}" '.address')
                        netmask=$(echo -n "${subnet_entry}" | "${YQ_BINARY}" '.netmask')
                    fi
                done
            elif [[ "${entry_type}" == "nameserver" ]]; then
                nameserver1=$("${YQ_BINARY}" '.address[0]' <<< "${entry}")
                nameserver2=$("${YQ_BINARY}" '.address[1]' <<< "${entry}")
                if [[ "${nameserver2}" != "null" ]]; then
                    nameserver="${nameserver1}:${nameserver2}"
                else
                    nameserver="${nameserver1}"
                fi
            fi
            if [[ -n "${address}" && -n "${gateway}" && -n "${netmask}" && -n "${if_name}" && -n "${nameserver}" ]]; then
              network_kernel_arg="ip=${address}::${gateway}:${netmask}:${cihostname}:${if_name}:none:${nameserver}"
              butane_conf=$(echo -n "${butane_conf}" | "${YQ_BINARY}" '.kernel_arguments.should_exist += [load_str("'<(echo -n "${network_kernel_arg}")'")]')
            fi
        done
        "${BUTANE_BINARY}" --strict --files-dir /var/lib/vz/snippets /dev/stdin <<< "${butane_conf}"  > "/var/lib/vz/snippets/${cihostname}.ign"
    fi
}

#shellcheck disable=SC2068
main
