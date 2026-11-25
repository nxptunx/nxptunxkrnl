#!/system/bin/sh
# Load all bundled USB Wi-Fi modules in dependency order.
# Safe to run more than once; already-loaded modules are ignored by insmod.

MODDIR=/vendor/lib/modules
MODPROBE=/vendor/bin/modprobe
[ -x "$MODPROBE" ] || MODPROBE="$MODDIR/modprobe"

mods="
mt76
mt76-usb
mt76x2-common
mt7601u
mt76x0
mt76x2u
rtl8xxxu
rtw_core
rtw_usb
rtw_88xxa
rtw_8723x
rtw_8703b
rtw_8723d
rtw_8812a
rtw_8814a
rtw_8821a
rtw_8821c
rtw_8822b
rtw_8822c
rtw_8723du
rtw_8812au
rtw_8814au
rtw_8821au
rtw_8821cu
rtw_8822bu
rtw_8822cu
"

for m in $mods; do
  [ -f "$MODDIR/$m.ko" ] || continue
  "$MODPROBE" "$m" >/dev/null 2>&1
done

echo "USB Wi-Fi modules loaded:"
lsmod 2>/dev/null | grep -E '^(mt76|rtl8|rtw_)' || echo "(none)"
