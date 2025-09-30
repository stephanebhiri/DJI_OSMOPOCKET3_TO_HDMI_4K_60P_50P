#!/bin/bash
set -e

echo "=========================================="
echo "DJI Osmo Pocket 3 Streaming Installation"
echo "=========================================="
echo ""

# Check if running on ARM64
if [ "$(uname -m)" != "aarch64" ]; then
    echo "ERROR: This script is designed for ARM64 architecture (RK3588)"
    exit 1
fi

# Install prerequisites
echo "[1/7] Installing prerequisites..."
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

# Install Rockchip MPP
echo ""
echo "[2/7] Installing Rockchip MPP..."
cd /tmp
if [ -d "rockchip-mpp" ]; then
    rm -rf rockchip-mpp
fi
git clone https://github.com/rockchip-linux/mpp.git rockchip-mpp
cd rockchip-mpp
mkdir -p build && cd build
cmake .. -DRKPLATFORM=ON -DHAVE_DRM=ON
make -j$(nproc)
sudo make install
sudo ldconfig

# Verify MPP
if ! ldconfig -p | grep -q rockchip_mpp; then
    echo "ERROR: Rockchip MPP installation failed"
    exit 1
fi
echo "✓ Rockchip MPP installed"

# Install gstreamer-rockchip
echo ""
echo "[3/7] Installing gstreamer-rockchip..."
cd /tmp
if [ -d "gstreamer-rockchip" ]; then
    rm -rf gstreamer-rockchip
fi
git clone https://github.com/Caesar-github/gstreamer-rockchip.git
cd gstreamer-rockchip
meson setup build
cd build
meson compile
sudo meson install

# Verify mppvideodec
if ! gst-inspect-1.0 mppvideodec > /dev/null 2>&1; then
    echo "ERROR: mppvideodec plugin not found"
    exit 1
fi
echo "✓ gstreamer-rockchip installed"

# Install libuvch264src (BELABOX fork)
echo ""
echo "[4/7] Installing libuvch264src (BELABOX fork)..."
cd /tmp
if [ -d "gstlibuvch264src" ]; then
    rm -rf gstlibuvch264src
fi
git clone https://github.com/BELABOX/gstlibuvch264src.git
cd gstlibuvch264src

# Build libuvc
cd libuvc
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)
sudo make install
sudo ldconfig

# Build libuvch264src
cd ../../libuvch264src
meson setup build --prefix=/usr
meson compile -C build
sudo meson install -C build

# Verify libuvch264src
if ! gst-inspect-1.0 libuvch264src > /dev/null 2>&1; then
    echo "ERROR: libuvch264src plugin not found"
    exit 1
fi
echo "✓ libuvch264src installed"

# Install udev rules
echo ""
echo "[5/7] Installing udev rules..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo cp "$SCRIPT_DIR/99-dma-heap.rules" /etc/udev/rules.d/
sudo cp "$SCRIPT_DIR/99-dji-camera.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
echo "✓ Udev rules installed"

# Set DMA heap permissions (temporary until reboot)
echo ""
echo "[6/7] Setting DMA heap permissions..."
sudo chmod 666 /dev/dma_heap/* 2>/dev/null || true
sudo chmod 666 /dev/mpp_service 2>/dev/null || true
echo "✓ DMA heap permissions set"

# Install systemd service
echo ""
echo "[7/7] Installing systemd service..."
sudo cp "$SCRIPT_DIR/dji-stream.sh" /usr/local/bin/
sudo chmod +x /usr/local/bin/dji-stream.sh
sudo cp "$SCRIPT_DIR/dji-h264-stream.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dji-h264-stream.service
echo "✓ Systemd service installed"

echo ""
echo "=========================================="
echo "Installation completed successfully!"
echo "=========================================="
echo ""
echo "IMPORTANT: You must configure plane-id and connector-id before starting the service."
echo ""
echo "1. Connect your DJI Osmo Pocket 3"
echo "2. Find your DRM connector and plane:"
echo "   sudo modetest -M rockchip | grep 'HDMI.*connected'"
echo "   sudo modetest -M rockchip -p | grep -B 1 'NV12'"
echo ""
echo "3. Edit /usr/local/bin/dji-stream.sh and update:"
echo "   - plane-id=XX"
echo "   - connector-id=YY"
echo ""
echo "4. Check audio devices:"
echo "   arecord -l  # Find DJI audio input (e.g., hw:4,0)"
echo "   aplay -l    # Find HDMI audio output (e.g., hw:1,0)"
echo ""
echo "5. Edit /usr/local/bin/dji-stream.sh and update:"
echo "   - alsasrc device=hw:X,0"
echo "   - alsasink device=hw:Y,0"
echo ""
echo "6. Start the service:"
echo "   sudo systemctl start dji-h264-stream.service"
echo ""
echo "7. Check status:"
echo "   sudo systemctl status dji-h264-stream.service"
echo ""
