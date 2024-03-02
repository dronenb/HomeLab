#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"
pushd tofu || exit 1
tofu plan -out /tmp/tf.plan
tofu apply /tmp/tf.plan
popd || exit 1
pushd ansible || exit 1
local_ansible_dir="${PWD}"
pushd "${SCRIPT_DIR}/../../../ansible-global" || exit 1
ansible-galaxy install --force -r "${local_ansible_dir}/requirements.yaml"
ansible-playbook "${local_ansible_dir}/k3s-server.yaml"
scp 10.91.1.5:~/.kube/config ~/.kube/config
chmod 600 ~/.kube/config
for folder in kube-vip olm cert-manager-olm ingress-nginx argocd-olm; do
    cd "${SCRIPT_DIR}/../../workloads/${folder}"
    ./apply.sh
done
