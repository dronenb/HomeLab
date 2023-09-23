#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"
cd terraform || exit 1
terraform plan -var-file="vars.tfvars" -out /tmp/tf.plan
terraform show -json /tmp/tf.plan  > /tmp/tf.json 
checkov -f /tmp/tf.json
terraform apply /tmp/tf.plan
cd "$HOME/workspace/Homelab/ansible-global" || exit 1
ansible-inventory -i inventory/ --graph --vars
