#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 1 ]] || exit 2
encoder_id=$1
[[ $encoder_id =~ ^[0-9]+$ ]] || exit 2
awk -v id="$encoder_id" '
    $1 == id && $4 ~ /^0x[0-9a-fA-F]+$/ {
        print $4
        found = 1
        exit
    }
    END { if (!found) exit 1 }
'
