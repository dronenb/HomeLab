#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

# Colors
BOLD_RED='\033[1;31m'
BOLD_CYAN='\033[1;36m'
NC='\033[0m'
BOLD_YELLOW='\033[1;33m'

TEMP=$(realpath /tmp)
WORKDIR="${TEMP}/k3s_init"

PODMAN_MACHINE_VCPUS=4
PODMAN_MACHINE_MEMORY_MB=4096
PODMAN_MACHINE_DISK_GB=20
PODMAN_MACHINE_NAME="podman-machine-default"

function main {
    chk_prerequisites
    chk_podman_machine
    pull_podman_images
    create_workdir
    generate_ignition
    tofu_apply
    ssh -o StrictHostKeyChecking=no 10.91.1.9 'cat /etc/rancher/k3s/k3s.yaml' | \
        yq --no-colors '.clusters[0].cluster.server = "https://10.91.1.9:6443"' \
        > ~/.kube/config
    chmod 600 ~/.kube/config
}

function tofu_apply {
    pushd tofu || exit 1
    tofu init
    tofu plan -out /tmp/tf.plan
    tofu apply /tmp/tf.plan
    popd || exit 1
}

# function upload_iso {
#     msg_change "Uploading ISO to Proxmox host..."
#     rsync --progress "${WORKDIR}/k3s.iso" "root@10.91.1.2:/var/lib/vz/template/iso/"
# }

# function customize_coreos {
#     if [[ -f "${WORKDIR}/k3s.iso" ]]; then
#         msg_change "Deleting existing ISO..."
#         rm "${WORKDIR}/k3s.iso"
#     fi
#     msg_change "Creating new ISO from ignition file..."
#     coreos-installer iso customize \
#         --dest-ignition "${WORKDIR}/k3s.ign" \
#         --dest-device "/dev/sda" \
#         -o "${WORKDIR}/k3s.iso" \
#         "${WORKDIR}/fedora-coreos.iso"
# }

function create_workdir {
    msg_info "Checking if working directory exists"
    if [[ ! -d "${WORKDIR}" ]]; then
        msg_change "Workdir ${WORKDIR} does not exist! Creating..."
        mkdir -p "${WORKDIR}"
    fi
}

function generate_ignition {
    msg_change "Generating ignition file..."
    butane --strict k3s.bu | tee "${WORKDIR}/k3s.ign" | jq
    ignition-validate "${WORKDIR}/k3s.ign"
}

function ignition-validate {
    #shellcheck disable=SC2068
    podman run --rm --volume "${WORKDIR}:${WORKDIR}" quay.io/coreos/ignition-validate:release $@
}

# function coreos-installer {
#     #shellcheck disable=SC2068
#     podman run --rm --volume "${WORKDIR}:${WORKDIR}" quay.io/coreos/coreos-installer:release $@
# }

function pull_podman_images {
    msg_info "Pulling podman images"
    images=(
        "quay.io/coreos/coreos-installer:release"
        "quay.io/coreos/ignition-validate:release"
    )
    for image in "${images[@]}"; do
        msg_info "Pulling image ${image}"
        podman pull "${image}"
    done
}

function chk_prerequisites {
    binaries=(
        "butane"
        "jq"
        "podman"
        "yq"
    )
    for binary in "${binaries[@]}"; do
        msg_info "Checking for binary ${binary}"
        if ! command -v "${binary}" >/dev/null; then
            msg_error "Could not find binary ${binary} in \$PATH"
            exit 1
        fi
    done
}

function chk_podman_machine {
    msg_info "Checking if podman machine exists..."
    podman_machine_list=$(podman machine list --format=json)
    # Check if the default machine has been created
    if [[ $(echo "${podman_machine_list}" | jq -r 'select(.[].Name=="'"${PODMAN_MACHINE_NAME}"'") | length') -eq 0 ]]; then
        init_podman_machine
        podman_machine_list=$(podman machine list --format=json)
    fi

    # Check if the default machine meets the system requirements
    jq_query='
        .[] | 
        select(
            (.Name=="'"${PODMAN_MACHINE_NAME}"'")
            and (.CPUs | tonumber  >= '"${PODMAN_MACHINE_VCPUS}"')
            and (.Memory | tonumber >= '"$((PODMAN_MACHINE_MEMORY_MB * 1024 * 1024))"')
            and (.DiskSize | tonumber >= '"$((PODMAN_MACHINE_DISK_GB * 1024 * 1024 * 1024))"')
        ) | 
        length
    '

    msg_info "Checking if podman machine matches specifications..."
    if [[ $(echo "${podman_machine_list}" | jq -r "${jq_query}") -eq 0 ]]; then
        msg_error "%b" \
            "Insufficient podman machine!\n" \
            "Please delete the existing podman machine with:\n" \
            "\t${NC}podman machine rm ${PODMAN_MACHINE_NAME}\n" \
            "${BOLD_RED}and re-run this script" 1>&2
        exit 1
    fi

    # Check if the podman machine is already running
    msg_info "Checking if podman machine is running..."
    if [[ $(echo "${podman_machine_list}" | jq -r '.[] | select(.Running==true and .Name=="'"${PODMAN_MACHINE_NAME}"'") | length') -eq 0 ]]; then
        msg_change "Starting podman machine: ${PODMAN_MACHINE_NAME}"
        podman machine start "${PODMAN_MACHINE_NAME}"
        sleep 3
    fi

    # Check if podman machine is running in rootless mode
    if [[ -n "$(podman info --format=json | jq -r 'select(.host.security.rootless == false)')" ]]; then
        msg_error  "Rootful podman machine detected!\n${NC}" \
            "${BOLD_CYAN}Please disable rootful podman machine with:\n${NC}" \
            "\t${NC}podman machine stop\n" \
            "\t${NC}podman machine set --rootful=false ${PODMAN_MACHINE_NAME}\n"\
            "${BOLD_RED}and re-run this script" 1>&2
        exit 1
    fi
}

function init_podman_machine {
    msg_change "Initializing podman machine..."
    podman machine init \
        --cpus "${PODMAN_MACHINE_VCPUS}" \
        --disk-size "${PODMAN_MACHINE_DISK_GB}" \
        --memory "${PODMAN_MACHINE_MEMORY_MB}" \
        "${PODMAN_MACHINE_NAME}"
}

function msg_info {
    printf "${BOLD_CYAN}INFO: %b${NC}\n" "$@"
}

function msg_change {
    printf "${BOLD_YELLOW}CHANGE: %b${NC}\n" "$@"
}

function msg_error {
    printf "${BOLD_RED}ERROR: %b${NC}\n" "$@" 1>&2
}

#shellcheck disable=SC2068,SC2199
if [[ -z "$@" ]]; then main; else $@; fi
