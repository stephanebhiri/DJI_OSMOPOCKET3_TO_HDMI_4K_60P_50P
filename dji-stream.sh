#!/bin/bash
# DJI Osmo Pocket 3 streaming - 4K 50fps
# Configuration validée sur Ubuntu Noble 24.04 avec GStreamer 1.24

exec /usr/bin/gst-launch-1.0 \
    libuvch264src index=0 ! video/x-h264,width=3840,height=2160,framerate=50/1 ! \
    h264parse ! mppvideodec ! \
    kmssink plane-id=73 connector-id=215 sync=false
