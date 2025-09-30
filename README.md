# DJI Osmo Pocket 3 - Hardware Accelerated 4K Streaming on Linux

Hardware-accelerated H264 streaming from DJI Osmo Pocket 3 to HDMI with Rockchip MPP decoder on ARM64 Linux (OrangePi 5 Plus / RK3588).

## Features

- ✅ **4K 50fps H264** streaming from DJI Osmo Pocket 3
- ✅ **Hardware decode** using Rockchip MPP (Media Process Platform)
- ✅ **Zero-copy NV12** display via DRM/KMS overlay plane
- ✅ **USB audio** routing to HDMI output
- ✅ **~30% CPU usage** for 4K 50fps (vs 100%+ software decode)
- ✅ **Systemd service** for auto-start at boot

## Hardware Requirements

- **SoC**: Rockchip RK3588 (tested on OrangePi 5 Plus)
- **Camera**: DJI Osmo Pocket 3
- **OS**: Armbian 25.8.1 Debian 12 (Bookworm) or similar
- **Kernel**: 6.1+ with DRM/KMS and Rockchip MPP support

## System Architecture

```
DJI Osmo Pocket 3 (USB)
    ↓ H264 4K 50fps via UVC H264
libuvch264src (GStreamer)
    ↓ H264 stream
mppvideodec (Rockchip MPP hardware decoder)
    ↓ NV12 decoded frames
kmssink (DRM/KMS overlay plane - zero CPU conversion)
    ↓
HDMI Output (4K 50fps)

Audio: USB → ALSA → HDMI
```

## Key Components

### 1. libuvch264src (BELABOX fork)
Custom GStreamer plugin for DJI UVC H264 cameras with improved resolution/framerate negotiation.

### 2. Rockchip MPP (Media Process Platform)
Hardware video decoder using dedicated VPU cores on RK3588.

### 3. gstreamer-rockchip
GStreamer plugins providing `mppvideodec` element for hardware H264 decode.

### 4. DRM/KMS Overlay Planes
Direct NV12 rendering to hardware overlay plane, bypassing RGB conversion.

## Installation

### Quick Install (Automated)

```bash
git clone https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P.git
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
./install.sh
```

The script will:
1. Install all prerequisites
2. Build and install Rockchip MPP
3. Build and install gstreamer-rockchip (mppvideodec)
4. Build and install libuvch264src (BELABOX fork)
5. Install udev rules
6. Install systemd service

After installation, you must configure plane-id, connector-id, and audio devices (see post-install instructions).

### Manual Installation

### Prerequisites

```bash
sudo apt-get update
sudo apt-get install -y \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-alsa \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-bad1.0-dev \
    libdrm-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    cmake \
    meson \
    ninja-build \
    pkg-config \
    git \
    build-essential \
    autoconf \
    automake \
    libtool \
    autopoint \
    gettext \
    libdrm-tests
```

### 1. Install Rockchip MPP

```bash
cd /tmp
git clone https://github.com/rockchip-linux/mpp.git rockchip-mpp
cd rockchip-mpp
# Tested with commit 4ed4f778 (2025-09-10)
cmake -DRKPLATFORM=ON -DHAVE_DRM=ON
make -j$(nproc)
sudo make install
sudo ldconfig

# Verify installation
ldconfig -p | grep rockchip_mpp
```

### 2. Install gstreamer-rockchip

```bash
cd /tmp
git clone https://github.com/Caesar-github/gstreamer-rockchip.git
cd gstreamer-rockchip
meson setup build
cd build
meson compile
sudo meson install

# Verify mppvideodec plugin is installed
gst-inspect-1.0 mppvideodec
```

### 3. Install libuvch264src (BELABOX fork)

```bash
cd /tmp
git clone https://github.com/BELABOX/gstlibuvch264src.git
cd gstlibuvch264src
# Tested with commit 159222b "Implement negotiating framerate and resolution" (Jan 2025)

# Build libuvc
cd libuvc
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)
sudo make install
sudo ldconfig

# Build libuvch264src
cd ../../libuvch264src
meson setup build --prefix=/usr
meson compile -C build
sudo meson install -C build

# Verify libuvch264src plugin is installed
gst-inspect-1.0 libuvch264src
```

### 4. Set DMA Heap Permissions

Create udev rule for persistent DMA heap access:

```bash
sudo tee /etc/udev/rules.d/99-dma-heap.rules << 'EOF'
KERNEL=="dma_heap", MODE="0666"
KERNEL=="system", MODE="0666"
KERNEL=="system-uncached", MODE="0666"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
```

Or set manually after each boot:
```bash
sudo chmod 666 /dev/dma_heap/*
sudo chmod 666 /dev/mpp_service
```

### 5. Find DRM Connector and Plane IDs

```bash
# Install modetest
sudo apt-get install -y libdrm-tests

# List DRM planes and find one supporting NV12
sudo modetest -M rockchip -p | grep -B 1 "NV12"

# Example output:
# 73	0	0	0,0		0,0	0       	0x00000001
#   formats: ... NV12 ...

# Note plane-id (e.g., 73)

# Find HDMI connector
sudo modetest -M rockchip | grep "HDMI.*connected"
# Example: 217	216	connected	HDMI-A-1

# Note connector-id (e.g., 217)
```

### 6. Test Pipeline

```bash
# Test 4K 50fps with audio
sudo gst-launch-1.0 \
    libuvch264src index=0 ! video/x-h264,width=3840,height=2160,framerate=50/1 ! \
    h264parse ! mppvideodec ! \
    kmssink plane-id=73 connector-id=217 sync=false \
    alsasrc device=hw:4,0 ! audioconvert ! audioresample ! alsasink device=hw:1,0
```

Adjust:
- `plane-id` and `connector-id` based on your `modetest` output
- `alsasrc device=hw:X,0` - your DJI audio capture device (check with `arecord -l`)
- `alsasink device=hw:Y,0` - your HDMI audio output (check with `aplay -l`)

### 7. Install Systemd Service

Copy files from repo:
```bash
sudo cp dji-stream.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/dji-stream.sh
sudo cp dji-h264-stream.service /etc/systemd/system/
sudo cp 99-dji-camera.rules /etc/udev/rules.d/

sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo systemctl enable dji-h264-stream.service
sudo systemctl start dji-h264-stream.service
```

The service will:
- Auto-start on boot
- Restart automatically on failure (3 second delay)
- Restart when camera is reconnected (via udev rule)

## Troubleshooting

### "not-negotiated" error

libuvch264src can be sensitive to format negotiation. Try:
1. Reconnect the camera
2. Use auto-negotiation (remove format caps): `libuvch264src index=0 ! h264parse ! ...`
3. Check supported formats: `v4l2-ctl -d /dev/video0 --list-formats-ext`

### No video output

1. Verify DRM plane supports NV12: `modetest -M rockchip -p | grep -B 1 "NV12"`
2. Try different plane-id values
3. Check kmssink gets correct connector-id
4. Test with videotestsrc first:
   ```bash
   gst-launch-1.0 videotestsrc ! video/x-raw,format=NV12 ! kmssink plane-id=73 connector-id=217
   ```

### High CPU usage

If CPU > 40%, hardware decode may not be working:
1. Check DMA heap permissions: `ls -la /dev/dma_heap/`
2. Verify MPP is used: logs should show `hal_h264d_vdpu34x`
3. Ensure `mppvideodec` is in pipeline (not `avdec_h264`)

### No audio

1. List audio devices: `arecord -l` and `aplay -l`
2. Test audio capture: `arecord -D hw:4,0 -f cd test.wav`
3. Test audio playback: `aplay -D hw:1,0 test.wav`
4. Adjust `alsasrc device=` and `alsasink device=` in pipeline

### Stride mismatch warnings

Warnings like `mpp_buf_slot: mismatch h_stride_by_pixel` are normal and don't affect functionality. They indicate internal stride differences handled by MPP.

### Camera reconnection not working

If the stream doesn't restart after unplugging/replugging the camera:
1. Check udev rule is installed: `ls /etc/udev/rules.d/99-dji-camera.rules`
2. Reload udev: `sudo udevadm control --reload-rules`
3. Test manually: `sudo systemctl restart dji-h264-stream.service`
4. Check service status: `sudo systemctl status dji-h264-stream.service`

## Performance

| Configuration | Resolution | FPS | CPU Usage | Notes |
|--------------|------------|-----|-----------|-------|
| Software decode + fbdevsink | 1080p | 30 | 100%+ | videoconvert NV12→RGB |
| MPP + fbdevsink | 1080p | 30 | 100%+ | videoconvert NV12→RGB |
| MPP + kmssink (wrong plane) | 1080p | 30 | 100%+ | Falls back to primary plane |
| **MPP + kmssink (overlay)** | **1080p** | **30** | **15%** | ✅ Hardware decode + zero-copy |
| **MPP + kmssink (overlay)** | **4K** | **50** | **29%** | ✅ Hardware decode + zero-copy |
| **MPP + kmssink (overlay)** | **4K** | **60** | **37%** | ✅ Hardware decode + zero-copy |

## Supported Resolutions/Framerates

Based on DJI Osmo Pocket 3 + libuvch264src:

| Resolution | Framerate | Status |
|-----------|-----------|--------|
| 720p | 30 | ✅ |
| 1080p | 30 | ✅ |
| 1080p | 50 | ❌ Not negotiated |
| 1080p | 60 | ❌ Not negotiated |
| 4K | 30 | ✅ |
| 4K | 50 | ✅ |
| 4K | 60 | ✅ (auto-negotiated) |

## Technical Details

### Why DRM/KMS Overlay Planes?

Traditional framebuffer (`fbdevsink`) requires RGB format. Converting NV12→RGB in software is CPU-intensive:
- 4K NV12→RGB conversion: ~90% CPU
- 1080p NV12→RGB conversion: ~50% CPU

DRM/KMS overlay planes accept NV12 directly, allowing zero-copy rendering from hardware decoder to display.

### Why libuvch264src?

DJI cameras use a custom UVC H264 implementation that doesn't work with standard V4L2 capture. libuvch264src provides userspace UVC H264 support specifically for these cameras.

### Why Rockchip MPP?

Software H264 decode (`avdec_h264`) consumes ~100% CPU for 1080p. Rockchip MPP uses dedicated VPU hardware cores, reducing CPU to ~20-40% depending on resolution/framerate.

## Known Limitations

1. **libuvch264src negotiation**: Only specific resolution/framerate combinations work when explicitly requested. Auto-negotiation is more reliable.

2. **4K stride mismatch**: MPP outputs with stride 2304 instead of expected 1920 for 4K, causing warnings. Functionality not affected.

3. **DMA heap permissions**: Reset on reboot. Requires udev rule or manual chmod.

4. **No RGA support**: Hardware scaler/converter (RGA) not available in current gstreamer-rockchip builds, limiting format conversion options.

## References

- [Rockchip MPP](https://github.com/rockchip-linux/mpp)
- [gstreamer-rockchip](https://github.com/Caesar-github/gstreamer-rockchip)
- [BELABOX libuvch264src](https://github.com/BELABOX/gstlibuvch264src)
- [GStreamer kmssink documentation](https://gstreamer.freedesktop.org/documentation/kms/kmssink.html)
- [DRM/KMS kernel documentation](https://www.kernel.org/doc/html/latest/gpu/drm-kms.html)

## License

MIT License - feel free to use and modify.

## Contributing

Issues and pull requests welcome!
