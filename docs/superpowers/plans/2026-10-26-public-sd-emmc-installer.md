# Public microSD to eMMC Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Build and validate a public Orange Pi 5 Plus microSD image that installs the complete Pocket 3 to HDMI system on eMMC, then publishes only after a real cold-boot picture-and-sound test.

**Architecture:** Start from the SHA-256-locked clean Armbian Noble image, provision pinned ARM64 sources, and turn the resulting 6 GiB image into a one-shot microSD installer. The SD service checks that it is running from SD, identifies one unmounted eMMC, freezes its source, copies and reads back the full image, checks and expands ext4 offline, switches the target to runtime services, and powers off only after success.

**Tech Stack:** Bash, systemd, Armbian Noble 25.8.1/vendor 6.1.115, GStreamer 1.24, Rockchip MPP/libuvc, parted/e2fsprogs, Linux ARM64 build host, GitHub Releases.

**Spec:** docs/superpowers/specs/2026-10-26-public-sd-emmc-installer-design.md

## Global Constraints

- Public image contains no user SSH key, fixed password, host key, machine ID, private IP or old BELABOX logs.
- SSH is off by default and runtime picture/sound starts without a setup prompt.
- Only Orange Pi 5 Plus with one unmounted eMMC >=8 GiB is an automatic target; never write NVMe or USB.
- Installation may begin only when the system actually booted from microSD; a wrong boot source must make no target writes.
- Only HDMI-A-2 with EDID 1920x1080i50 is supported for the verified output; select connector and NV12 plane dynamically.
- Source image is exactly 6 GiB; the full copied region must match readback before the target filesystem is resized.
- Preserve a verified offline backup of the working eMMC before destructive hardware testing.
- Publish no image until a new healthy microSD has installed eMMC and the user has physically confirmed image and sound after cold boot.

## Review Focus

- Source root could be eMMC despite SD inserted: preflight must reject before writing.
- Multiple or mounted eMMCs and absent 1080i50: preflight must reject before writing.
- Source remount or partial copy failure: never print completion or power off as success.
- Failed readback or ext4 resize: leave clear diagnostic state and do not enable runtime as successful.
- Public-image scan must catch private keys, active SSH, machine identity, and stale personal logs.

## Task 1 — Dynamic video hardware selection

**Files:** dji-stream.sh; image/parse-hdmi-mode.sh; new image/parse-kms-plane.sh; image/provision-rootfs.sh; image/test-hdmi-selection.sh.

- [ ] Add fixture tests for connected HDMI-A-2 at renumbered connector/EDID indices, usable NV12 plane with variable plane ID, and rejection when absent.
- [ ] Run the fixtures and confirm they fail against the old hard-coded plane.
- [ ] Implement plane discovery from modetest capabilities and remove the mismatched HDMI-A-1 boot argument.
- [ ] Run Bash syntax and fixture tests; compare selected connector/plane with the working BELABOX without changing its services.
- [ ] Commit this tested unit.

## Task 2 — Safe one-shot eMMC installer

**Files:** image/osmo-install-emmc.sh; image/osmo-install-emmc.service; new image/test-emmc-installer.sh.

- [ ] Add tests for source type, board, one target, mounted target, size, EDID, state marker, and copy/readback/resize failure paths using injected command wrappers or file-backed devices.
- [ ] Confirm the tests fail for the present unsafe or incomplete cases.
- [ ] Make the installer log source and target identity, verify the source and target before write, remount the SD root read-only, copy exactly 6 GiB, compare, repair GPT, check and expand ext4, then switch target services.
- [ ] Ensure every failure exits nonzero with a durable error record and no success poweroff; success powers off only after sync and an eMMC state marker.
- [ ] Run tests and shell syntax checks; commit this unit.

## Task 3 — Public finalization and build entrypoint

**Files:** new image/finalize-public-installer.sh; new image/build-public-installer.sh; image/source-lock.txt; new image/test-public-finalization.sh; image/README.md.

- [ ] Add tests using a temporary fake rootfs for service enablement, disabled SSH, absent personal identity, locked root account, and installed source/hash manifest.
- [ ] Confirm failing tests, then implement a public finalizer separate from the existing personal-key finalizer.
- [ ] Implement a builder that verifies the base SHA-256, exact source revisions, ARM64 Linux host, scratch-space preflight, image size, and resulting artifact hashes; reuse image/provision-rootfs.sh.
- [ ] Verify scripts with Bash syntax and local fake-rootfs tests; commit this unit.

## Task 4 — Build and inspect the candidate image

**Files:** local build artifacts outside Git; manifest and checksums.

- [ ] Prepare >=20 GiB scratch space without deleting the personal rescue image.
- [ ] Build in an ARM64 Linux environment from the verified clean Armbian base.
- [ ] Run fsck on the unmounted candidate root, inspect enabled units, compiled library hashes, boot config and absence of credentials/private data.
- [ ] Compress, compute SHA-256 and ensure the release asset is under GitHub's 2 GiB per-file limit.
- [ ] Keep this as a candidate, not a public release; record exact build inputs and output hashes.

## Task 5 — Full hardware validation

**Files:** local offline eMMC backup, candidate microSD, image/BELABOX_VALIDATION_2026-10-26.md or a new dated validation record.

- [ ] Read the first 6 GiB and trailing GPT header of the currently working eMMC through MaskROM while powered off; hash and retain them with restoration instructions.
- [ ] Identify the new healthy microSD on the Mac, explicitly verify its device and size, flash the candidate and verify the written bytes.
- [ ] Boot the Orange Pi from the microSD and prove the installer sees SD as root before it writes; confirm eMMC target and log the copy/readback/resize result.
- [ ] Remove the SD, power-cycle, and verify eMMC root, 1080i50, NV12 video plane, healthy ext4, Pocket 3 picture that moves, and audible microphone sound.
- [ ] If any gate fails, repair the candidate and repeat the specific failed gate; retain the original eMMC backup.

## Task 6 — Public release and clear instructions

**Files:** README.md; image/README.md; release notes and assets.

- [ ] Update user instructions to state the exact flash, SD boot, eMMC install and cold-boot sequence, credentials policy, boot-source limitation and known first-launch SIGSEGV.
- [ ] Re-run documentation links and syntax checks; commit source changes to main.
- [ ] Create a draft release with the validated compressed image, SHA-256 and notes; inspect its assets and hash.
- [ ] Publish the release only after the full hardware gate is complete; attach and verify the public download link.
