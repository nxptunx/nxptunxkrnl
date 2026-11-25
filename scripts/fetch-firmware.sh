#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

FWROOT="$FIRMWARE_DIR/vendor/firmware"
mkdir -p "$FWROOT/rtlwifi" "$FWROOT/rtw88"

BASE="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain"

MEDIATEK_FW=(
  mediatek/mt7601u.bin
  mediatek/mt7610u.bin
  mediatek/mt7662u.bin
  mediatek/mt7662u_rom_patch.bin
)

RTLWIFI_FW=(
  rtlwifi/rtl8192cufw.bin
  rtlwifi/rtl8192cufw_TMSC.bin
  rtlwifi/rtl8188eufw.bin
  rtlwifi/rtl8723aufw_A.bin
)

for fw in "${MEDIATEK_FW[@]}"; do
  out="$FWROOT/$(basename "$fw")"
  echo "Fetching $fw"
  curl -L --fail --retry 3 --retry-delay 2 -o "$out" "$BASE/$fw"
done

for fw in "${RTLWIFI_FW[@]}"; do
  out="$FWROOT/rtlwifi/$(basename "$fw")"
  echo "Fetching $fw"
  curl -L --fail --retry 3 --retry-delay 2 -o "$out" "$BASE/$fw"
done

if [ -d "$RTW88_DIR/firmware" ]; then
  echo "Copying RTW88 firmware"
  cp -f "$RTW88_DIR"/firmware/*.bin "$FWROOT/rtw88/" 2>/dev/null || true
else
  echo "::warning::RTW88 firmware directory not found"
fi

echo "Firmware staged in $FWROOT"
find "$FWROOT" -type f | sort
