# Rockchip Vendor Kernel 6.6 for Radxa Zero 3W

This directory contains the Yocto recipe files to build Rockchip's vendor kernel 6.6.89 for the Radxa Zero 3W board.

## Overview

The Rockchip vendor kernel provides complete hardware support including:

- ✅ All RK3566 peripherals (GPU, VPU, USB, etc.)
- ✅ **MIPI CSI camera** (RKCIF + RKISP drivers)
- ✅ **Hardware video encoding/decoding** (MPP service)
- ✅ WiFi/Bluetooth (AIC8800D80)
- ✅ HDMI output
- ✅ Ethernet
- ✅ All sensors and I/O

## Files in this Directory

```
linux-rockchip-6.6/
├── rk3566-radxa-zero-3w.dts                          # Main device tree
├── rk3566-radxa-zero-3w-imx708.dtso                 # Camera overlay for IMX708
├── defconfig                                         # Kernel config fragment
├── 0001-arm64-dts-rockchip-Add-Radxa-Zero-3W-support.patch
└── README.md                                         # This file
```

## Parent Recipe (linux-rockchip_6.6.bb)

You'll need to create a base recipe in your BSP layer or use meta-rockchip. Example:

**File:** `recipes-kernel/linux/linux-rockchip_6.6.bb`

```bitbake
require recipes-kernel/linux/linux-yocto.inc

KBRANCH = "linux-6.6-stan-rkr1"
SRC_URI = "git://github.com/rockchip-linux/kernel.git;protocol=https;branch=${KBRANCH}"
SRCREV = "${AUTOREV}"

LINUX_VERSION = "6.6.89"
LINUX_VERSION_EXTENSION = "-rockchip"

PV = "${LINUX_VERSION}+git${SRCPV}"

COMPATIBLE_MACHINE = "(rk3566|rk3568|rk3588)"

# Required for device tree overlays
KERNEL_DTC_FLAGS += "-@"

# Default defconfig
KCONFIG_MODE = "alldefconfig"
KBUILD_DEFCONFIG = "rockchip_linux_defconfig"

```

# To print extra logging when kernel boot hangs:

From u-boot (notice the kernel arguments for extra logging):

```
ext4load mmc 1:1 ${kernel_addr_r} /Image-initramfs-radxa-zero3w.bin
ext4load mmc 1:1 ${fdt_addr_r} /rk3566-radxa-zero-3w.dtb
setenv bootargs 'console=ttyS2,1500000 earlycon=uart8250,mmio32,0xfe660000 ignore_loglevel loglevel=8 keep_bootcon panic=10 initcall_debug clk_ignore_unused pd_ignore_unused'
booti ${kernel_addr_r} - ${fdt_addr_r}
```
