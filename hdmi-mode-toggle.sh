#!/bin/bash
# Toggle HDMI mode between 1080i50 and 1080p50

BOOT_CONFIG="/boot/armbianEnv.txt"
MODE_FILE="/tmp/hdmi_current_mode"

# Read current mode
if [ -f "$MODE_FILE" ]; then
    CURRENT_MODE=$(cat "$MODE_FILE")
else
    # Detect from boot config
    if grep -q "1920x1080M@50" "$BOOT_CONFIG"; then
        CURRENT_MODE="interlaced"
    else
        CURRENT_MODE="progressive"
    fi
fi

echo "Current HDMI mode: $CURRENT_MODE"

# Toggle mode
if [ "$CURRENT_MODE" == "progressive" ]; then
    NEW_MODE="interlaced"
    NEW_PARAM="video=HDMI-A-1:1920x1080M@50eD"
    echo "Switching to 1080i50 (interlaced)..."
else
    NEW_MODE="progressive"
    NEW_PARAM="video=HDMI-A-1:1920x1080@50"
    echo "Switching to 1080p50 (progressive)..."
fi

# Update boot config
sudo cp "$BOOT_CONFIG" "${BOOT_CONFIG}.backup"
sudo sed -i "s|video=HDMI-A-1:[^ ]*|$NEW_PARAM|" "$BOOT_CONFIG"

# Save new mode
echo "$NEW_MODE" > "$MODE_FILE"

echo ""
echo "✅ Boot config updated!"
echo "New mode will be: $([ "$NEW_MODE" == "progressive" ] && echo "1080p50" || echo "1080i50")"
echo ""
echo "⚠️  Reboot required to apply changes."
echo "Run: sudo reboot"
