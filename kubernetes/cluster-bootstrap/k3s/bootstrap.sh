#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"
pushd terraform || exit 1
terraform plan -out /tmp/tf.plan
terraform apply /tmp/tf.plan
popd || exit 1
pushd ansible || exit 1
local_ansible_dir="${PWD}"
pushd "${SCRIPT_DIR}/../../../ansible-global" || exit 1
# ansible-galaxy install --force -r "${local_ansible_dir}/requirements.yaml"
ansible-playbook "${local_ansible_dir}/k3s-server.yaml"
