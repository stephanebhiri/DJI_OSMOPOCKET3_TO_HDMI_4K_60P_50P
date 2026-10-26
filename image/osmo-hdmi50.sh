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

# Connector IDs and EDID mode indices can change across boots and systems.
read -r connector_id mode_index < <(/usr/bin/modetest -M rockchip -c | /usr/local/bin/parse-hdmi-mode.sh) || {
    echo 'HDMI-A-2 does not offer 1080i50' >&2
    exit 1
}
echo "HDMI-A-2 connector $connector_id 1080i50 EDID mode #$mode_index"
# -d releases DRM master for the GStreamer KMS sink.
exec /bin/bash -c "tail -f /dev/null | /usr/bin/modetest -M rockchip -s ${connector_id}:#${mode_index} -d"
