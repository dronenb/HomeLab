#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../bash/bitwarden_env.sh"
cd ansible || exit 1
local_ansible_dir=$PWD
cd ~/workspace/Homelab/ansible-global
ansible-galaxy install -r "$local_ansible_dir/requirements.yaml"
ansible-playbook "$local_ansible_dir/steamdeck.yaml"
