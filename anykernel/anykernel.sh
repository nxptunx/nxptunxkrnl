### AnyKernel3 script for Redmi 9T (lime) USB Wi-Fi kernel
## Generated from this repository's template.

properties() { '
kernel.string=__KERNEL_STRING__
do.devicecheck=1
do.modules=1
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=lime
device.name2=Lime
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

BLOCK=boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh;

ui_print " ";
ui_print "Installing nxptunxkrnl";

dump_boot;
write_boot;

ui_print " ";
ui_print "Kernel flashed. Modules are installed through the AK3 helper.";
ui_print "Reboot, then run /vendor/bin/load-usb-wifi.sh as root if needed.";
ui_print " ";
