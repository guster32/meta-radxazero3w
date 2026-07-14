# Rockchip vendor kernel 6.6.89
# Based on https://github.com/rockchip-linux/kernel branch linux-6.6-stan-rkr1

require recipes-kernel/linux/linux-yocto.inc

KBRANCH = "develop-6.6"
SRCREV = "1ba51b059f25533c5529b7f68186190b47d6a7b3"

# Use the new git: fetcher (not the legacy git:// fetcher).
# The git:// fetcher tries HTTP mirror tarballs first, then a
# git clone --bare --mirror with a URL-mangling step that inserts
# '/git/' into the path, and only then falls back to git fetch.
# On the 3.8GB ARM64 builder, the mirror-fallback dance triggers an
# OOM kill while retrying. The git: fetcher does a direct git clone
# (no mirror fallback, no URL mangling), honors ;depth=1 properly, and
# is significantly faster. ;nobranch=1 skips fetching all branches
# and tags; SRCREV pins a specific commit, so only that one is needed.
SRC_URI = "git:github.com/rockchip-linux/kernel.git;protocol=https;nobranch=1;depth=1"

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
