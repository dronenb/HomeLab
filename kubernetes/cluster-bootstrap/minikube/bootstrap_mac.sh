#!/bin/bash

set -e
# set -x

# Colors
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
YELLOW='\033[0;33m'

PODMAN_MACHINE_VCPUS=4
PODMAN_MACHINE_MEMORY_MB=4096
PODMAN_MACHINE_DISK_GB=20
PODMAN_MACHINE_NAME="podman-machine-default"

function main {
    install_prereqs
    chk_podman_machine
    bootstrap_minikube
}

function install_prereqs {
    echo -e "${CYAN}Checking prerequities...${NC}"
    if [[ ! -x $(which brew) ]]; then
        echo "${RED}Homebrew must be installed! Install from brew.sh${NC}" 1>&2
        exit 1
    fi
    for formula in $(brew list --formula -1); do
        if [[ "${formula}" == "podman" ]]; then
            PODMAN_INSTALLED=1
        elif [[ "${formula}" == "minikube" ]]; then
            MINIKUBE_INSTALLED=1
        elif [[ "${formula}" == "jq" ]]; then
            JQ_INSTALLED=1
        fi
    done
    pkgs_to_install=()
    if [[ -z "${PODMAN_INSTALLED}" ]]; then
        pkgs_to_install+=("podman")
    fi
    if [[ -z "${MINIKUBE_INSTALLED}" ]]; then
        pkgs_to_install+=("minikube")
    fi
    if [[ -z "${JQ_INSTALLED}" ]]; then
        pkgs_to_install+=("jq")
    fi
    if [[ "${#pkgs_to_install[@]}" -gt 0 ]]; then
        echo -e "${YELLOW}Updating homebrew...${NC}"
        brew update
    fi
    for formula in "${pkgs_to_install[@]}"; do
        echo -e "${YELLOW}Installing prerequisite homebrew formulas...${NC}"
        brew install "${formula}"
    done
}

function chk_podman_machine {
    echo -e "${CYAN}Checking on podman machine....${NC}"
    podman_machine_list=$(podman  machine list --format=json)
    # Check if the default machine has been created
    if [[ $(echo "${podman_machine_list}" | jq -r 'select(.[].Name=="'"${PODMAN_MACHINE_NAME}"'") | length') -eq 0 ]]; then
        echo -e "${CYAN}Podman machine \"${PODMAN_MACHINE_NAME}\" does not exist!${NC}"
        podman_machine_init
        podman_machine_list=$(podman machine list --format=json)
    fi

    # Check if the default machine meets the system requirements
    jq_query='
        .[] | 
        select(
            (.Name=="'"${PODMAN_MACHINE_NAME}"'")
            and (.CPUs >= '"${PODMAN_MACHINE_VCPUS}"')
            and (.Memory | tonumber >= '"$((PODMAN_MACHINE_MEMORY_MB * 1024 * 1024))"')
            and (.DiskSize | tonumber >= '"$((PODMAN_MACHINE_DISK_GB * 1024 * 1024 * 1024))"')
        ) | 
        length
    '

    if [[ $(echo "${podman_machine_list}" | jq -r "${jq_query}") -eq 0 ]]; then
        printf "%b" \
            "${RED}Insufficient podman machine!\n" \
            "Please delete the existing podman machine with:\n" \
            "\t${NC}podman machine rm ${PODMAN_MACHINE_NAME}\n" \
            "${RED}and re-run this script${NC}" 1>&2
        exit 1
    fi

    # Check if the podman machine is already running
    echo -e "${CYAN}Checking if podman machine is running...${NC}"
    if [[ $(echo "${podman_machine_list}" | jq -r '.[] | select(.Running==true and .Name=="'"${PODMAN_MACHINE_NAME}"'") | length') -eq 0 ]]; then
        echo -e "${YELLOW}Starting podman machine: ${PODMAN_MACHINE_NAME}${NC}"
        podman machine start "${PODMAN_MACHINE_NAME}"
        sleep 3
    fi

    # Check if podman machine is running in rootless mode
    if [[ -n "$(podman info --format=json | jq -r 'select(.host.security.rootless == false)')" ]]; then
        printf "%b" \
            "${RED}Rootful podman machine detected!\n"\
            "Please disable rootful podman machine with:\n"\
            "\t${NC}podman machine stop\n"\
            "\t${NC}podman machine set --rootful=false ${PODMAN_MACHINE_NAME}\n"\
            "${RED}and re-run this script${NC}" 1>&2
        exit 1
    fi
}

function podman_machine_init {
    echo -e "${YELLOW}Initializing podman machine...${NC}"
    podman machine init \
        --cpus "${PODMAN_MACHINE_VCPUS}" \
        --disk-size "${PODMAN_MACHINE_DISK_GB}" \
        --memory "${PODMAN_MACHINE_MEMORY_MB}" \
        "${PODMAN_MACHINE_NAME}"
}

function bootstrap_minikube {
    while true; do
        echo -ne "${YELLOW}This process will delete and recreate any existing minikube cluster.\nWould you like to continue? [y/n]: ${NC}"
        read -r yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit 0;;
            * ) echo -ne "Please answer y/n";;
        esac
    done
    minikube config set rootless true
    minikube config set driver podman
    minikube config set container-runtime containerd
    minikube delete
    minikube start
    kubectl config use-context minikube
}

main "$@"
