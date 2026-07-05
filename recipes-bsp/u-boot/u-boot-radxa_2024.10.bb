# Modern mainline u-boot for Radxa Zero 3W (Rockchip RK3566).
#
# Vendor upstreams we used (e20b990-era) that didn't work:
#   1. mainline `radxa-zero-3-rk3566_defconfig` exists in v2024.10 (renamed)
#      and references CONFIG_ROCKCHIP_RK3568=y which works for the rk3566
#      board family.
#   2. radxa/u-boot fork is built only via ./make.sh which expects rbgit
#      `../rkbin` and a static cross compiler. Yocto provides a working
#      aarch64-arcadia-linux-gnu- via gcc-cross-canadian; reproducing the
#      exact radxa layout in Yocto's ${WORKDIR}/sources layout is fragile.
#   3. Rockchip vendor `radxa/rkbin` fork ships BL31 + DDR blobs at
#      bin/rk35/rk3568_bl31_v1.44.elf and rk3566_ddr_*.bin which are
#      required to compose the FIT SPL/idbloader image.
#
# What we do here:
#   - Build u-boot v2024.10 from source.denx.de/u-boot using the radxa-zero3
#     family defconfig (CONFIG_ROCKCHIP_RK3568=y; same SoC binary tree).
#   - Vendor the rkbin/tools + bin/rk35 blobs into the recipe's WORKDIR via
#     a second SCM SRCREV, with destsuffix=rkbin.
#   - In do_compile, set BL31 and ROCKCHIP_TPL env vars to the rkbin paths
#     so the rockchip make_fit_atf.sh pipeline picks them up; mainline
#     u-boot's make_fit_atf.sh honours $BL31 already, no further plumbing.
#   - Drop the result (u-boot.itb + u-boot-rockchip.bin) into /boot/u-boot.

require recipes-bsp/u-boot/u-boot-common.inc
require recipes-bsp/u-boot/u-boot.inc

SUMMARY = "U-Boot bootloader for Radxa Zero 3W (Rockchip RK3566)"
DESCRIPTION = "Mainline u-boot v2024.10 with radxa-zero3-rk3566_defconfig; \
pairs with radxa/rkbin develop-v${PV} for BL31 + DDR init blobs. \
Output is u-boot.itb + u-boot-rockchip.bin, the rockchip multi-stage \
SPL/ITB pair consumed by idbloader packing during image generation."

SRC_URI = "git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master;tag=v${PV} \
           git://github.com/radxa/rkbin.git;protocol=https;branch=develop-v${PV};name=rkbin;destsuffix=rkbin"

# Multiple SCMs in SRC_URI require SRCREV_FORMAT to disambiguate them.
# u-boot itself is the first SCM (=>SRCREV); the second is named 'rkbin'.
SRCREV_FORMAT = "_rkbin"

# u-boot v2024.10 tag points to commit 573d69af36cfb10d58e189656b03a659654b0cd9
# (verified against source.denx.de/u-boot mirror via git ls-remote).
SRCREV = "573d69af36cfb10d58e189656b03a659654b0cd9"

# rkbin develop-v2024.10 HEAD = a45caf5db84fddb3422142a77cf2b50336f11161;
# in this commit rk3566_ddr_1056MHz_v1.23.bin and rk3568_bl31_v1.44.elf
# both live in bin/rk35/ and are the binaries radxa-zero3-rk3566 expects.
SRCREV_rkbin = "a45caf5db84fddb3422142a77cf2b50336f11161"

PE = "1"

PROVIDES += "virtual/bootloader u-boot"

# --- Modern U-Boot configuration flow (wrynose 6.0) ---
UBOOT_CONFIG ??= "radxa-zero3w"
UBOOT_CONFIG[radxa-zero3w] = "radxa-zero-3-rk3566_defconfig"
UBOOT_CONFIG_BINARY[radxa-zero3w] = "u-boot-rockchip.bin"
UBOOT_CONFIG_IMAGE_FSTYPES[radxa-zero3w] = "ext4 fit"

UBOOT_SUFFIX ?= "bin"
PACKAGE_ARCH = "${MACHINE_ARCH}"

# --- Patch out the SWIG pylibfdt .py build ----------------------------------
# scripts/dtc/pylibfdt/libfdt_wrap.c was SWIG-generated against an older
# Python C API and fails to compile under the wrynose 6.0 toolchain:
#   error: too few arguments to function 'SWIG_Python_AppendOutput'
# Disable CONFIG_PYLIBFDT for our build. u-boot's dtc continues to ship
# libfdt directly (libfdt_internal.shipped), so the device-tree tooling
# works without the SWIG Python module.
do_configure:append:radxa-zero3w() {
    if [ -f ${B}/.config ]; then
        sed -i 's/^CONFIG_PYLIBFDT=.*/# CONFIG_PYLIBFDT is not set/' ${B}/.config
        sed -i 's/^CONFIG_LIBFDT_USE_PYLIBFDT=.*/# CONFIG_LIBFDT_USE_PYLIBFDT is not set/' ${B}/.config
    fi
}

# --- Rockchip multi-stage artefact staging ---------------------------------
RK = "${UNPACKDIR}/rkbin"

# Required by the rockchip make_fit_atf.sh pre-processor in SPL build:
# BL31 = arm-trusted-firmware (.elf), ROCKCHIP_TPL = DDR init (.bin).
# We grab the rk3568 bl31 (works as rk3566 family firmware) and the
# 1056 MHz DDR binary (radxa-zero3 pred spec).
do_compile:prepend:radxa-zero3w() {
    cp -a ${RK}/bin/rk35/rk3568_bl31_v1.44.elf              ${S}/
    cp -a ${RK}/bin/rk35/rk3566_ddr_1056MHz_v1.23.bin        ${S}/
    cp -a ${RK}/tools                                          ${S}/
}

do_deploy:append() {
    install -d ${DEPLOYDIR}
    # New-style Rockchip binaries (preferred by mainline tooling)
    install -m 755 ${B}/u-boot.itb          ${DEPLOYDIR}/u-boot.itb
    install -m 755 ${B}/u-boot-rockchip.bin ${DEPLOYDIR}/u-boot.bin
}

COMPATIBLE_MACHINE = "radxa-zero3w"
