#!/bin/bash
set -e

echo "=========================================="
echo "DJI Osmo Pocket 3 - Installation Noble"
echo "Ubuntu Noble 24.04 / GStreamer 1.24"
echo "=========================================="
echo ""

# Check OS
if ! grep -q "noble\|bookworm" /etc/os-release; then
    echo "❌ ERROR: This script is for Ubuntu Noble 24.04 or Debian Bookworm only!"
    echo "   Debian Trixie is NOT supported (GStreamer 1.26 incompatible)"
    exit 1
fi

# Check GStreamer version
GSTREAMER_VERSION=$(gst-launch-1.0 --version 2>/dev/null | grep "GStreamer" | awk '{print $2}' || echo "not found")
if [[ "$GSTREAMER_VERSION" != 1.24.* ]]; then
    echo "⚠️  WARNING: GStreamer version is $GSTREAMER_VERSION"
    echo "   Expected 1.24.x for compatibility with libuvch264src (BELABOX fork)"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ OS check passed: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo "✅ GStreamer version: $GSTREAMER_VERSION"
echo ""

# Check if running on ARM64
if [ "$(uname -m)" != "aarch64" ]; then
    echo "ERROR: This script is designed for ARM64 architecture (RK3588)"
    exit 1
fi

# Install prerequisites
echo "[1/8] Installing prerequisites..."
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
echo "[2/8] Installing Rockchip MPP (from Gitee mirror)..."
cd /tmp
if [ -d "rockchip-mpp" ]; then
    rm -rf rockchip-mpp
fi
git clone https://gitee.com/hermanchen82/mpp.git rockchip-mpp
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
echo "[3/8] Installing gstreamer-rockchip..."
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

# Link plugins to system path
echo ""
echo "[4/8] Linking GStreamer plugins..."
sudo ln -sf /usr/local/lib/aarch64-linux-gnu/gstreamer-1.0/libgstrockchipmpp.so /usr/lib/aarch64-linux-gnu/gstreamer-1.0/
sudo ln -sf /usr/local/lib/aarch64-linux-gnu/gstreamer-1.0/libgstrkximage.so /usr/lib/aarch64-linux-gnu/gstreamer-1.0/
sudo ln -sf /usr/local/lib/aarch64-linux-gnu/gstreamer-1.0/libgstkmssrc.so /usr/lib/aarch64-linux-gnu/gstreamer-1.0/

# Verify mppvideodec
if ! gst-inspect-1.0 mppvideodec > /dev/null 2>&1; then
    echo "ERROR: mppvideodec plugin not found"
    exit 1
fi
echo "✓ gstreamer-rockchip installed"

# Install libuvch264src (BELABOX fork)
echo ""
echo "[5/8] Installing libuvch264src (BELABOX fork - Jan 2025)..."
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

# Install USB permissions (CRITICAL!)
echo ""
echo "[6/8] Installing USB permissions for DJI..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo cp "$SCRIPT_DIR/50-dji-usb.rules" /etc/udev/rules.d/
sudo cp "$SCRIPT_DIR/99-dma-heap.rules" /etc/udev/rules.d/
sudo cp "$SCRIPT_DIR/99-dji-camera.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
echo "✓ USB permissions installed"

# Set DMA heap permissions
echo ""
echo "[7/8] Setting DMA heap permissions..."
sudo chmod 666 /dev/dma_heap/* 2>/dev/null || true
sudo chmod 666 /dev/mpp_service 2>/dev/null || true
echo "✓ DMA heap permissions set"

# Configure boot parameters
echo ""
echo "Configuring boot parameters..."
if ! grep -q "usbcore.quirks=2ca3:0023:i" /boot/armbianEnv.txt; then
    echo "Adding USB quirk and HDMI settings to /boot/armbianEnv.txt..."
    sudo sed -i 's|extraargs=cma=256M|extraargs=usbcore.quirks=2ca3:0023:i video=HDMI-A-1:1920x1080i@50 cma=256M|' /boot/armbianEnv.txt
    echo "✓ Boot parameters updated (will apply after reboot)"
else
    echo "✓ Boot parameters already configured"
fi

# Install systemd service
echo ""
echo "[8/8] Installing systemd service..."
sudo cp "$SCRIPT_DIR/dji-stream.sh" /usr/local/bin/
sudo chmod +x /usr/local/bin/dji-stream.sh
sudo cp "$SCRIPT_DIR/dji-h264-stream.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dji-h264-stream.service
echo "✓ Systemd service installed and enabled"

echo ""
echo "=========================================="
echo "✅ Installation completed successfully!"
echo "=========================================="
echo ""
echo "⚠️  IMPORTANT: Reboot required for boot parameters to take effect"
echo ""
echo "After reboot:"
echo "1. Connect your DJI Osmo Pocket 3 via USB-C"
echo "2. Connect HDMI display"
echo "3. The service will start automatically"
echo ""
echo "Check status with:"
echo "  sudo systemctl status dji-h264-stream.service"
echo ""
echo "View logs with:"
echo "  sudo journalctl -u dji-h264-stream.service -f"
echo ""
echo "Reboot now? (y/N)"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo reboot
fi
