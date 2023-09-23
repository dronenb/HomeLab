#!/bin/bash
if [[ -z "$BW_SESSION" ]]; then
    BW_SESSION=$(bw unlock --raw)
    export BW_SESSION
fi
