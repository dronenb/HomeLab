#!/bin/bash
# shellcheck disable=SC1091
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SCRIPT_DIR}/../bash/bitwarden_env.sh"
cd ansible || exit 1
ansible-galaxy install -r requirements.yaml
ansible-playbook steamdeck.yaml
