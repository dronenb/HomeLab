#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../../bash/proxmox_env.sh"
cloudinit_entry=$(bw get item cloudinit_creds)
TF_VAR_cloudinit_username=$(echo "$cloudinit_entry" | jq -r '.login.username'); export TF_VAR_cloudinit_username
TF_VAR_cloudinit_password=$(echo "$cloudinit_entry" | jq -r '.login.password'); export TF_VAR_cloudinit_password
