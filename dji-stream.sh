#!/bin/bash
# DJI Osmo Pocket 3 streaming - 4K 50fps
# Configuration validée sur Ubuntu Noble 24.04 avec GStreamer 1.24
set -euo pipefail

read -r connector_id mode_index < <(/usr/bin/modetest -M rockchip -c | /usr/local/bin/parse-hdmi-mode.sh) || {
    echo 'HDMI-A-2 1080i50 is unavailable' >&2
    exit 1
}

exec /usr/bin/gst-launch-1.0 --no-fault \
    libuvch264src index=0 ! video/x-h264,width=3840,height=2160,framerate=50/1 ! \
    h264parse ! mppvideodec ! \
    kmssink connector-id="$connector_id" plane-id=114 sync=true restore-crtc=false
