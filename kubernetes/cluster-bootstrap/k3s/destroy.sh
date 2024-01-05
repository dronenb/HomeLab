#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"
cd terraform || exit 1
terraform destroy

