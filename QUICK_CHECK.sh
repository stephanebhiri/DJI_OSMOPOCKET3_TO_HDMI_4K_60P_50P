#!/bin/bash
# Quick check script pour vérifier que la configuration DJI est OK

echo "=========================================="
echo "DJI Osmo Pocket 3 → HDMI - Quick Check"
echo "=========================================="
echo ""

echo "1. Kernel Version (doit être 6.1.84):"
ssh orangepiosmo "uname -r"
echo ""

echo "2. Kernel figé (doit afficher linux-image-vendor-rk35xx):"
ssh orangepiosmo "apt-mark showhold"
echo ""

echo "3. Service actif (doit afficher 'active'):"
ssh orangepiosmo "sudo systemctl is-active dji-h264-stream.service"
echo ""

echo "4. Caméra DJI connectée (doit afficher 2ca3:0023):"
ssh orangepiosmo "lsusb | grep 2ca3"
echo ""

echo "5. CPU usage (doit être ~25-30%):"
ssh orangepiosmo "ps aux | grep '[g]st-launch' | awk '{print \$3}'"
echo ""

echo "6. Uptime et load:"
ssh orangepiosmo "uptime"
echo ""

echo "7. Boot config HDMI (doit contenir 1920x1080@50):"
ssh orangepiosmo "cat /boot/armbianEnv.txt | grep extraargs"
echo ""

echo "8. DRM plane-id et connector-id (doit afficher 72 et 215):"
ssh orangepiosmo "cat /usr/local/bin/dji-stream.sh | grep 'plane-id'"
echo ""

echo "=========================================="
echo "Statut général du service:"
echo "=========================================="
ssh orangepiosmo "sudo systemctl status dji-h264-stream.service | head -15"
echo ""

echo "✅ Si tout est OK ci-dessus, la config est PARFAITE!"
echo "⚠️  En cas de problème, consulter WORKING_CONFIG.md"
