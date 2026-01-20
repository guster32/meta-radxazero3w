# Rockchip vendor kernel 6.6.89
# Based on https://github.com/rockchip-linux/kernel branch linux-6.6-stan-rkr1

require recipes-kernel/linux/linux-yocto.inc

KBRANCH = "develop-6.6"
SRCREV = "1ba51b059f25533c5529b7f68186190b47d6a7b3"

SRC_URI = "git://github.com/rockchip-linux/kernel.git;protocol=https;branch=${KBRANCH}"

LINUX_VERSION = "6.6.89"
LINUX_VERSION_EXTENSION = "-rockchip"
PV = "${LINUX_VERSION}+git${SRCPV}"

# Rockchip-specific configuration
KCONFIG_MODE = "alldefconfig"
KBUILD_DEFCONFIG = "rockchip_linux_defconfig"

# Compatible with RK3566, RK3568, RK3588 platforms
COMPATIBLE_MACHINE = "(rk3566|rk3568|rk3588|radxa-zero3w)"

# Metadata
DESCRIPTION = "Rockchip vendor Linux kernel 6.6.89 with full hardware support"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

# Required for device tree overlays
KERNEL_DTC_FLAGS += "-@"
