#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../bash/bitwarden_env.sh"
cd ansible || exit 1

ansible-galaxy install -r requirements.yaml
ansible-playbook proxmox.yaml
