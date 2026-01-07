#!/bin/bash
set -e

echo "=========================================="
echo "DJI Osmo Pocket 3 → HDMI 4K 50fps"
echo "WORKING CONFIGURATION INSTALLER"
echo "=========================================="
echo ""
echo "⚠️  This installer will:"
echo "  - Install kernel 6.1.84-vendor-rk35xx (version 24.11.3)"
echo "  - Configure HDMI output to 1080p50"
echo "  - Install Rockchip MPP, gstreamer-rockchip, libuvch264src"
echo "  - Configure plane-id=72, connector-id=215"
echo "  - Set audio devices hw:4,0 (DJI) → hw:1,0 (HDMI)"
echo "  - HOLD kernel to prevent upgrades"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Check if running on ARM64
if [ "$(uname -m)" != "aarch64" ]; then
    echo "❌ ERROR: This script is designed for ARM64 architecture (RK3588)"
    exit 1
fi

# Check if on Armbian
if [ ! -f /etc/armbian-release ]; then
    echo "❌ ERROR: This script is designed for Armbian"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: Install correct kernel version
echo ""
echo "[1/9] Installing kernel 6.1.84-vendor-rk35xx (version 24.11.3)..."
sudo apt-get update
CURRENT_KERNEL=$(uname -r)
if [ "$CURRENT_KERNEL" != "6.1.84-vendor-rk35xx" ]; then
    echo "Installing kernel 6.1.84..."
    sudo apt-get install --allow-downgrades -y linux-image-vendor-rk35xx=24.11.3
    echo "⚠️  Kernel installed. System will need a reboot after installation."
    NEED_REBOOT=1
else
    echo "✓ Kernel 6.1.84 already installed"
fi

# Step 2: Hold kernel to prevent upgrades
echo ""
echo "[2/9] Holding kernel package to prevent upgrades..."
sudo apt-mark hold linux-image-vendor-rk35xx
echo "✓ Kernel package held"

# Step 3: Configure boot parameters
echo ""
echo "[3/9] Configuring boot parameters for 1080p50 HDMI..."
BOOT_CONFIG="/boot/armbianEnv.txt"
if [ -f "$BOOT_CONFIG" ]; then
    sudo cp "$BOOT_CONFIG" "${BOOT_CONFIG}.backup.$(date +%Y%m%d)"

    # Update or add video mode
    if grep -q "extraargs=" "$BOOT_CONFIG"; then
        # Remove old video= if exists
        sudo sed -i 's/video=[^ ]* //g' "$BOOT_CONFIG"
        # Add correct video mode
        sudo sed -i 's/extraargs=/extraargs=video=HDMI-A-1:1920x1080@50 /' "$BOOT_CONFIG"
    else
        echo "extraargs=video=HDMI-A-1:1920x1080@50" | sudo tee -a "$BOOT_CONFIG"
    fi

    echo "✓ Boot parameters configured"
    NEED_REBOOT=1
else
    echo "⚠️  WARNING: /boot/armbianEnv.txt not found"
fi

# Step 4: Install prerequisites
echo ""
echo "[4/9] Installing prerequisites..."
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

echo "✓ Prerequisites installed"

# Step 5: Install Rockchip MPP
echo ""
echo "[5/9] Installing Rockchip MPP..."
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

if ! ldconfig -p | grep -q rockchip_mpp; then
    echo "❌ ERROR: Rockchip MPP installation failed"
    exit 1
fi
echo "✓ Rockchip MPP installed"

# Step 6: Install gstreamer-rockchip
echo ""
echo "[6/9] Installing gstreamer-rockchip..."
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

if ! gst-inspect-1.0 mppvideodec > /dev/null 2>&1; then
    echo "❌ ERROR: mppvideodec plugin not found"
    exit 1
fi
echo "✓ gstreamer-rockchip installed"

# Step 7: Install libuvch264src (BELABOX fork)
echo ""
echo "[7/9] Installing libuvch264src (BELABOX fork)..."
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

if ! gst-inspect-1.0 libuvch264src > /dev/null 2>&1; then
    echo "❌ ERROR: libuvch264src plugin not found"
    exit 1
fi
echo "✓ libuvch264src installed"

# Step 8: Install udev rules and scripts
echo ""
echo "[8/9] Installing udev rules and streaming scripts..."
sudo cp "$SCRIPT_DIR/99-dma-heap.rules" /etc/udev/rules.d/
sudo cp "$SCRIPT_DIR/99-dji-camera.rules" /etc/udev/rules.d/
sudo cp "$SCRIPT_DIR/dji-stream.sh" /usr/local/bin/
sudo chmod +x /usr/local/bin/dji-stream.sh
sudo udevadm control --reload-rules
sudo udevadm trigger

# Set DMA heap permissions (temporary until reboot)
sudo chmod 666 /dev/dma_heap/* 2>/dev/null || true
sudo chmod 666 /dev/mpp_service 2>/dev/null || true

echo "✓ Udev rules and scripts installed"

# Step 9: Install systemd service
echo ""
echo "[9/9] Installing systemd service..."
sudo cp "$SCRIPT_DIR/dji-h264-stream.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dji-h264-stream.service
echo "✓ Systemd service installed and enabled"

# Final summary
echo ""
echo "=========================================="
echo "✅ Installation completed successfully!"
echo "=========================================="
echo ""

if [ "$NEED_REBOOT" == "1" ]; then
    echo "⚠️  REBOOT REQUIRED"
    echo ""
    echo "A reboot is required to load kernel 6.1.84 and apply boot parameters."
    echo ""
    echo "After reboot:"
    echo "  1. Connect your DJI Osmo Pocket 3 camera"
    echo "  2. Check service status:"
    echo "     sudo systemctl status dji-h264-stream.service"
    echo ""
    read -p "Reboot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    else
        echo "Please reboot manually when ready: sudo reboot"
    fi
else
    echo "Configuration complete!"
    echo ""
    echo "Connect your DJI Osmo Pocket 3 and check:"
    echo "  sudo systemctl status dji-h264-stream.service"
fi

echo ""
echo "=========================================="
echo "WORKING CONFIGURATION DETAILS:"
echo "=========================================="
echo "Kernel: 6.1.84-vendor-rk35xx (HELD - won't upgrade)"
echo "HDMI: 1080p50 (video=HDMI-A-1:1920x1080@50)"
echo "Video: 4K 50fps → Hardware decode (Rockchip MPP)"
echo "DRM: plane-id=72, connector-id=215"
echo "Audio: hw:4,0 (DJI) → hw:1,0 (HDMI)"
echo ""
echo "For troubleshooting, see WORKING_CONFIG.md"
echo "=========================================="
