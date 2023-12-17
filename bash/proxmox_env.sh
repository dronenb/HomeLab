#!/bin/bash
# shellcheck disable=SC1091
source "$HOME/workspace/HomeLab/bash/bitwarden_env.sh"

pm_entry=$(bw get item fh-proxmox0)
PM_USER="$(echo "$pm_entry" | jq -r '.login.username')@pam"; export PM_USER
export PROXMOX_VE_USERNAME=PM_USER
PM_PASS="$(echo "$pm_entry" | jq -r '.login.password')"; export PM_PASS
export PROXMOX_VE_PASSWORD=PM_PASS
PM_API_URL=$(echo "$pm_entry" | jq -r '.login.uris[0].uri')/api2/json; export PM_API_URL
