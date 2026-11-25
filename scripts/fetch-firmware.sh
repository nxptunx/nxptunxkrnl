#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

FWROOT="$FIRMWARE_DIR/vendor/firmware"
mkdir -p "$FWROOT/rtlwifi" "$FWROOT/rtw88" "$FWROOT/mediatek"

BASE="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain"

# The in-tree mt7601u driver requests "mt7601u.bin" at the firmware root,
# while mt76x0/mt76x2u request "mediatek/<file>".
MT7601U_FW="mediatek/mt7601u.bin"

MEDIATEK_FW=(
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

echo "Fetching $MT7601U_FW to firmware root"
curl -L --fail --retry 3 --retry-delay 2 \
  -o "$FWROOT/mt7601u.bin" "$BASE/$MT7601U_FW"

for fw in "${MEDIATEK_FW[@]}"; do
  out="$FWROOT/$fw"
  mkdir -p "$(dirname "$out")"
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
