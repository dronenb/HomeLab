#!/bin/bash
function bwu() {
    # https://github.com/bitwarden/clients/issues/6689#issuecomment-1787609205
    export NODE_OPTIONS="--no-deprecation"
    BW_SESSION=$(security find-generic-password -a "${USER}" -s BW_SESSION -w)
    export BW_SESSION
    BW_STATUS=$(bw status | jq -r .status)
    case "${BW_STATUS}" in
    "unauthenticated")
        echo "Logging into BitWarden"
        unset BW_SESSION
        BW_SESSION=$(bw login --raw)
        security add-generic-password -U -a "${USER}" -s BW_SESSION -w "${BW_SESSION}"
        ;;
    "locked")
        echo "Unlocking Vault"
        unset BW_SESSION
        BW_SESSION=$(bw unlock --raw)
        security add-generic-password -U -a "${USER}" -s BW_SESSION -w "${BW_SESSION}"
        ;;
    "unlocked")
        echo "Vault is unlocked"
        ;;
    *)
        echo "Unknown Login Status: ${BW_STATUS}"
        return 1
        ;;
    esac
    export BW_SESSION
    bw sync
}
bwu
BW_EMAIL=$(bw status | jq -r '.userEmail')
BITWARDENCLI_APPDATA_DIR="${HOME}/.bitwarden"
export BW_EMAIL BITWARDENCLI_APPDATA_DIR
