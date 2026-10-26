#!/usr/bin/env bash
set -euo pipefail

parser="$(dirname "$0")/parse-hdmi-mode.sh"

result=$("$parser" <<'MODETEST'
Connectors:
id encoder status name size (mm) modes encoders
215 214 connected HDMI-A-1 600x340 2 214
  modes:
    #0 1920x1080i 50.00 74250 1920 2448 2492 2640 1080 1084 1094 1125 flags: interlace
236 235 connected HDMI-A-2 600x340 3 235
  modes:
    #24 1920x1080i 50.00 74250 1920 2448 2492 2640 1080 1084 1094 1125 flags: interlace
MODETEST
)
[[ $result == '236 24' ]] || { echo "Wrong HDMI-A-2 selection: $result" >&2; exit 1; }

result=$("$parser" <<'MODETEST'
Connectors:
id encoder status name size (mm) modes encoders
301 300 connected HDMI-A-2 600x340 2 300
  modes:
    #0 1920x1080i 50.00 74250 1920 2448 2492 2640 1080 1084 1094 1125 flags: interlace
MODETEST
)
[[ $result == '301 0' ]] || { echo "Wrong renumbered mode selection: $result" >&2; exit 1; }

if "$parser" <<'MODETEST'
Connectors:
id encoder status name size (mm) modes encoders
236 235 connected HDMI-A-2 600x340 1 235
  modes:
    #0 1920x1080 50.00 74250 1920 2448 2492 2640 1080 1084 1094 1125
MODETEST
then
  echo 'Accepted a display without 1080i50' >&2
  exit 1
fi

echo 'HDMI-A-2 connector and 1080i50 selection passed'
