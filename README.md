# Lime USB Wi-Fi kernel build

Builds a Halcyon OS 16.2 / Android 16 kernel for the Redmi 9T (`lime`, SM6115 / SD 662)
with:

- loadable `.ko` modules (`insmod` / `modprobe`-style),
- unsigned third-party modules allowed,
- USB host Wi-Fi support,
- common Realtek / MediaTek USB Wi-Fi drivers,
- firmware bundled in an AnyKernel3 flashable zip.

Everything is fetched and staged **inside this workspace**:

| Path | Contents |
| --- | --- |
| `kernel/` | Halcyon `liliumproject/kernel_xiaomi_chime` source |
| `AK3/` | AnyKernel3 checkout used for the flashable zip |
| `external/rtw88-android/` | External Realtek RTW88 driver suite |
| `toolchain/` | Lilium clang toolchain |
| `out/` | Kernel build output |
| `firmware/` | Downloaded firmware staging |
| `artifacts/` | Final zips and build report |

## Available drivers

### In-tree, built as modules

- `rtl8xxxu` — RTL8188CU/RTL8192CU/RTL8723AU family
- `rtl8192cu` — rtlwifi variant of RTL8192CU
- `mt7601u`
- `mt76x0` — MT7610U USB (`mt76` + `mt76-usb` are loaded as dependencies)
- `mt76x2u` — MT7612U / MT7662U USB

### External RTW88 suite

Built out-of-tree against the same kernel tree:

- RTL8811AU / RTL8812AU / RTL8821AU
- RTL8814AU
- RTL8821CU / RTL8822BU / RTL8822CU
- RTL8723DU

The loader script also includes the SDIO/PCI RTW88 modules if the sources build them,
but the phone use case here is USB OTG.

If your adapter uses a different chipset, identify it first (see below) and add a
compatible driver source under `external/`.

## Build on GitHub Actions

1. Put these files in a GitHub repository.
2. Enable Actions.
3. Run the workflow manually (`Actions → Build lime USB Wi-Fi kernel → Run workflow`)
   or push to `main`/`master`.

Inputs:

- `kernel_ref`: kernel branch, default `bloom`
- `defconfig`: `vendor/bengal_defconfig` or `vendor/bengal-perf_defconfig`
- `build_rtw88`: build external Realtek modules, default `true`

Artifacts:

- `AnyKernel3-lime-<version>-<date>.zip` — kernel + modules + firmware
- `modules-lime-<version>-<date>.zip` — modules/firmware only, for manual install
- `build-report.txt`

Tagged releases also publish the artifacts to a GitHub Release.

## Build locally

From this directory:

```bash
mkdir -p kernel AK3 external
git clone --depth=1 -b bloom \
  https://github.com/liliumproject/kernel_xiaomi_chime.git kernel
git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git AK3
git clone --depth=1 \
  https://github.com/ShorterKing/RTW88-Android-Drivers.git \
  external/rtw88-android

bash scripts/download_toolchain.sh
bash scripts/build.sh
bash scripts/fetch-firmware.sh
bash scripts/package_anykernel.sh
```

The build script applies:

1. `vendor/bengal_defconfig` (or the selected defconfig)
2. `kernel/arch/arm64/configs/vendor/xiaomi/lime.config`
3. `config/usb-wifi-modules.config`

Important config choices:

- `CONFIG_MODULES=y`, `CONFIG_MODULE_UNLOAD=y`, `CONFIG_MODVERSIONS=y`
- `CONFIG_MODULE_SIG_FORCE` is disabled so unsigned `.ko` files can load
- `CONFIG_MAC80211=y` and `CONFIG_CFG80211=y` for mac80211 drivers
- USB host/xHCI/DWC3 options kept explicit
- The gzip kernel image is used; **DTB/DTBO from the ROM is preserved**, not replaced

## Flash

Halcyon's `lime` device page lists firmware `14.0.5.0.SJQMIXM` as the required base.
Update to that firmware first if you are on an older build.

1. Boot into recovery.
2. Flash `AnyKernel3-lime-*.zip`.
3. Reboot.

The zip uses `do.modules=1` and `do.systemless=1`, so modules/firmware/scripts are
installed through the AnyKernel3 helper when Magisk or KernelSU is detected. Without
one of those, the kernel still flashes, but `/vendor` is normally read-only and the
modules will not persist. In that case use the modules-only zip with a rooted/overlayed
`/vendor`.

## Use the modules

After reboot with root:

```bash
adb shell su -c '/vendor/bin/load-usb-wifi.sh'
adb shell su -c 'lsmod | grep -E "^(mt76|rtl8|rtw_)"'
adb shell su -c 'ip link show'
```

Debian-like single-module loading:

```bash
adb shell su -c '/vendor/bin/modprobe mt76x2u'
adb shell su -c '/vendor/bin/modprobe rtw_8821au'
adb shell su -c '/vendor/bin/modprobe -r rtw_8821au'
```

`modprobe` reads `/vendor/lib/modules/modules.dep` and calls `insmod` on dependencies
first. Plug in the OTG adapter after the modules are loaded (or use the included
`usb-wifi.rc`, which attempts loading after boot).

Firmware locations:

```text
/vendor/firmware/mt7601u.bin
/vendor/firmware/mediatek/mt7610u.bin
/vendor/firmware/mediatek/mt7662u.bin
/vendor/firmware/mediatek/mt7662u_rom_patch.bin
/vendor/firmware/rtlwifi/*.bin
/vendor/firmware/rtw88/*.bin
```

`mt7601u` is the exception: its driver requests the firmware from the root,
while `mt76x0`/`mt76x2u` request files from the `mediatek/` subdirectory.

## Identify your USB Wi-Fi adapter

Android usually has no `lsusb`. With the adapter connected via OTG:

```bash
adb shell su -c 'cat /proc/bus/usb/devices'
adb shell su -c 'dmesg | grep -i -E "usb|wireless|rtw|mt76"'
```

Look for lines such as `Vendor=0bda ProdID=8812` or text like
`ID 0bda:8812`. Common IDs:

| VID:PID | Likely chipset | Driver in this build |
| --- | --- | --- |
| `0bda:8812`, `0bda:881a`, `0bda:881b`, `0bda:881c` | RTL8812AU | `rtw_8812au` |
| `0bda:8811` family | RTL8811AU | `rtw_8812au` |
| `0bda:0821`, `0bda:a811` family | RTL8821AU | `rtw_8821au` |
| `0e8d:7610` / `0e8d:7612` family | MT7610U / MT7612U | `mt76x0` / `mt76x2u` |
| `148f:7601` | MT7601U | `mt7601u` |
| `0bda:8176`, `0bda:8192` family | RTL8188/8192 USB | `rtl8xxxu` / `rtl8192cu` |

Vendor-specific IDs vary. If your ID is not in the table, search the driver source
`supported-device-IDs` files or send me the `dmesg` output and I can add the right driver.

## Limitations and warnings

- Module signature forcing is disabled. This is necessary for unsigned third-party
  `.ko` modules, but it weakens module authenticity checks. Use at your own risk.
- This is a legacy non-GKI kernel; there is no `vendor_boot.img` flow here. The
  AnyKernel3 zip preserves the ROM ramdisk, DTB and DTBO.
- Adapter support depends on the exact chipset. Some cheap adapters use multi-state
  USB storage/firmware modes and need `usb_modeswitch`, which is not included.
- If the RTW88 out-of-tree build fails in Actions, the kernel and in-tree modules are
  still packaged; check `build-report.txt` and the workflow log.
- Flash only on `lime`. `device.name1=lime` is enforced by the AnyKernel3 script.
