#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# Scrub node IP's from known_hosts
if nc -vz "$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's/^https:\/\///' | sed 's/\:6443//')" 6443 > /dev/null 2>&1; then
    for ip in $(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'); do
        ssh-keygen -R "${ip}"
    done
fi
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"
cd tofu || exit 1
tofu destroy
