#!/usr/bin/env bash
set -euo pipefail

parser="$(dirname "$0")/parse-encoder-mask.sh"
fixture=$(mktemp)
trap 'rm -f "$fixture"' EXIT
cat >"$fixture" <<'ENCODERS'
Encoders:
id crtc type possible crtcs possible clones
216 0 TMDS 0x00000001 0x00000002
235 130 TMDS 0x00000002 0x00000004
ENCODERS

if [[ $("$parser" 235 <"$fixture") != 0x00000002 ]]; then
    echo 'Wrong HDMI-A-2 encoder CRTC mask' >&2
    exit 1
fi
if "$parser" 999 <"$fixture" >/dev/null 2>&1; then
    echo 'Accepted an unknown encoder' >&2
    exit 1
fi
echo 'Encoder CRTC mask selection: PASS'
