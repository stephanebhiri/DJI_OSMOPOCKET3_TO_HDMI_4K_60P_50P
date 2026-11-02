#!/usr/bin/env bash
# Read-only health check for the Orange Pi 5 Plus Pocket 3 -> HDMI appliance.
# It does not restart services, touch USB, or write to eMMC.
set -u

failures=0
pass() { printf 'OK   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }
note() { printf 'NOTE %s\n' "$1"; }

root=$(findmnt -n -o SOURCE,FSTYPE / 2>/dev/null || true)
case "$root" in
  /dev/mmcblk*p*' ext4')
    disk=${root%%p*}
    if [[ $(cat "/sys/block/${disk##*/}/device/type" 2>/dev/null) == MMC ]]; then
      pass "racine eMMC ext4 : $root"
    else
      fail "racine sur carte SD, pas sur eMMC : $root"
    fi ;;
  *) fail "racine attendue sur eMMC ext4, obtenue : ${root:-inconnue}" ;;
esac

[[ $(uname -r) == 6.1.115-vendor-rk35xx ]] \
  && pass 'noyau fournisseur 6.1.115' \
  || fail "noyau différent : $(uname -r)"

if lsusb -d 2ca3:0023 2>/dev/null | grep -q .; then
  pass 'Pocket 3 en mode webcam (2ca3:0023)'
else
  fail 'Pocket 3 absente ou en mode transfert ; reconnecter USB et choisir webcam'
fi

for unit in osmo-hdmi50 dji-h264-stream dji-hdmi-audio; do
  if [[ $(systemctl is-active "$unit.service" 2>/dev/null) == active ]]; then
    pass "service $unit actif"
  else
    fail "service $unit inactif"
  fi
done

if grep -q 'Display mode: 1920x1080i50' /sys/kernel/debug/dri/0/summary 2>/dev/null; then
  pass 'HDMI en 1920x1080i50'
else
  fail 'mode HDMI 1920x1080i50 absent'
fi

if grep -A8 'plane\[114\]' /sys/kernel/debug/dri/0/state 2>/dev/null |
    grep -q 'format=NV12'; then
  pass 'plan KMS 114 actif en NV12'
else
  fail 'plan KMS 114 absent ou sans image NV12'
fi

if command -v python3 >/dev/null; then
  cadence=$(python3 - <<'PY'
import re
import time

path = '/sys/kernel/debug/dri/0/state'
samples = []
start = time.monotonic()
while time.monotonic() - start < 3.0:
    try:
        data = open(path).read()
    except OSError:
        break
    match = re.search(r'plane\[114\].*?\n\s*crtc=video_port1\n\s*fb=(\d+)', data, re.S)
    samples.append(int(match.group(1)) if match else -1)
    time.sleep(0.01)
elapsed = time.monotonic() - start
changes = sum(a != b for a, b in zip(samples, samples[1:]))
print(f'{changes / elapsed:.1f}' if elapsed and samples else '0')
PY
  )
  if awk -v fps="$cadence" 'BEGIN { exit !(fps >= 35) }'; then
    pass "cadence du plan HDMI : $cadence changements/s (seuil 35)"
  else
    fail "cadence du plan HDMI insuffisante : $cadence changements/s"
  fi
else
  fail 'python3 absent : cadence HDMI non mesurée'
fi

cache=/root/.spspps/0
expected=116eaddd34020344a16a378759b0a1f41fd07d9ca3e8aaf7ed0f7611ad66169e
actual=$(sha256sum "$cache" 2>/dev/null | awk '{print $1}')
[[ $actual == "$expected" ]] \
  && pass 'cache SPS/PPS 4K50 conforme' \
  || fail "cache SPS/PPS différent : ${actual:-absent}"
if lsattr "$cache" 2>/dev/null | awk '{print $1}' | grep -q 'i'; then
  pass 'cache SPS/PPS protégé contre les réécritures'
else
  fail 'cache SPS/PPS non protégé'
fi

video=/usr/local/bin/dji-stream.sh
if grep -q 'sync=false' "$video" 2>/dev/null; then
  pass 'sortie vidéo configurée avec sync=false'
else
  fail 'sortie vidéo sans sync=false'
fi

audio=/usr/local/bin/dji-hdmi-audio.sh
audio_hash=$(sha256sum "$audio" 2>/dev/null | awk '{print $1}')
if [[ $audio_hash == 5c5c41948b1ada69a0a7a57c5192329431163ba6fe005ee727b295e49b804a60 ]]; then
  pass 'script audio vérifié, sans gain ajouté'
else
  fail "script audio différent : ${audio_hash:-absent}"
fi

camera_card=$(awk '/\[DJIPocket3/ {print $1; exit}' /proc/asound/cards 2>/dev/null)
hdmi_card=$(awk '/\[rockchiphdmi1/ {print $1; exit}' /proc/asound/cards 2>/dev/null)
if [[ -n $camera_card && -n $hdmi_card ]] &&
   grep -q RUNNING "/proc/asound/card${camera_card}/pcm0c/sub0/status" 2>/dev/null &&
   grep -q RUNNING "/proc/asound/card${hdmi_card}/pcm0p/sub0/status" 2>/dev/null; then
  pass 'capture Pocket 3 et lecture HDMI actives dans ALSA'
else
  fail 'capture Pocket 3 ou lecture HDMI inactive dans ALSA'
fi

note "Le contrôle logiciel ne prouve pas que l'écran montre la caméra ni que son haut-parleur est audible."
note "Après une nouvelle installation, vérifier une fois l'image mobile et la voix sur l'écran."
printf 'RESULTAT %s\n' "$([[ $failures == 0 ]] && echo 'OK' || echo "$failures anomalie(s)")"
(( failures == 0 ))
