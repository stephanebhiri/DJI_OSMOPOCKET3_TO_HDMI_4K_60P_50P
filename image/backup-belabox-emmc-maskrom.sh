#!/usr/bin/env bash
# Read-only, board-specific rescue capture of the working BELABOX eMMC.
# Run on macOS after entering MaskROM; never writes a sector to the Orange Pi.
set -Eeuo pipefail

if (( $# == 0 )); then
  workspace=$(cd "$(dirname "$0")/../.." && pwd)
  set -- "$workspace/rkdeveloptool/rkdeveloptool" \
    "$workspace/rkbin-mini/rk3588_loader_v1.24.114.bin" \
    "$workspace/OSMO2HDMI-BELABOX-working-$(date +%F)"
fi
if (( $# != 3 )); then
  echo 'Usage: backup-belabox-emmc-maskrom.sh <rkdeveloptool> <rk3588-loader.bin> <output-prefix>' >&2
  exit 2
fi
rktool=$1
loader=$2
prefix=$3
[[ -x $rktool && -f $loader ]] || { echo 'Missing rkdeveloptool or loader' >&2; exit 2; }
[[ $(uname -s) == Darwin ]] || { echo 'This capture script requires macOS' >&2; exit 2; }
[[ -d $(dirname "$prefix") ]] || { echo 'Output directory missing' >&2; exit 2; }
rktool="$(cd "$(dirname "$rktool")" && pwd)/$(basename "$rktool")"
loader="$(cd "$(dirname "$loader")" && pwd)/$(basename "$loader")"
prefix="$(cd "$(dirname "$prefix")" && pwd)/$(basename "$prefix")"
cd "$(dirname "$prefix")"    # rkdeveloptool keeps its own log/ beside the output
for suffix in .img .img.part .img.gz .img.gz.part .img.gz.sha256 .sha256 .chunks.sha256; do
  [[ ! -e ${prefix}${suffix} ]] || { echo "Refusing to overwrite ${prefix}${suffix}" >&2; exit 2; }
done
available_kib=$(df -Pk "$(dirname "$prefix")" | awk 'END {print $4}')
(( available_kib >= 10485760 )) || { echo 'At least 10 GiB free space required' >&2; exit 2; }

device_list=$("$rktool" ld 2>&1) || {
  printf '%s\n' "$device_list" >&2
  echo 'MaskROM device detection failed; no eMMC data read' >&2
  exit 2
}
printf '%s\n' "$device_list"
[[ $(grep -Eic 'Maskrom' <<< "$device_list") == 1 ]] &&
  grep -Eiq 'Vid=0x2207,Pid=0x350b' <<< "$device_list" || {
    echo 'Exactly one RK3588 in MaskROM is required; no eMMC data read' >&2
    exit 2
  }

"$rktool" db "$loader"
"$rktool" cs 1
flash_info=$($rktool rfi)
printf '%s\n' "$flash_info"
grep -Eq '120832000[[:space:]]+Sectors' <<< "$flash_info" || {
  echo 'Unexpected eMMC capacity; no eMMC data read' >&2
  exit 2
}

chunk_sectors=1048576              # 512 MiB
chunk_bytes=536870912
chunk_count=12                     # 6 GiB, covers the entire current rootfs
tmpdir=$(mktemp -d "$(dirname "$prefix")/.osmo-backup.XXXXXX")
trap 'echo "Capture interrupted; partial files retained at $prefix and $tmpdir" >&2' ERR
: >"${prefix}.img.part"
: >"${prefix}.chunks.sha256"
for (( i=0; i<chunk_count; i++ )); do
  start=$((i * chunk_sectors))
  chunk="$tmpdir/chunk-$(printf '%02d' "$i").bin"
  printf 'Reading eMMC block %d/%d, LBA %d...\n' "$((i + 1))" "$chunk_count" "$start"
  "$rktool" rl "$start" "$chunk_sectors" "$chunk"
  actual_bytes=$(stat -f %z "$chunk")
  (( actual_bytes == chunk_bytes )) || {
    echo "Short read at LBA $start: $actual_bytes bytes" >&2
    exit 1
  }
  shasum -a 256 "$chunk" >>"${prefix}.chunks.sha256"
  cat "$chunk" >>"${prefix}.img.part"
  rm "$chunk"
done
rmdir "$tmpdir"
[[ $(stat -f %z "${prefix}.img.part") == 6442450944 ]] || {
  echo 'Unexpected final image size' >&2; exit 1;
}
mv "${prefix}.img.part" "${prefix}.img"
shasum -a 256 "${prefix}.img" >"${prefix}.sha256"
gzip -1 -c "${prefix}.img" >"${prefix}.img.gz.part"
set -o pipefail
decompressed_hash=$(gzip -cd "${prefix}.img.gz.part" | shasum -a 256 | awk '{print $1}')
source_hash=$(awk '{print $1}' "${prefix}.sha256")
[[ $decompressed_hash == "$source_hash" ]] || {
  echo 'Compressed image does not match the captured bytes' >&2; exit 1;
}
mv "${prefix}.img.gz.part" "${prefix}.img.gz"
printf '%s  %s\n' "$(shasum -a 256 "${prefix}.img.gz" | awk '{print $1}')" "$(basename "${prefix}.img.gz")" >"${prefix}.img.gz.sha256"
trap - ERR
echo "Captured 6 GiB of eMMC; archive: ${prefix}.img.gz"
echo 'This is a private image of this exact board. Do not publish it unchanged.'
