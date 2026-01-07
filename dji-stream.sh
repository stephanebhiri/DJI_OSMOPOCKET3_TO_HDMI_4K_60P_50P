#!/bin/bash

# DJI Osmo Pocket 3 streaming wrapper script
# Exits cleanly on errors so systemd can restart

exec /usr/bin/gst-launch-1.0 \
    libuvch264src index=0 ! video/x-h264,width=3840,height=2160,framerate=50/1 ! \
    h264parse ! mppvideodec ! \
    kmssink plane-id=72 connector-id=215 sync=false \
    alsasrc device=hw:4,0 ! audioconvert ! audioresample ! alsasink device=hw:1,0
