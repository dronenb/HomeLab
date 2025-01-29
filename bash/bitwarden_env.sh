#!/usr/bin/env bash
function bwu() {
    export NODE_OPTIONS="--no-deprecation"
    export BITWARDENCLI_APPDATA_DIR="${HOME}/.bitwarden"
    if [[ $(uname) == "Darwin" ]]; then
        BW_SESSION=$(security find-generic-password -a "${USER}" -s BW_SESSION -w)
    fi
    export BW_SESSION
    BW_STATUS=$(bw status | jq -r .status)
    case "${BW_STATUS}" in
    "unauthenticated")
        echo "Logging into BitWarden"
        unset BW_SESSION
        BW_SESSION=$(bw login --raw)
        export BW_SESSION
        if [[ $(uname) == "Darwin" ]]; then
            security add-generic-password -U -a "${USER}" -s BW_SESSION -w "${BW_SESSION}"
        fi
        ;;
    "locked")
        echo "Unlocking Vault"
        unset BW_SESSION
        BW_SESSION=$(bw unlock --raw)
        export BW_SESSION
        if [[ $(uname) == "Darwin" ]]; then
            security add-generic-password -U -a "${USER}" -s BW_SESSION -w "${BW_SESSION}"
        fi
        ;;
    "unlocked")
        echo "Vault is unlocked"
        ;;
    *)
        echo "Unknown Login Status: ${BW_STATUS}"
        return 1
        ;;
    esac
    bw sync
    BW_EMAIL=$(bw status | jq -r '.userEmail')
    export BW_EMAIL
}
bwu
