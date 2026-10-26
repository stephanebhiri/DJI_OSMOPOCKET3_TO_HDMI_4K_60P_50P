# BELABOX Orange Pi 5 Plus validation — 26 October 2026

## Why this record exists

The earlier Orange Pi installation produced Pocket 3 picture and microphone audio after a cold boot, with HDMI-A-2 in 1920×1080i50. Its complete eMMC contents were not imaged after those corrections. The October 22 downloadable images preceded the audio and dynamic HDMI mode fixes and were withdrawn. Do not treat either image as a copy of that working installation.

## Hardware and boot source

- Board: BELABOX Orange Pi 5 Plus, RK3588.
- Test system: Armbian 25.8.1 Noble, vendor kernel 6.1.115, booted from microSD. The original BELABOX eMMC is still untouched at the time of this record.
- Pocket 3: USB webcam mode `2ca3:0023`, USB descriptor version 2.01, link at 480 Mb/s. This link speed alone does not show a cable fault.
- Display: HDMI-A-2, connector 236, CRTC 130, NV12 capable plane 114. The EDID mode index was `#5` during this test; it must be discovered again at each boot.

## Reproduced faults and fixes

1. The BELABOX libuvc fork calls `UVC_GET_MAX` before selecting the requested format. After 1080p30, the Pocket 3 returned a stale payload maximum of `622080`; for 4K50 its accepted control returned `2488320`. The fork rejected the valid 4K50 format/frame/interval as `Invalid mode` because it also compared these payload sizes. `belabox-uvc-stale-payload.patch` compares format, frame and interval. A 1080p30→4K50 test then delivered 100 encoded buffers and EOS successfully.
2. The video script did not specify an NV12 capable KMS plane. Plane 114 was verified on this board. The running pipeline uses `kmssink connector-id=236 plane-id=114 sync=true restore-crtc=false`.
3. The camera udev rule restarted video for every `video4linux` add event, including repeated reprobes, and the service reached its start limit. The rule now triggers once per USB device add; the service can keep retrying while the camera is absent.

## Hardware evidence before cold boot

- 4K50 acquisition with the patched libuvc: **2225 encoded buffers in 45 seconds**, approximately 49.4 buffers/s; no new USB disconnection during that run.
- Runtime pipeline: Pocket 3 H.264 3840×2160 at 50/1 → `h264parse` → Rockchip `mppvideodec` → KMS plane 114 on HDMI-A-2. DRM state showed an active NV12 framebuffer at 3840×2160, scaled to the HDMI output.
- DRM CRTC 130 mode was `1920x1080i`, 50 Hz, pixel clock 74250 kHz. Audio service used the named Pocket 3 and HDMI ALSA cards.
- The user physically confirmed **moving live picture and microphone sound** on the display. The video, HDMI mode and audio services remained active over a further 30 second observation; the framebuffer changed and no ext4 errors were logged.

## Cold-boot result and replacement medium

- A complete power-off/power-on booted the original BELABOX eMMC instead of the microSD. An offline `e2fsck -fn` of the unmounted microSD then found a corrupted directory. The freshly installed libuvc binary's SHA-256 had also changed from its verified value. This microSD is unsuitable as an eMMC source.
- The separate 31.9 GB USB card was mounted from the original eMMC system, updated with the same source patch and runtime files, and tested by running its Noble userspace in a chroot against the connected Pocket 3. Its 1080p30→4K50 UVC test passed. After clean unmount, an offline `e2fsck -fn` reported no errors. The patched libuvc SHA-256 is `c21c116ab853fd277139f89a6272267d927637c5f98a48c401f84ca6bf66b56d`.

## Publication gate

- No corrected image should be published until the exact image file is rebuilt, checksummed, flashed, and independently cold tested.

## eMMC installation and first live test

- The corrected USB image was copied to a 6 GiB raw file on the Mac. SHA-256: `eef110804488b3168894ebf585e59a4cab982b05fd3d2fa1f2d7d8b904b4819f`. The compressed personalized image is kept locally and must not be published because it contains the user's SSH public key.
- With both removable cards removed, MaskROM reported RK3588 USB ID `2207:350b`. `rkdeveloptool cs 1` selected the 61,865,984,000-byte Samsung eMMC. Its pre-write GPT contained the BELABOX root partition extending to sector 120831966.
- The raw image was written to eMMC starting at LBA 0. All 6 GiB were read back in twelve 512 MiB blocks and compared by SHA-256 with the raw source; all matched.
- On first boot, `/` mounted from `/dev/mmcblk0p1`, kernel `6.1.115-vendor-rk35xx`. The installed libuvc SHA-256 was `c21c116ab853fd277139f89a6272267d927637c5f98a48c401f84ca6bf66b56d`.
- The initial boot selected 1080i50 and then reverted to 1080p60. The framebuffer console reclaimed the display after `modetest -d`. Detaching the framebuffer console (`/sys/class/vtconsole/vtcon1/bind=0`) before setting the mode held HDMI-A-2 at `1920x1080i50` while the GStreamer stream and audio services ran. This correction was added to `osmo-hdmi50.sh` on eMMC and in the source tree.
- The Pocket 3 was detected in webcam mode as `2ca3:0023`; the 4K50 H.264 pipeline used NV12 KMS plane 114. The user physically confirmed a moving image and microphone sound on the HDMI display.
- The 6 GiB root filesystem currently occupies only part of the 64 GB eMMC. The backup GPT header has been moved to the end of the eMMC; extending the mounted root partition was refused by `parted` and is deferred until it can be done safely.

## Cold-boot observation and remaining check

- With the Mac data cable and both removable cards removed, a full power-off/power-on booted `/dev/mmcblk0p1`. HDMI-A-2 remained at `1920x1080i50`, the Pocket 3 enumerated as `2ca3:0023`, and all three services reported active. The user confirmed moving picture and microphone sound on the display.
- During this boot, the first `gst-launch-1.0` video process logged `Caught SIGSEGV` after entering PLAYING and then spun waiting for a debugger. It misleadingly appeared active while KMS plane 114 was empty. Restarting only `dji-h264-stream.service` produced an active NV12 plane and restored the stream. The exact internal crash cause was not established.
- The source and installed `dji-stream.sh` now invoke `gst-launch-1.0 --no-fault`. This disables its debugger wait so `Restart=always` can recover from a future crash. In a controlled recovery test, sending SIGSEGV to video PID 1566 caused systemd to replace it with PID 1623; HDMI remained at 1080i50 and plane 114 again held a 3840×2160 NV12 framebuffer.

## Final cold boot with the installed fixes

- After a complete power-off and power-on with no microSD, USB card reader or Mac data cable, the board booted from `/dev/mmcblk0p1`. The new boot ID was `774a7125-ae5e-4d02-b5b6-ec53641b0ff4`.
- Pocket 3 `2ca3:0023`, all three services active, HDMI-A-2 `1920x1080i50`, and KMS plane 114 active with a 3840×2160 NV12 framebuffer. No ext4, MMC or I/O error appeared in the boot log.
- Early service attempts failed while USB audio/video was still enumerating, then the first video pipeline reached PLAYING and exited with `status=11/SEGV`. With `--no-fault`, systemd automatically started a new process (PID 1408); the live picture returned without any manual service command. The user physically confirmed **moving image and microphone sound** on HDMI after this cold boot.
- The recurring first-launch segmentation fault is **not root-cause fixed**. The installed restart behavior recovered during this test. Continue to treat a future lack of picture or unexpectedly repeated crashes as a fault and inspect `journalctl -b -u dji-h264-stream.service` and the KMS plane before claiming healthy operation.
