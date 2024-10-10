#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

PROJECT_NAME="Ben-HomeLab"

if ! command -v gcloud > /dev/null; then
    echo -e \
        "gcloud CLI not installed! Please install on macOS with:\n" \
        "\tbrew install --cask google-cloud-sdk\n" \
        "...or install using Google's documentation" \
        1>&2
    exit 1
elif ! command -v tofu > /dev/null; then
    echo -e \
        "OpenTofu CLI not installed! Please install on macOS with:\n" \
        "\tbrew install opentofu\n" \
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

#shellcheck disable=SC1091
source ../bash/bitwarden_env.sh

pushd tofu || exit 1
tofu plan -var-file=variables.tfvars -out /tmp/plan
tofu apply /tmp/plan
