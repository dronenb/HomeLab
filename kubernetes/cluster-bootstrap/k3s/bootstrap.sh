#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../../bash/proxmox_env.sh"
cloudinit_entry=$(bw get item cloudinit_creds)
TF_VAR_cloudinit_username=$(echo "$cloudinit_entry" | jq -r '.login.username'); export TF_VAR_cloudinit_username
TF_VAR_cloudinit_password=$(echo "$cloudinit_entry" | jq -r '.login.password'); export TF_VAR_cloudinit_password
export TF_VAR_k3s_master_count=3
export TF_VAR_k3s_node_count=2
cd terraform || exit 1
terraform apply
