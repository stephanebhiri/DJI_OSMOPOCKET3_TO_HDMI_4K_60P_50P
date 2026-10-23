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

# EDID mode indices change when the downstream screen or converter changes.
# Select 1080i50 by timing on HDMI-A-2, then keep modetest alive to retain it.
mode_index=$(/usr/bin/modetest -M rockchip -c | awk '
    /^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+connected[[:space:]]+HDMI-A-2/ {found=1; next}
    found && /^[[:space:]]*#[0-9]+[[:space:]]+1920x1080i[[:space:]]+50[.]00[[:space:]]/ {
        sub(/^#/, "", $1); print $1; exit
    }
    found && /^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]/ {exit}
')
[[ $mode_index =~ ^[0-9]+$ ]] || { echo 'HDMI-A-2 does not offer 1080i50' >&2; exit 1; }
echo "HDMI-A-2 1080i50 EDID mode #$mode_index"
# -d releases DRM master for the GStreamer KMS sink.
exec /bin/bash -c "tail -f /dev/null | /usr/bin/modetest -M rockchip -s 236:#${mode_index} -d"
