#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[ -f "$WORKSPACE/.kernelrelease" ] || { echo "Run scripts/build.sh first" >&2; exit 1; }
KVER="$(cat "$WORKSPACE/.kernelrelease")"
DATE="$(date +%Y%m%d-%H%M)"
AK_ZIP="$ARTIFACTS_DIR/AnyKernel3-lime-${KVER}-${DATE}.zip"
MOD_ZIP="$ARTIFACTS_DIR/modules-lime-${KVER}-${DATE}.zip"

mkdir -p "$ARTIFACTS_DIR"
[ -d "$AK_DIR" ] || { echo "AnyKernel3 checkout missing at $AK_DIR" >&2; exit 1; }

echo "=== Preparing AnyKernel3 package ==="
rm -rf "$AK_DIR/.git" "$AK_DIR/README.md" "$AK_DIR/anykernel.sh" \
  "$AK_DIR/ramdisk" "$AK_DIR/patch" "$AK_DIR/split_img" "$AK_DIR/modules"

cp "$WORKSPACE/anykernel/anykernel.sh" "$AK_DIR/anykernel.sh"
sed -i "s|__KERNEL_STRING__|Lime USB-WiFi ${KVER} ${DATE}|g" "$AK_DIR/anykernel.sh"

cp "$OUT_DIR/arch/arm64/boot/Image.gz" "$AK_DIR/Image.gz"

echo "=== Staging modules for $KVER ==="
rm -rf "$STAGING_DIR"
MODROOT="$STAGING_DIR/lib/modules/$KVER"
mkdir -p "$MODROOT"

copy_ko() {
  local search_dir="$1"
  [ -d "$search_dir" ] || return 0
  while IFS= read -r -d '' f; do
    cp -f "$f" "$MODROOT/$(basename "$f")"
  done < <(find "$search_dir" -type f -name '*.ko' -print0)
}

copy_ko "$OUT_DIR"
copy_ko "$RTW88_DIR"

[ -f "$OUT_DIR/modules.builtin" ] && cp "$OUT_DIR/modules.builtin" "$MODROOT/modules.builtin"
[ -f "$OUT_DIR/Module.symvers" ] && cp "$OUT_DIR/Module.symvers" "$MODROOT/Module.symvers"

if ! (cd "$STAGING_DIR" && depmod -b . "$KVER"); then
  echo "::warning::depmod failed; modules.dep will be empty and modprobe will fall back to direct insmod"
  : > "$MODROOT/modules.dep"
fi

echo "Modules staged: $(find "$MODROOT" -maxdepth 1 -name '*.ko' | wc -l)"

echo "=== Copying modules, firmware and helpers into AnyKernel3 ==="
AKMOD="$AK_DIR/modules/vendor/lib/modules"
mkdir -p "$AKMOD" "$AK_DIR/modules/vendor/firmware" \
  "$AK_DIR/modules/vendor/bin" "$AK_DIR/modules/vendor/etc/init"
cp -af "$MODROOT"/. "$AKMOD"/

if [ -d "$FIRMWARE_DIR/vendor/firmware" ]; then
  cp -af "$FIRMWARE_DIR/vendor/firmware"/. "$AK_DIR/modules/vendor/firmware"/
fi

cp "$WORKSPACE/modules/bin/modprobe" "$AK_DIR/modules/vendor/bin/modprobe"
cp "$WORKSPACE/modules/bin/load-usb-wifi.sh" "$AK_DIR/modules/vendor/bin/load-usb-wifi.sh"
chmod 0755 "$AK_DIR/modules/vendor/bin/modprobe" "$AK_DIR/modules/vendor/bin/load-usb-wifi.sh"
cp "$WORKSPACE/modules/etc/init/usb-wifi.rc" "$AK_DIR/modules/vendor/etc/init/usb-wifi.rc"
chmod 0644 "$AK_DIR/modules/vendor/etc/init/usb-wifi.rc"

echo "=== Creating zips ==="
rm -f "$AK_ZIP" "$MOD_ZIP"
(
  cd "$AK_DIR"
  zip -r9 "$AK_ZIP" . -x '.git*' 'README.md' '*placeholder*' '*.tar.gz'
)

PKGROOT="$WORKSPACE/module-package"
rm -rf "$PKGROOT"
mkdir -p "$PKGROOT/lib/modules/$KVER" "$PKGROOT/vendor/firmware" \
  "$PKGROOT/vendor/bin" "$PKGROOT/vendor/etc/init"
cp -af "$MODROOT"/. "$PKGROOT/lib/modules/$KVER"/
if [ -d "$FIRMWARE_DIR/vendor/firmware" ]; then
  cp -af "$FIRMWARE_DIR/vendor/firmware"/. "$PKGROOT/vendor/firmware"/
fi
cp "$WORKSPACE/modules/bin/modprobe" "$PKGROOT/vendor/bin/modprobe"
cp "$WORKSPACE/modules/bin/load-usb-wifi.sh" "$PKGROOT/vendor/bin/load-usb-wifi.sh"
chmod 0755 "$PKGROOT/vendor/bin/modprobe" "$PKGROOT/vendor/bin/load-usb-wifi.sh"
cp "$WORKSPACE/modules/etc/init/usb-wifi.rc" "$PKGROOT/vendor/etc/init/usb-wifi.rc"
chmod 0644 "$PKGROOT/vendor/etc/init/usb-wifi.rc"
(
  cd "$PKGROOT"
  zip -r9 "$MOD_ZIP" .
)

{
  echo
  echo "Packaged kernel release: $KVER"
  echo "Packaged .ko files: $(find "$MODROOT" -maxdepth 1 -name '*.ko' | wc -l)"
  echo "AnyKernel zip: $(basename "$AK_ZIP")"
  echo "Modules zip: $(basename "$MOD_ZIP")"
} >> "$ARTIFACTS_DIR/build-report.txt"

echo "=== Package complete ==="
ls -lh "$AK_ZIP" "$MOD_ZIP"
