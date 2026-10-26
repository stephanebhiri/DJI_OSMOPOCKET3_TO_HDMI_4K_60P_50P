#!/usr/bin/env bash
set -euo pipefail

parser="$(dirname "$0")/parse-kms-plane.py"
fixture=$(mktemp)
trap 'rm -f "$fixture"' EXIT

cat >"$fixture" <<'PLANES'
Planes:
id crtc fb CRTC x,y x,y gamma size possible crtcs
73 0 0 0,0 0,0 0 0x00000001
  formats: XR24 NV12
  props:
    8 type:
      enums: Overlay=0 Primary=1 Cursor=2
      value: 2
    9 NAME:
      values: Smart0-win0=0x1
114 0 0 0,0 0,0 0 0x00000002
  formats: XR24 NV12
  props:
    8 type:
      enums: Overlay=0 Primary=1 Cursor=2
      value: 2
    9 NAME:
      values: Esmart1-win0=0x400
    10 FEATURE:
      values: scale=0x1
    11 INPUT_WIDTH:
      values: 0 4096
    12 INPUT_HEIGHT:
      values: 0 4320
215 0 0 0,0 0,0 0 0x00000002
  formats: XR24 NV12
  props:
    8 type:
      enums: Overlay=0 Primary=1 Cursor=2
      value: 2
    9 NAME:
      values: Smart1-win0=0x800
PLANES

if [[ $(python3 "$parser" 0x2 <"$fixture") != 114 ]]; then
    echo 'Did not select the NV12 overlay for CRTC mask 0x2' >&2
    exit 1
fi
if python3 "$parser" 0x4 <"$fixture" >/dev/null 2>&1; then
    echo 'Accepted a CRTC without an NV12 overlay' >&2
    exit 1
fi
echo 'Dynamic NV12 plane selection: PASS'
