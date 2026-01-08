# DJI Osmo Pocket 3 → HDMI Ready Image

## 📦 Image Info

- **Filename**: `dji-noble-v1.0-20260108.img.gz`
- **Size**: 893 MB (compressed)
- **Date**: January 8, 2026
- **OS**: Ubuntu Noble 24.04 (Armbian)
- **Kernel**: 6.1.115-vendor-rk35xx
- **GStreamer**: 1.24.2

## ✅ What's Included

- **DJI Streaming Service** (auto-start)
- **GStreamer plugins**: MPP hardware decoder, libuvch264src (BELABOX fork)
- **Boot config**: USB quirk, HDMI 1080i@50
- **Udev rules**: USB permissions for DJI camera
- **Ready to use**: Plug DJI → Video works!

## ⚠️ What's NOT Included (Security)

- ❌ No SSH keys (add your own)
- ❌ No WiFi passwords
- ❌ No personal data
- ✅ Clean machine-id (regenerates on first boot)

## 📋 Requirements

- **Hardware**: Orange Pi 5 Plus (RK3588)
- **SD Card**: ≥4 GB (auto-expands to full card size)
- **HDMI Display**: Any display supporting 1080i@50
- **DJI Camera**: Osmo Pocket 3

## 🚀 Quick Start

### 1. Download & Verify

```bash
# Download
# dji-noble-v1.0-20260108.img.gz (893 MB)

# Verify checksum
shasum -a 256 -c dji-noble-v1.0-20260108.img.gz.sha256
# Should output: OK
```

**SHA256**: `814f6adc6e1af8345fb173d80c991e16a1aa19775db5d09f19668000e2eb2951`

### 2. Flash to SD Card

**Using Etcher (recommended):**
1. Download [Etcher](https://etcher.balena.io/)
2. Select `dji-noble-v1.0-20260108.img.gz`
3. Select SD card (≥4 GB)
4. Flash!

**Using dd (advanced):**
```bash
# Decompress
gunzip dji-noble-v1.0-20260108.img.gz

# Find SD card
diskutil list  # macOS
lsblk          # Linux

# Flash (replace diskX with your SD card)
sudo dd if=dji-noble-v1.0-20260108.img of=/dev/rdiskX bs=4m status=progress
```

### 3. First Boot

1. Insert SD card in Orange Pi
2. Connect HDMI display
3. Power on
4. Wait 60 seconds (auto-expand + first boot setup)
5. Login: `orangepi` / `orangepi`

### 4. Setup SSH (Optional)

```bash
# From your computer
ssh-copy-id orangepi@<IP>
ssh orangepi@<IP>
```

### 5. Use!

1. Plug DJI Osmo Pocket 3 via USB-C
2. Video appears automatically on HDMI! 🎉

## 🔧 Default Configuration

- **Video**: 4K 50fps (3840x2160@50)
- **HDMI Output**: 1080i@50 (downscaled)
- **Service**: `dji-h264-stream.service` (auto-start)
- **Decoder**: Rockchip MPP (hardware)

## 📊 Compatibility

| SD Card Size | Status | Result |
|--------------|--------|--------|
| 4 GB | ✅ | Auto-expands to 4 GB |
| 8 GB | ✅ | Auto-expands to 8 GB |
| 16 GB | ✅ | Auto-expands to 16 GB |
| 32 GB | ✅ | Auto-expands to 32 GB |
| 64 GB | ✅ | Auto-expands to 64 GB |

## 🛠️ Troubleshooting

### No video on HDMI

```bash
# Check service status
sudo systemctl status dji-h264-stream.service

# Check DJI connected
lsusb | grep -i dji

# Restart service
sudo systemctl restart dji-h264-stream.service
```

### SSH doesn't work

**Normal!** Image has no SSH keys for security.

```bash
# Add your SSH key
ssh-copy-id orangepi@<IP>
```

Or set password:
```bash
# Login via keyboard/HDMI
passwd
```

### Service keeps restarting

Check logs:
```bash
sudo journalctl -u dji-h264-stream.service -f
```

Common issues:
- DJI not plugged in (service waits)
- Wrong video mode on DJI (should be 4K 50fps or 1080p 30fps)
- USB cable issue

## 📝 Changing Configuration

### Change video resolution

Edit `/usr/local/bin/dji-stream.sh`:

```bash
# For 1080p 30fps (less CPU)
width=1920,height=1080,framerate=30/1

# For 4K 50fps (default)
width=3840,height=2160,framerate=50/1
```

Then restart:
```bash
sudo systemctl restart dji-h264-stream.service
```

### Disable auto-start

```bash
sudo systemctl disable dji-h264-stream.service
```

### Manual start

```bash
sudo systemctl start dji-h264-stream.service
```

## 🔐 Security Notes

This image is **safe to distribute** because:
- ✅ No SSH private keys
- ✅ No WiFi passwords
- ✅ No personal data
- ✅ Clean logs
- ✅ Unique machine-id per Pi

**First boot actions:**
1. Set your own password: `passwd`
2. Add your SSH key: `ssh-copy-id`
3. Update system: `sudo apt update && sudo apt upgrade`

## 📚 Documentation

Full documentation available at:
https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P

- **WORKING_CONFIG_NOBLE.md**: Complete validated config
- **install-noble.sh**: Automated install from scratch
- **CREATE_IMAGE.md**: How this image was created

## 🐛 Issues

Report issues at:
https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P/issues

## 📄 License

- **This configuration**: MIT License
- **Linux kernel**: GPL
- **Armbian**: GPL
- **GStreamer**: LGPL
- **Rockchip MPP**: Apache 2.0

## 🙏 Credits

- **Armbian Team**: Base OS
- **BELABOX**: libuvch264src fork
- **Rockchip**: MPP hardware decoder
- **DrewPiShrink**: Image shrinking tool

---

**Image created**: 2026-01-08
**Tested on**: Orange Pi 5 Plus, DJI Osmo Pocket 3
**Status**: ✅ Production ready
