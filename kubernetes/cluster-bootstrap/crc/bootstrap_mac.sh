#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
# set -x

# Colors
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
YELLOW='\033[0;33m'

PULL_SECRET_FILEPATH="${HOME}/.config/containers/auth.json"

function main {
  install_prereqs
  unlock_bitwarden
  get_red_hat_pull_secret
  bootstrap_crc
  # If we want to expose the cluster to the network, we can use haproxy
  # enable_haproxy
  add_etc_hosts
  configure_kubectl
}

function install_prereqs {
  echo -e "${CYAN}Checking prerequities...${NC}"
  if ! command -v brew > /dev/null; then
    echo "${RED}Homebrew must be installed! Install from https://brew.sh ${NC}" 1>&2
    exit 1
  fi
  # Ensure brew services are installed by simply running "brew services" - https://github.com/Homebrew/homebrew-services/blob/aa377a5dbc924d6387483617f0b9ef285e418a94/README.md#L11
  brew services > /dev/null
  JQ_INSTALLED=0
  BW_INSTALLED=0
  OC_INSTALLED=0
  YQ_INSTALLED=0
  KUBECTL_INSTALLED=0
  HAPROXY_INSTALLED=0
  # CRC_INSTALLED=0
  for formula in $(brew list --formula -1 --full-name); do
    if [[ "${formula}" == "bitwarden-cli" ]]; then
      BW_INSTALLED=1
    # Eventually I'd like to upstream this and make it compile from source
    # see https://github.com/dronenb/homebrew-tap/pull/59
    # haven't figured out why it doesn't work yet
    # in the meantime, I can install Red Hat's package via a cask
    # elif [[ "${formula}" == "dronenb/tap/crc" ]]; then
    #   CRC_INSTALLED=1
    elif [[ "${formula}" == "jq" ]]; then
      JQ_INSTALLED=1
    elif [[ "${formula}" == "haproxy" ]]; then
      HAPROXY_INSTALLED=1
    elif [[ "${formula}" == "yq" ]]; then
      YQ_INSTALLED=1
    elif [[ "${formula}" == "kubernetes-cli" ]]; then
      KUBECTL_INSTALLED=1
    elif [[ "${formula}" == "openshift-cli" ]]; then
      OC_INSTALLED=1
    fi
  done
  CRC_INSTALLED=0
  for cask in $(brew list --cask -1 --full-name); do
    if [[ "${cask}" == "dronenb/tap/crc" ]]; then
      CRC_INSTALLED=1
    fi
  done
  pkgs_to_install=()
  if [[ "${JQ_INSTALLED}" -ne 1 ]]; then
    pkgs_to_install+=("jq")
  fi
  if [[ "${CRC_INSTALLED}" -ne 1 ]]; then
    pkgs_to_install+=("--cask dronenb/tap/crc")
  fi
  if [[ "${HAPROXY_INSTALLED}" -ne 1 ]]; then
    pkgs_to_install+=("haproxy")
  fi
  if [[ "${YQ_INSTALLED}" -ne 1 ]]; then
    pkgs_to_install+=("yq")
  fi
  if [[ "${OC_INSTALLED}" -ne 1 ]]; then
    pkgs_to_install+=("openshift-cli")
  fi
  if [[ "${KUBECTL_INSTALLED}" -ne 1 ]]; then
    pkgs_to_install+=("kubernetes-cli")
  fi
  if [[ "${BW_INSTALLED}" -ne 1 ]]; then
    pkgs_to_install+=("bitwarden-cli")
  fi
  if [[ "${#pkgs_to_install[@]}" -gt 0 ]]; then
    echo -e "${YELLOW}Updating homebrew...${NC}"
    brew update
  fi
  for formula in "${pkgs_to_install[@]}"; do
    echo -e "${YELLOW}Installing prerequisite homebrew formulas...${NC}"
    # shellcheck disable=SC2086
    brew install ${formula}
  done
}

function unlock_bitwarden {
  SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/env.sh"
}

function get_red_hat_pull_secret {
  # Red Hat pull secret
  bw_item_id="da9ee1bd-9391-42bd-8e23-b29b0014528d"
  bw_pull_secret_entry=$(bw get item "${bw_item_id}")
  if [[ $(jq  -r '.attachments | select(.[].fileName=="pull-secret") | length' <<< "${bw_pull_secret_entry}") -ne 1 ]]; then
    echo "Error: pull-secret attachment not found in Bitwarden entry" > /dev/stderr
    exit 1
  fi
  bw_attachment_id=$(jq -r '.attachments[] | select(.fileName=="pull-secret") | .id' <<< "${bw_pull_secret_entry}")
  red_hat_pull_secret_filename="$(realpath /tmp)/pull-secret.json"
  bw get attachment --itemid "${bw_item_id}" --output "${red_hat_pull_secret_filename}" "${bw_attachment_id}" > /dev/null
  if [[ -f "${PULL_SECRET_FILEPATH}" ]]; then
    yq -i 'del(.auths."default-route-openshift-image-registry.apps-crc.testing")' "${PULL_SECRET_FILEPATH}"
    mv "${PULL_SECRET_FILEPATH}" "${PULL_SECRET_FILEPATH}.bak"
    jq -s 'reduce .[] as $item ({}; .auths += $item.auths)' "${red_hat_pull_secret_filename}" "${PULL_SECRET_FILEPATH}.bak" > "${PULL_SECRET_FILEPATH}"
  else
    mkdir -p "$(dirname "${PULL_SECRET_FILEPATH}")"
    mv "${red_hat_pull_secret_filename}" "${PULL_SECRET_FILEPATH}"
  fi
}

function add_etc_hosts {
  if ! grep -qE "127\.0\.0\.1\s+host.containers.internal" /etc/hosts; then
    echo "${YELLOW}Adding host.containers.internal to /etc/hosts${NC}"
    cp /etc/hosts "${HOME}/hosts.bak"
    echo "127.0.0.1 host.containers.internal" | sudo tee -a /etc/hosts
  fi
}

function bootstrap_crc {
  while true; do
    echo -ne "${YELLOW}This process will delete and recreate any existing crc cluster.\nWould you like to continue? [y/n]: ${NC}"
    read -r yn
    case ${yn} in
      [Yy]* ) break;;
      [Nn]* ) exit 0;;
      * ) echo -ne "Please answer y/n";;
      esac
  done
  if crc delete -f > /dev/null; then
    echo -e "${YELLOW}Deleted existing crc cluster${NC}"
  fi
  crc config set consent-telemetry no
  crc config set preset openshift
  crc setup
  # Ensure crc daemon is running
  # if using Red Hat's crc, use the following command to ensure the daemon is started
  launchctl kickstart -k "gui/$(id -u)/com.redhat.crc.daemon"
  # brew services start dronenb/tap/crc
  crc start --pull-secret-file="${PULL_SECRET_FILEPATH}" > /dev/null # so credentials don't print to the console
}

function enable_haproxy {
  brew services stop haproxy
  CRC_IP=$(crc ip)
  # https://crc.dev/docs/networking/#setting-up-on-a-remote-server
  # intentionally not using privileged ports here
  # 6443 -> 36443
  # 80 -> 30080
  # 443 -> 30443
  cat <<EOF > /opt/homebrew/etc/haproxy.cfg
global
    log /dev/log local0

defaults
    balance roundrobin
    log global
    maxconn 100
    mode tcp
    timeout connect 5s
    timeout client 500s
    timeout server 500s

listen apps
    bind 0.0.0.0:30080
    server crcvm ${CRC_IP}:30080 check

listen apps_ssl
    bind 0.0.0.0:30443
    server crcvm  ${CRC_IP}:30443 check

listen api
    bind 0.0.0.0:36443
    server crcvm  ${CRC_IP}:36443 check
EOF
  brew services start haproxy
}

function configure_kubectl {
  # If we only wanted to configure kubectl for local use, we could have done this:
  # kubectl config use-context crc-admin
  # However, by default, the api.crc.testing entry in /etc/hosts on the host don't get propogated into podman machines
  # so if we want to do local development with crc and podman, we should use host.containers.internal
  # https://docs.podman.io/en/latest/markdown/podman-run.1.html#add-host-hostname-hostname-ip
  # this is because some utils, like for openshift console plugin development, use oc whoami --show-server to pass into the container
  # https://github.com/openshift/console-plugin-template/blob/659b03543adabc4b8a2fe90ba76a69ce6251b4c9/start-console.sh#L18
  # so... we need to login to the cluster using host.containers.internal
  # Hence why we added it to /etc/hosts on the host
  crc_creds=$(crc console --credentials --output=json)
  kubeadmin_username=$(jq -r '.clusterConfig.adminCredentials.username' <<< "${crc_creds}")
  kubeadmin_password=$(jq -r '.clusterConfig.adminCredentials.password' <<< "${crc_creds}")
  oc login --insecure-skip-tls-verify=true -u "${kubeadmin_username}" -p "${kubeadmin_password}" https://host.containers.internal:6443
  # login to the registry now that oc is configured
  oc registry login --insecure=true
}

# shellcheck disable=SC2068
main $@
