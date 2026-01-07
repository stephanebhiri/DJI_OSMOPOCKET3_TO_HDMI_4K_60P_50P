#!/usr/bin/env python3
"""
GPIO Button Daemon for HDMI Mode Toggle
Listens for button press on GPIO pin and toggles HDMI mode (1080i50 <-> 1080p50)

Usage:
  sudo python3 gpio-button-daemon.py [GPIO_PIN]

Example:
  sudo python3 gpio-button-daemon.py 100  # Use GPIO 100 (GPIO3_A4, physical pin 7)

Hardware connection:
  - Connect button between GPIO pin and GND
  - Internal pull-up resistor is enabled
  - Button press = LOW signal
"""

import time
import os
import subprocess
import sys

# Default GPIO pin (can be overridden via command line)
DEFAULT_GPIO_PIN = 100  # GPIO3_A4 on Orange Pi 5 Plus (physical pin 7)

TOGGLE_SCRIPT = "/usr/local/bin/hdmi-mode-toggle.sh"
DEBOUNCE_TIME = 1.0  # seconds (prevent multiple triggers)

class GPIOButton:
    def __init__(self, pin):
        self.pin = pin
        self.gpio_path = f"/sys/class/gpio/gpio{pin}"

    def setup(self):
        """Export and configure GPIO pin as input with pull-up"""
        # Export GPIO if not already exported
        if not os.path.exists(self.gpio_path):
            try:
                with open("/sys/class/gpio/export", "w") as f:
                    f.write(str(self.pin))
                time.sleep(0.2)  # Wait for sysfs to create files
            except IOError as e:
                print(f"Error exporting GPIO {self.pin}: {e}")
                return False

        # Set as input
        try:
            with open(f"{self.gpio_path}/direction", "w") as f:
                f.write("in")
        except IOError as e:
            print(f"Error setting GPIO direction: {e}")
            return False

        # Configure edge detection (falling edge = button press)
        try:
            with open(f"{self.gpio_path}/edge", "w") as f:
                f.write("falling")
        except IOError as e:
            print(f"Warning: Could not set edge detection: {e}")

        print(f"✅ GPIO {self.pin} configured successfully")
        return True

    def cleanup(self):
        """Unexport GPIO"""
        if os.path.exists(self.gpio_path):
            try:
                with open("/sys/class/gpio/unexport", "w") as f:
                    f.write(str(self.pin))
                print(f"GPIO {self.pin} unexported")
            except IOError:
                pass

    def read(self):
        """Read GPIO value (0 = pressed, 1 = released with pull-up)"""
        try:
            with open(f"{self.gpio_path}/value", "r") as f:
                return int(f.read().strip())
        except IOError:
            return 1  # Default to not pressed

def toggle_hdmi_mode():
    """Execute HDMI mode toggle script and auto-reboot"""
    print("\n" + "="*50)
    print("🔘 Button pressed! Toggling HDMI mode...")
    print("="*50)

    try:
        result = subprocess.run([TOGGLE_SCRIPT], capture_output=True, text=True)
        print(result.stdout)

        if result.returncode == 0:
            print("\n⏳ Auto-rebooting in 3 seconds...")
            for i in range(3, 0, -1):
                print(f"   {i}...")
                time.sleep(1)
            subprocess.run(["sudo", "reboot"])
        else:
            print(f"❌ Error: {result.stderr}")
    except Exception as e:
        print(f"❌ Error toggling mode: {e}")

def main():
    # Get GPIO pin from command line or use default
    gpio_pin = DEFAULT_GPIO_PIN
    if len(sys.argv) > 1:
        try:
            gpio_pin = int(sys.argv[1])
        except ValueError:
            print(f"Invalid GPIO pin number: {sys.argv[1]}")
            print(f"Usage: {sys.argv[0]} [GPIO_PIN]")
            sys.exit(1)

    print("="*60)
    print("  HDMI Mode Toggle - GPIO Button Daemon")
    print("="*60)
    print(f"GPIO Pin: {gpio_pin}")
    print(f"Mode: 1080i50 ↔ 1080p50")
    print(f"Action: Toggle + Auto-reboot")
    print("="*60)
    print()

    # Check if toggle script exists
    if not os.path.exists(TOGGLE_SCRIPT):
        print(f"❌ Error: Toggle script not found: {TOGGLE_SCRIPT}")
        print(f"Please install hdmi-mode-toggle.sh first")
        sys.exit(1)

    # Setup GPIO
    button = GPIOButton(gpio_pin)
    if not button.setup():
        print("❌ Failed to setup GPIO. Are you running as root?")
        sys.exit(1)

    print("✅ Ready! Press the button to toggle HDMI mode")
    print("   (Press Ctrl+C to exit)\n")

    try:
        last_press_time = 0
        last_value = 1

        while True:
            value = button.read()

            # Detect button press (transition from HIGH to LOW)
            if value == 0 and last_value == 1:
                current_time = time.time()

                # Debounce check
                if current_time - last_press_time > DEBOUNCE_TIME:
                    toggle_hdmi_mode()
                    last_press_time = current_time
                else:
                    print("⚠️  Button bounce detected, ignoring...")

            last_value = value
            time.sleep(0.05)  # Check every 50ms

    except KeyboardInterrupt:
        print("\n\n👋 Shutting down gracefully...")
    except Exception as e:
        print(f"\n❌ Error: {e}")
    finally:
        button.cleanup()
        print("✅ Cleanup complete")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("❌ This script must be run as root (use sudo)")
        sys.exit(1)

    main()
