#!/usr/bin/env bash
set -euo pipefail

# Pocket 3 USB audio -> the RK3588 HDMI1 sound card paired with HDMI-A-2.
# Named ALSA cards remain stable if other USB devices change card numbers.
exec /usr/bin/gst-launch-1.0 -q \
    alsasrc device=hw:CARD=DJIPocket3,DEV=0 ! \
    audio/x-raw,format=S16LE,rate=48000,channels=2 ! \
    queue max-size-time=200000000 leaky=downstream ! \
    alsasink device=hw:CARD=rockchiphdmi1,DEV=0 sync=false
