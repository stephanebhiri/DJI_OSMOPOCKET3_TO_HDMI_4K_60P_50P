# Validated Configuration - Ubuntu Noble 24.04

✅ **Tested and working on January 8, 2026**

## ⚠️ Important: Noble vs Trixie

**✅ USE: Ubuntu Noble 24.04 (or Armbian Bookworm)**
- GStreamer 1.24.2
- Compatible with libuvch264src (BELABOX fork)

**❌ DO NOT USE: Debian Trixie**
- GStreamer 1.26
- **INCOMPATIBLE** with libuvch264src (BELABOX fork)
- Error: "Unable to get stream control: Invalid mode"

## Validated System

- **OS**: Armbian 25.11.1 Noble (Ubuntu 24.04)
- **Kernel**: 6.1.115-vendor-rk35xx
- **GStreamer**: 1.24.2
- **Hardware**: Orange Pi 5 Plus (RK3588)

## DJI Configuration

The DJI Osmo Pocket 3 automatically adapts to the receiver's request.

**Validated configuration:**
- **Resolution**: 4K (3840x2160)
- **Framerate**: 50 fps
- **Format**: H.264

## HDMI Configuration

**Boot parameters** (`/boot/armbianEnv.txt`):
```
extraargs=usbcore.quirks=2ca3:0023:i video=HDMI-A-1:1920x1080i@50 cma=256M
```

**KMS sink parameters:**
- `plane-id=73` (supports NV12 for MPP)
- `connector-id=215` (HDMI-A-1)

⚠️ **Note**: `plane-id=72` does NOT work (error "Invalid argument")

## Validated GStreamer Pipeline

```bash
gst-launch-1.0 \
    libuvch264src index=0 ! video/x-h264,width=3840,height=2160,framerate=50/1 ! \
    h264parse ! mppvideodec ! \
    kmssink plane-id=73 connector-id=215 sync=false
```

## Performance

- **CPU**: ~43% (MPP hardware decode)
- **RAM**: ~92 MB (stable)
- **Latency**: Low (~50-100ms)

## Modified Files

### 1. `/etc/udev/rules.d/50-dji-usb.rules` (NEW)

```
SUBSYSTEM=="usb", ATTRS{idVendor}=="2ca3", ATTRS{idProduct}=="0023", MODE="0666", GROUP="video"
```

**Without this file**: "Access denied" error on startup

### 2. `dji-stream.sh`

**Critical changes:**
- `plane-id=72` → `plane-id=73` ✅
- Audio temporarily disabled (for stability)

### 3. `/boot/armbianEnv.txt`

**Added USB quirk:**
```
usbcore.quirks=2ca3:0023:i
```

## Installation on Fresh Noble

1. **Flash Ubuntu Noble 24.04 Minimal/IOT** (kernel 6.1 vendor)

2. **Configure SSH before boot** (optional):
```bash
# Mount root partition
mkdir -p /tmp/armbi_root
mount /dev/sdX1 /tmp/armbi_root

# Add SSH key
mkdir -p /tmp/armbi_root/root/.ssh
cat ~/.ssh/id_rsa.pub > /tmp/armbi_root/root/.ssh/authorized_keys
chmod 700 /tmp/armbi_root/root/.ssh
chmod 600 /tmp/armbi_root/root/.ssh/authorized_keys

# Enable SSH
touch /tmp/armbi_root/boot/ssh

# Unmount
umount /tmp/armbi_root
```

3. **Boot and connect**:
```bash
# Default login: orangepi / orangepi
ssh orangepi@<IP>
```

4. **Clone the repo**:
```bash
git clone https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P.git
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
```

5. **Install**:
```bash
sudo ./install-noble.sh
```

6. **Install USB permissions**:
```bash
sudo cp 50-dji-usb.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

7. **Configure HDMI and USB quirk**:
```bash
sudo sed -i 's|extraargs=cma=256M|extraargs=usbcore.quirks=2ca3:0023:i video=HDMI-A-1:1920x1080i@50 cma=256M|' /boot/armbianEnv.txt
```

8. **Install the corrected script**:
```bash
sudo cp dji-stream.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/dji-stream.sh
```

9. **Enable the service**:
```bash
sudo cp dji-h264-stream.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dji-h264-stream.service
```

10. **Reboot**:
```bash
sudo reboot
```

11. **Plug in the DJI and verify**:
```bash
sudo systemctl status dji-h264-stream.service
```

## Troubleshooting

### "Access denied" error
```bash
# Check USB permissions
ls -la /dev/bus/usb/001/*

# Reload udev
sudo udevadm control --reload-rules
sudo udevadm trigger

# Replug the DJI
```

### "Invalid argument" error (kmssink)
```bash
# Check plane-id in dji-stream.sh
cat /usr/local/bin/dji-stream.sh | grep plane-id

# Should be: plane-id=73 (not 72!)
```

### No video
```bash
# Check that the service is running
sudo systemctl status dji-h264-stream.service

# View logs
sudo journalctl -u dji-h264-stream.service -f

# Test manually
sudo systemctl stop dji-h264-stream.service
gst-launch-1.0 videotestsrc ! kmssink plane-id=73 connector-id=215
```

### OOM killer (memory)
If the service is killed after a few minutes, this is normal - the service automatically restarts (observed behavior but stable after restart).

## Useful Commands

```bash
# Service status
sudo systemctl status dji-h264-stream.service

# Restart
sudo systemctl restart dji-h264-stream.service

# Stop/Start
sudo systemctl stop dji-h264-stream.service
sudo systemctl start dji-h264-stream.service

# Live logs
sudo journalctl -u dji-h264-stream.service -f

# Check DJI connected
lsusb | grep -i dji

# Check decoding
dmesg | grep -i "uvc\|dji"
```

## Differences from Bookworm

This configuration is identical to Bookworm because Noble and Bookworm both share **GStreamer 1.24**.

**Why it works:**
- BELABOX fork (Jan 2025) developed for GStreamer 1.24
- Noble = GStreamer 1.24 ✅
- Trixie = GStreamer 1.26 ❌ (incompatible API changes)
