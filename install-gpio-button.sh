#!/bin/bash
set -e

echo "=========================================="
echo "HDMI Mode Toggle - GPIO Button Installer"
echo "=========================================="
echo ""
echo "This will install:"
echo "  - GPIO button daemon for HDMI mode toggle"
echo "  - Toggle script (1080i50 ↔ 1080p50)"
echo "  - Systemd service for auto-start"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install toggle script
echo ""
echo "[1/4] Installing HDMI mode toggle script..."
sudo cp "$SCRIPT_DIR/hdmi-mode-toggle.sh" /usr/local/bin/
sudo chmod +x /usr/local/bin/hdmi-mode-toggle.sh
echo "✅ Toggle script installed"

# Install GPIO daemon
echo ""
echo "[2/4] Installing GPIO button daemon..."
sudo cp "$SCRIPT_DIR/gpio-button-daemon.py" /usr/local/bin/
sudo chmod +x /usr/local/bin/gpio-button-daemon.py

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Installing Python 3..."
    sudo apt-get update
    sudo apt-get install -y python3
fi

echo "✅ GPIO daemon installed"

# Install systemd service
echo ""
echo "[3/4] Installing systemd service..."
sudo cp "$SCRIPT_DIR/hdmi-button.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable hdmi-button.service
echo "✅ Systemd service installed and enabled"

# Start service
echo ""
echo "[4/4] Starting button daemon..."
sudo systemctl start hdmi-button.service
sleep 1

# Check status
if systemctl is-active --quiet hdmi-button.service; then
    echo "✅ Button daemon is running"
else
    echo "⚠️  Warning: Button daemon failed to start"
    echo "Check status with: sudo systemctl status hdmi-button.service"
fi

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Hardware Connection:"
echo "  Pin 7 (GPIO3_A4) ──── Button ──── GND (Pin 9)"
echo ""
echo "Usage:"
echo "  - Press the button to toggle HDMI mode"
echo "  - System will auto-reboot after 3 seconds"
echo "  - After reboot, new mode is active"
echo ""
echo "Current mode:"
if grep -q "1920x1080M@50" /boot/armbianEnv.txt; then
    echo "  🔵 1080i50 (interlaced)"
else
    echo "  🟢 1080p50 (progressive)"
fi
echo ""
echo "Manual toggle (without button):"
echo "  sudo /usr/local/bin/hdmi-mode-toggle.sh"
echo ""
echo "Check daemon status:"
echo "  sudo systemctl status hdmi-button.service"
echo ""
echo "View logs:"
echo "  sudo journalctl -u hdmi-button.service -f"
echo ""
echo "Full documentation: GPIO_BUTTON_GUIDE.md"
echo "=========================================="
