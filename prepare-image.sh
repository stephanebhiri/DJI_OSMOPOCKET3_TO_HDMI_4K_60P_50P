#!/bin/bash
# Script to prepare DJI Noble system for image distribution
# Removes all sensitive data, logs, and machine-specific config

set -e

echo "=========================================="
echo "Preparing system for image distribution"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will remove SSH keys, logs, and machine-specific data!"
echo "   Only run this on a system you're about to image for distribution."
echo ""
read -p "Continue? (yes/no) " -r
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "[1/10] Cleaning bash history..."
rm -f /root/.bash_history
rm -f /home/*/bash_history
history -c

echo "[2/10] Cleaning SSH keys and known_hosts..."
rm -rf /root/.ssh/authorized_keys
rm -rf /root/.ssh/known_hosts
rm -rf /root/.ssh/known_hosts.old
rm -rf /home/*/.ssh/authorized_keys
rm -rf /home/*/.ssh/known_hosts
rm -rf /home/*/.ssh/known_hosts.old
# Keep SSH host keys (not sensitive, needed for SSH server)

echo "[3/10] Cleaning system logs..."
journalctl --vacuum-time=1s
rm -rf /var/log/*.log
rm -rf /var/log/*.log.*
rm -rf /var/log/journal/*
rm -rf /var/log/apt/*

echo "[4/10] Cleaning machine-id (will regenerate on first boot)..."
# Truncate but don't delete (systemd will regenerate)
truncate -s 0 /etc/machine-id
if [ -f /var/lib/dbus/machine-id ]; then
    rm /var/lib/dbus/machine-id
    ln -s /etc/machine-id /var/lib/dbus/machine-id
fi

echo "[5/10] Cleaning network configuration..."
# Remove persistent network rules
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /etc/systemd/network/99-default.link
# Don't touch netplan configs (might be needed)

echo "[6/10] Cleaning temporary files..."
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /root/.cache/*
rm -rf /home/*/.cache/*

echo "[7/10] Cleaning APT cache..."
apt-get clean
rm -rf /var/cache/apt/*

echo "[8/10] Cleaning user-specific data..."
rm -rf /root/.local/share/*
rm -rf /home/*/.local/share/*
rm -rf /root/.config/*
rm -rf /home/*/.config/*
# Restore DJI config directory if it was removed
mkdir -p /home/orangepi/.spspps || true

echo "[9/10] Cleaning command history from logs..."
# Remove sensitive command history from systemd journal
systemctl stop systemd-journald
rm -rf /var/log/journal/*/*
systemctl start systemd-journald

echo "[10/10] Cleaning cloud-init data (if present)..."
if [ -d /var/lib/cloud ]; then
    cloud-init clean --logs --seed || true
fi

# Sync to ensure all writes are flushed
sync

echo ""
echo "=========================================="
echo "✅ System cleaned and ready for imaging!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Shutdown the system:"
echo "   sudo shutdown -h now"
echo ""
echo "2. Remove SD card and create image:"
echo "   sudo dd if=/dev/sdX of=dji-noble-ready.img bs=4M status=progress"
echo ""
echo "3. Shrink image (optional, recommended):"
echo "   wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh"
echo "   chmod +x pishrink.sh"
echo "   sudo ./pishrink.sh dji-noble-ready.img"
echo ""
echo "4. Compress image:"
echo "   xz -9 -T0 dji-noble-ready.img"
echo ""
echo "⚠️  When users flash this image, their Pi will:"
echo "   - Generate a NEW unique machine-id on first boot"
echo "   - Need to configure SSH keys (no keys in image)"
echo "   - Have clean logs (no history)"
echo ""
