#!/usr/bin/env python3
"""
HDMI Mode Buttons Daemon - Dual Button Mode Selection
Two physical buttons to select HDMI output mode directly

Button 1 (GPIO 100, Pin 7):  Force 1080i50 (interlaced) + reboot
Button 2 (GPIO 101, Pin 11): Force 1080p50 (progressive) + reboot

Hardware connection:
  Pin 7 (GPIO 100) ──── Button 1 ──┐
                                    ├─── GND (Pin 9 or 14)
  Pin 11 (GPIO 101) ─── Button 2 ──┘

Usage:
  sudo python3 hdmi-mode-buttons-daemon.py
"""

import time
import os
import subprocess
import sys

# GPIO pins configuration
GPIO_INTERLACED = 100   # Pin 7 - Button for 1080i50
GPIO_PROGRESSIVE = 101  # Pin 11 - Button for 1080p50

BOOT_CONFIG = "/boot/armbianEnv.txt"
DEBOUNCE_TIME = 1.0  # seconds

class GPIOButton:
    def __init__(self, pin, name):
        self.pin = pin
        self.name = name
        self.gpio_path = f"/sys/class/gpio/gpio{pin}"

    def setup(self):
        """Export and configure GPIO pin as input with pull-up"""
        if not os.path.exists(self.gpio_path):
            try:
                with open("/sys/class/gpio/export", "w") as f:
                    f.write(str(self.pin))
                time.sleep(0.2)
            except IOError as e:
                print(f"❌ Error exporting GPIO {self.pin}: {e}")
                return False

        try:
            with open(f"{self.gpio_path}/direction", "w") as f:
                f.write("in")
        except IOError as e:
            print(f"❌ Error setting GPIO direction: {e}")
            return False

        try:
            with open(f"{self.gpio_path}/edge", "w") as f:
                f.write("falling")
        except IOError:
            pass

        print(f"✅ GPIO {self.pin} ({self.name}) configured")
        return True

    def cleanup(self):
        """Unexport GPIO"""
        if os.path.exists(self.gpio_path):
            try:
                with open("/sys/class/gpio/unexport", "w") as f:
                    f.write(str(self.pin))
            except IOError:
                pass

    def read(self):
        """Read GPIO value (0 = pressed, 1 = released)"""
        try:
            with open(f"{self.gpio_path}/value", "r") as f:
                return int(f.read().strip())
        except IOError:
            return 1

def set_hdmi_mode(mode):
    """Set HDMI mode in boot config and reboot"""
    if mode == "interlaced":
        param = "video=HDMI-A-1:1920x1080M@50eD"
        mode_name = "1080i50 (interlaced)"
    else:
        param = "video=HDMI-A-1:1920x1080@50"
        mode_name = "1080p50 (progressive)"

    print("\n" + "="*60)
    print(f"🎬 Setting HDMI mode: {mode_name}")
    print("="*60)

    # Backup boot config
    try:
        subprocess.run(["cp", BOOT_CONFIG, f"{BOOT_CONFIG}.backup"], check=True)
    except subprocess.CalledProcessError:
        print("⚠️  Warning: Could not create backup")

    # Update boot config
    try:
        with open(BOOT_CONFIG, 'r') as f:
            content = f.read()

        # Replace video mode parameter
        import re
        new_content = re.sub(
            r'video=HDMI-A-1:[^ ]*',
            param,
            content
        )

        with open(BOOT_CONFIG, 'w') as f:
            f.write(new_content)

        print(f"✅ Boot config updated to: {mode_name}")

    except Exception as e:
        print(f"❌ Error updating boot config: {e}")
        return False

    # Reboot
    print("\n⏳ Rebooting in 3 seconds...")
    for i in range(3, 0, -1):
        print(f"   {i}...")
        time.sleep(1)

    subprocess.run(["reboot"])
    return True

def main():
    print("="*60)
    print("  HDMI Mode Selection - Dual Button Daemon")
    print("="*60)
    print(f"Button 1 (GPIO {GPIO_INTERLACED}, Pin 7):  1080i50 (interlaced)")
    print(f"Button 2 (GPIO {GPIO_PROGRESSIVE}, Pin 11): 1080p50 (progressive)")
    print("="*60)
    print()

    # Setup buttons
    btn_interlaced = GPIOButton(GPIO_INTERLACED, "1080i50")
    btn_progressive = GPIOButton(GPIO_PROGRESSIVE, "1080p50")

    if not btn_interlaced.setup() or not btn_progressive.setup():
        print("❌ Failed to setup GPIOs. Are you running as root?")
        sys.exit(1)

    print("✅ Ready! Press a button to select HDMI mode:")
    print("   • Pin 7  → 1080i50 (interlaced)")
    print("   • Pin 11 → 1080p50 (progressive)")
    print("   (Press Ctrl+C to exit)\n")

    try:
        last_press_time = {
            GPIO_INTERLACED: 0,
            GPIO_PROGRESSIVE: 0
        }
        last_values = {
            GPIO_INTERLACED: 1,
            GPIO_PROGRESSIVE: 1
        }

        while True:
            # Check button 1 (interlaced)
            value_i = btn_interlaced.read()
            if value_i == 0 and last_values[GPIO_INTERLACED] == 1:
                current_time = time.time()
                if current_time - last_press_time[GPIO_INTERLACED] > DEBOUNCE_TIME:
                    print("\n🔵 Button 1 pressed: Setting 1080i50 (interlaced)")
                    set_hdmi_mode("interlaced")
                    last_press_time[GPIO_INTERLACED] = current_time
            last_values[GPIO_INTERLACED] = value_i

            # Check button 2 (progressive)
            value_p = btn_progressive.read()
            if value_p == 0 and last_values[GPIO_PROGRESSIVE] == 1:
                current_time = time.time()
                if current_time - last_press_time[GPIO_PROGRESSIVE] > DEBOUNCE_TIME:
                    print("\n🟢 Button 2 pressed: Setting 1080p50 (progressive)")
                    set_hdmi_mode("progressive")
                    last_press_time[GPIO_PROGRESSIVE] = current_time
            last_values[GPIO_PROGRESSIVE] = value_p

            time.sleep(0.05)  # Check every 50ms

    except KeyboardInterrupt:
        print("\n\n👋 Shutting down gracefully...")
    except Exception as e:
        print(f"\n❌ Error: {e}")
    finally:
        btn_interlaced.cleanup()
        btn_progressive.cleanup()
        print("✅ Cleanup complete")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("❌ This script must be run as root (use sudo)")
        sys.exit(1)

    main()
