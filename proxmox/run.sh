#!/bin/bash
set -o errexit # Exit on any failure. Same as set -e
set -o pipefail # Return value of all commands in a pipe
# set -o nounset # Exit on undeclared variables. Same as set -u
# set -o xtrace # Command tracing. Same as set -x

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../bash/bitwarden_env.sh"

cd ansible || exit 1
local_ansible_dir="${PWD}"
cd "${SCRIPT_DIR}/../ansible-global" || exit 1
ansible-galaxy install --force -r "${local_ansible_dir}/requirements.yaml"
ansible-playbook "${local_ansible_dir}/proxmox.yaml"
