#!/usr/bin/env bash
set -euo pipefail

for attempt in {1..60}; do
    if [[ $(cat /sys/class/drm/card0-HDMI-A-2/status 2>/dev/null) == connected ]]; then
        break
    fi
    sleep 1
done

if [[ $(cat /sys/class/drm/card0-HDMI-A-2/status 2>/dev/null) != connected ]]; then
    echo 'HDMI-A-2 is not connected' >&2
    exit 1
fi

# Keep modetest alive so it retains the EDID-provided 1080i50 mode. Its
# -d option releases DRM master for the GStreamer KMS sink.
exec /bin/bash -c 'tail -f /dev/null | /usr/bin/modetest -M rockchip -s 236:#13 -d'
