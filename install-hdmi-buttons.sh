#!/bin/bash
set -e

echo "=========================================="
echo "HDMI Mode Selection - Dual Button Setup"
echo "=========================================="
echo ""
echo "This will install:"
echo "  - Dual button daemon for HDMI mode selection"
echo "  - Button 1 (Pin 7):  1080i50 (interlaced)"
echo "  - Button 2 (Pin 11): 1080p50 (progressive)"
echo "  - Systemd service for auto-start"
echo ""
echo "Hardware connection:"
echo "  Pin 7 (GPIO 100) ──── Button 1 ──┐"
echo "                                    ├─── GND (Pin 9 or 14)"
echo "  Pin 11 (GPIO 101) ─── Button 2 ──┘"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install dual button daemon
echo ""
echo "[1/3] Installing dual button daemon..."
sudo cp "$SCRIPT_DIR/hdmi-mode-buttons-daemon.py" /usr/local/bin/
sudo chmod +x /usr/local/bin/hdmi-mode-buttons-daemon.py

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Installing Python 3..."
    sudo apt-get update
    sudo apt-get install -y python3
fi

echo "✅ Dual button daemon installed"

# Install systemd service
echo ""
echo "[2/3] Installing systemd service..."
sudo cp "$SCRIPT_DIR/hdmi-buttons.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable hdmi-buttons.service
echo "✅ Systemd service installed and enabled"

# Start service
echo ""
echo "[3/3] Starting button daemon..."
sudo systemctl start hdmi-buttons.service
sleep 1

# Check status
if systemctl is-active --quiet hdmi-buttons.service; then
    echo "✅ Button daemon is running"
else
    echo "⚠️  Warning: Button daemon failed to start"
    echo "Check status with: sudo systemctl status hdmi-buttons.service"
fi

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Hardware Connection:"
echo "  Pin 7 (GPIO 100) ──── Button 1 ──┐"
echo "                                    ├─── GND (Pin 9 or 14)"
echo "  Pin 11 (GPIO 101) ─── Button 2 ──┘"
echo ""
echo "Button Functions:"
echo "  🔵 Button 1 (Pin 7):  1080i50 (interlaced) + reboot"
echo "  🟢 Button 2 (Pin 11): 1080p50 (progressive) + reboot"
echo ""
echo "Current mode:"
if grep -q "1920x1080M@50" /boot/armbianEnv.txt; then
    echo "  🔵 1080i50 (interlaced)"
else
    echo "  🟢 1080p50 (progressive)"
fi
echo ""
echo "Check daemon status:"
echo "  sudo systemctl status hdmi-buttons.service"
echo ""
echo "View logs:"
echo "  sudo journalctl -u hdmi-buttons.service -f"
echo ""
echo "Test manually (stop service first):"
echo "  sudo systemctl stop hdmi-buttons.service"
echo "  sudo python3 /usr/local/bin/hdmi-mode-buttons-daemon.py"
echo "=========================================="
