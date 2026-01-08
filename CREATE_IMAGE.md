# Creating a Distribution Image

This guide explains how to create a clean, distributable SD card image from a working DJI Noble system.

## ⚠️ Important

Before creating an image, you MUST clean all sensitive data (SSH keys, logs, machine-ID) using the provided script.

## Prerequisites

- Working DJI Noble system (tested and validated)
- SD card reader on Linux/macOS
- ~16 GB free disk space
- `pishrink.sh` (optional, for smaller images)

## Step 1: Prepare the System

Run the cleanup script **on the Orange Pi**:

```bash
cd ~/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
sudo ./prepare-image.sh
```

This will:
- ✅ Remove SSH keys (yours won't be distributed!)
- ✅ Clean all logs and history
- ✅ Clear machine-id (each Pi will get unique ID)
- ✅ Remove temporary files and caches

**Type `yes` to confirm.**

## Step 2: Shutdown

After the script completes:

```bash
sudo shutdown -h now
```

Wait for the Pi to fully power off (LED off).

## Step 3: Create the Image

Remove the SD card and insert it into your computer.

### On Linux:

```bash
# Find SD card device
lsblk

# Create image (replace /dev/sdX with your SD card)
sudo dd if=/dev/sdX of=dji-noble-v1.0.img bs=4M status=progress conv=fsync

# This takes ~5-10 minutes for 16GB card
```

### On macOS:

```bash
# Find SD card device
diskutil list

# Unmount (but don't eject)
diskutil unmountDisk /dev/diskX

# Create image
sudo dd if=/dev/rdiskX of=dji-noble-v1.0.img bs=4m

# Use rdiskX (raw disk) for faster speed
```

## Step 4: Shrink Image (Recommended)

Raw images are the full SD card size (16 GB), even if only 4 GB is used.

Download and use PiShrink:

```bash
# Download PiShrink
wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh
chmod +x pishrink.sh

# Shrink image (removes unused space)
sudo ./pishrink.sh dji-noble-v1.0.img

# Before: 16 GB
# After:  ~2-4 GB (depends on actual usage)
```

PiShrink also makes the image auto-expand on first boot!

## Step 5: Compress

Compress for distribution:

```bash
# Using xz (best compression, slower)
xz -9 -T0 dji-noble-v1.0.img
# Result: dji-noble-v1.0.img.xz (~1-2 GB)

# OR using gzip (faster, larger)
gzip -9 dji-noble-v1.0.img
# Result: dji-noble-v1.0.img.gz (~2-3 GB)
```

## Step 6: Verify Image

Test the image before distribution:

```bash
# Flash to another SD card
sudo dd if=dji-noble-v1.0.img.xz bs=4M status=progress | xz -d | sudo dd of=/dev/sdX bs=4M status=progress

# Boot and verify:
# - New machine-id generated
# - SSH works (with YOUR keys, not mine)
# - DJI service starts automatically
```

## Step 7: Distribution Options

### Option A: GitHub Releases (Free, max 2 GB)

```bash
# 1. Create release on GitHub
# 2. Upload compressed image as asset
# 3. Add SHA256 checksum:
sha256sum dji-noble-v1.0.img.xz > dji-noble-v1.0.img.xz.sha256
```

### Option B: Google Drive (Easy)

```bash
# 1. Upload to Google Drive
# 2. Get shareable link
# 3. Add link to README
```

### Option C: Torrent (Best for large files)

```bash
# 1. Create torrent
# 2. Seed from your machine
# 3. Share magnet link
```

## Image Naming Convention

Use semantic versioning:

```
dji-noble-v1.0-20260108.img.xz
         │ │    └─ Date (YYYYMMDD)
         │ └─ Version
         └─ OS (noble)
```

## What's Included in Clean Image

✅ **Included:**
- DJI streaming service (configured)
- All GStreamer plugins (MPP, rockchip, libuvch264src)
- Boot config (USB quirk, HDMI 1080i@50)
- udev rules (USB permissions)
- System packages

❌ **NOT Included (by design):**
- SSH keys (user must add their own)
- Logs (clean start)
- Machine-ID (generated on first boot)
- Personal data

## User Instructions (in README)

When distributing, tell users:

```markdown
# Using Pre-built Image

1. Download: dji-noble-v1.0.img.xz
2. Flash with [Etcher](https://etcher.balena.io/)
3. First boot: Create root password
4. Add your SSH key:
   ```bash
   ssh-copy-id orangepi@<IP>
   ```
5. Plug DJI → Video works!
```

## Troubleshooting

### Image too large for GitHub

- Use PiShrink (reduces to ~2 GB)
- Use stronger compression: `xz -9e`
- Use Google Drive instead

### Image won't boot

- Verify checksum: `sha256sum -c *.sha256`
- Try different SD card
- Re-flash with Etcher

### SSH doesn't work

Normal! Image has no SSH keys for security.
Users must add their own: `ssh-copy-id orangepi@<IP>`

## Security Notes

⚠️ **Never distribute images with:**
- Your SSH private keys
- WiFi passwords
- API tokens
- Personal data

✅ **Always run `prepare-image.sh` first!**

## Size Expectations

- Raw image: 16 GB
- After PiShrink: ~2-4 GB
- After xz compression: ~1-2 GB
- Download time (100 Mbps): ~2-3 minutes

## Legal

Include license in image:
- GPL for Linux kernel
- MIT/Apache for your scripts
- Credit to Armbian, BELABOX, etc.
