#!/usr/bin/env bash
# Run inside the mounted ARM64 Noble rootfs/chroot after the OS is upgraded.
set -Eeuo pipefail

DJI_SOURCE_ROOT=${DJI_SOURCE_ROOT:-/opt/dji-build}

dji_set_boot_args() {
  local file="$1" args arg tmp
  [[ -f "$file" ]] || { echo "Missing boot config: $file" >&2; return 1; }
  args="$(sed -n 's/^extraargs=//p' "$file" | head -1)"
  for arg in 'usbcore.quirks=2ca3:0023:i' 'video=HDMI-A-1:1920x1080i@50' 'cma=256M'; do
    case " $args " in
      *" $arg "*) ;;
      *) args="${args:+$args }$arg" ;;
    esac
  done
  tmp="$(mktemp "${file}.XXXXXX")"
  if grep -q '^extraargs=' "$file"; then
    awk -v value="extraargs=$args" '/^extraargs=/ { if (!done) print value; done=1; next } { print }' "$file" >"$tmp"
  else
    cat "$file" >"$tmp"
    printf 'extraargs=%s\n' "$args" >>"$tmp"
  fi
  chmod 644 "$tmp"
  mv "$tmp" "$file"
}

dji_link_plugin() {
  local name="$1" found
  found="$(find /usr/local/lib -name "$name" -type f -print -quit)"
  [[ -n "$found" ]] || { echo "Plugin missing after build: $name" >&2; return 1; }
  ln -sfn "$found" "/usr/lib/aarch64-linux-gnu/gstreamer-1.0/$name"
}

dji_provision() {
  local project="$DJI_SOURCE_ROOT/project" mpp="$DJI_SOURCE_ROOT/mpp"
  local rockchip="$DJI_SOURCE_ROOT/gstreamer-rockchip" uvc="$DJI_SOURCE_ROOT/gstlibuvch264src"
  [[ "$(uname -m)" == aarch64 ]] || { echo 'ARM64 build environment required' >&2; return 1; }
  grep -q 'VERSION_CODENAME=noble' /etc/os-release || { echo 'Ubuntu Noble required' >&2; return 1; }
  for path in "$project/dji-stream.sh" "$mpp/CMakeLists.txt" "$rockchip/meson.build" "$uvc/libuvc/CMakeLists.txt"; do
    [[ -f "$path" ]] || { echo "Missing source: $path" >&2; return 1; }
  done

  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y --no-install-recommends \
    gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-alsa \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-bad1.0-dev libdrm-dev libusb-1.0-0-dev \
    libudev-dev cmake meson ninja-build pkg-config git build-essential \
    autoconf automake libtool autopoint gettext libdrm-tests
  [[ "$(gst-launch-1.0 --version)" == *'1.24.'* ]] || { echo 'GStreamer 1.24 required' >&2; return 1; }

  cmake -S "$mpp" -B "$mpp/build" -DRKPLATFORM=ON -DHAVE_DRM=ON
  cmake --build "$mpp/build" -j "$(nproc)"
  cmake --install "$mpp/build"
  ldconfig
  ldconfig -p | grep rockchip_mpp >/dev/null

  if [[ -d "$rockchip/build" ]]; then
    meson setup --reconfigure "$rockchip/build" "$rockchip"
  else
    meson setup "$rockchip/build" "$rockchip"
  fi
  meson compile -C "$rockchip/build"
  meson install -C "$rockchip/build"
  mkdir -p /usr/lib/aarch64-linux-gnu/gstreamer-1.0
  dji_link_plugin libgstrockchipmpp.so
  dji_link_plugin libgstrkximage.so
  dji_link_plugin libgstkmssrc.so
  gst-inspect-1.0 mppvideodec >/dev/null

  if ! grep -q '^[[:space:]]*UVC_FRAME_FORMAT_H265,' "$uvc/libuvc/include/libuvc/libuvc.h"; then
    patch -d "$uvc/libuvc" -p1 <"$project/image/patches/belabox-h265-enum.patch"
  fi
  cmake -S "$uvc/libuvc" -B "$uvc/libuvc/build" -DCMAKE_INSTALL_PREFIX=/usr/local
  cmake --build "$uvc/libuvc/build" -j "$(nproc)"
  cmake --install "$uvc/libuvc/build"
  ldconfig
  if [[ -d "$uvc/libuvch264src/build" ]]; then
    meson setup --reconfigure "$uvc/libuvch264src/build" "$uvc/libuvch264src" --prefix=/usr
  else
    meson setup "$uvc/libuvch264src/build" "$uvc/libuvch264src" --prefix=/usr
  fi
  meson compile -C "$uvc/libuvch264src/build"
  meson install -C "$uvc/libuvch264src/build"
  gst-inspect-1.0 libuvch264src >/dev/null

  install -m 644 "$project/50-dji-usb.rules" /etc/udev/rules.d/
  install -m 644 "$project/99-dma-heap.rules" /etc/udev/rules.d/
  install -m 644 "$project/99-dji-camera.rules" /etc/udev/rules.d/
  install -m 755 "$project/dji-stream.sh" /usr/local/bin/dji-stream.sh
  install -m 644 "$project/dji-h264-stream.service" /etc/systemd/system/
  install -m 755 "$project/image/dji-hdmi-audio.sh" /usr/local/bin/dji-hdmi-audio.sh
  install -m 644 "$project/image/dji-hdmi-audio.service" /etc/systemd/system/
  install -m 755 "$project/image/dji-install-to-nvme.sh" /usr/local/sbin/
  install -m 644 "$project/image/dji-install-to-nvme.service" /etc/systemd/system/
  dji_set_boot_args /boot/armbianEnv.txt
  systemctl enable dji-h264-stream.service dji-hdmi-audio.service dji-install-to-nvme.service
  mkdir -p /usr/share/doc/dji-osmo2hdmi
  cp "$project/image/source-lock.txt" /usr/share/doc/dji-osmo2hdmi/
  echo 'Video stack and one-shot NVMe installer provisioned.'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dji_provision "$@"
fi
