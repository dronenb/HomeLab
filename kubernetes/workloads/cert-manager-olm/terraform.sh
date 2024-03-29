#!/bin/bash

set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../../bash/bitwarden_env.sh"

arg="${1:-pre}"

pushd "terraform/${arg}" > /dev/null || exit 1

PROJECT_NAME="Ben-HomeLab"

if [[ ! -x $(which gcloud) ]]; then
    echo -e \
        "gcloud CLI not installed! Please install on macOS with:\n" \
        "\tbrew install --cask google-cloud-sdk\n" \
        "...or install using Google's documentation" \
        1>&2
    exit 1
elif [[ ! -x $(which terraform) ]]; then
    echo -e \
        "terraform CLI not installed! Please install on macOS with:\n" \
        "\tbrew install terraform\n" \
        "...or install using HashiCorp's documentation" \
        1>&2
    exit 1
fi

login_filter='.[] | select(.status == "ACTIVE") | length'
auths=$(gcloud auth list --format=json)
# Check if logged in
if [[ $(echo "${auths}" | jq -r "${login_filter}") -le 0 ]]; then
    gcloud auth application-default login
fi

# Get list of projects
projects=$(gcloud projects list --format=json)
proj_id_filter='.[] |select(.name=="'"${PROJECT_NAME}"'") | .projectId'
TF_VAR_homelab_project_id=$(echo "${projects}" | jq -r "${proj_id_filter}")
if [[ -z "${TF_VAR_homelab_project_id}" || "${TF_VAR_homelab_project_id}" == "null" ]]; then
    echo "Project does not exist!" 1>&2
    exit 1
fi
export TF_VAR_homelab_project_id

# Target the project
gcloud config set project "${TF_VAR_homelab_project_id}"
terraform apply -auto-approve
