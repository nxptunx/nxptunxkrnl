#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DEFCONFIG="${DEFCONFIG:-vendor/bengal-perf_defconfig}"
BUILD_RTW88="${BUILD_RTW88:-1}"
case "${BUILD_RTW88,,}" in
  1|true|yes|on) BUILD_RTW88=1 ;;
  *) BUILD_RTW88=0 ;;
esac

[ -d "$KERNEL_DIR" ] || { echo "Kernel source missing at $KERNEL_DIR" >&2; exit 1; }
mkdir -p "$OUT_DIR" "$ARTIFACTS_DIR"

BASE_CONFIG="${BASE_CONFIG:-$WORKSPACE/config/lime-stock.config}"

if [ -f "$BASE_CONFIG" ]; then
  echo "=== Configuring $DEVICE from stock kernel config ==="
  cp -f "$BASE_CONFIG" "$OUT_DIR/.config"
else
  echo "=== Configuring $DEVICE with $DEFCONFIG ==="
  kmake "$DEFCONFIG"
fi

echo "=== Merging lime + USB Wi-Fi fragments ==="
(
  cd "$KERNEL_DIR"
  bash scripts/kconfig/merge_config.sh -m -O "$OUT_DIR" \
    "$OUT_DIR/.config" \
    "$KERNEL_DIR/arch/arm64/configs/vendor/xiaomi/lime.config" \
    "$WORKSPACE/config/usb-wifi-modules.config"
)

kmake olddefconfig

echo "=== Building kernel + in-tree modules ==="
kmake -j"$JOBS" Image.gz modules

KVER="$(kmake -s kernelrelease)"
echo "$KVER" > "$WORKSPACE/.kernelrelease"
echo "Kernel release: $KVER"

echo "=== Verifying config ==="
for sym in MODULES MODULE_UNLOAD MAC80211 RTL8XXXU MT76x0U MT76x2U; do
  grep -E "^CONFIG_${sym}=" "$OUT_DIR/.config" || true
done
grep -q '^CONFIG_MODULE_SIG_FORCE=y' "$OUT_DIR/.config" && {
  echo "ERROR: forced module signing is still enabled" >&2
  exit 1
} || true

RTW_STATUS="disabled"
if [ "$BUILD_RTW88" = "1" ] && [ -d "$RTW88_DIR" ]; then
  echo "=== Building external RTW88 modules ==="
  if kmake -j"$JOBS" M="$RTW88_DIR" modules; then
    RTW_STATUS="success"
  else
    RTW_STATUS="failed"
    echo "::warning::RTW88 external module build failed; kernel and in-tree modules are still usable."
  fi
fi
echo "$RTW_STATUS" > "$WORKSPACE/.rtw88-status"

{
  echo "Device: $DEVICE"
  echo "Kernel release: $KVER"
  echo "Base config: ${BASE_CONFIG:-$DEFCONFIG}"
  echo "Kernel ref: ${KERNEL_REF:-staging/16.2}"
  echo "RTW88 module build: $RTW_STATUS"
  echo "In-tree + external .ko count: $(find "$OUT_DIR" "$RTW88_DIR" -type f -name '*.ko' 2>/dev/null | wc -l)"
} > "$ARTIFACTS_DIR/build-report.txt"

echo "=== Build complete ==="
cat "$ARTIFACTS_DIR/build-report.txt"
