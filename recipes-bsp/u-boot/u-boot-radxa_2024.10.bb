# Modern u-boot for the Radxa Zero3W (RK3566). Mainline u-boot 2026.01
# already includes a radxa-zero-3-rk3566 defconfig (this recipe just wires it
# up explicitly), plus the Radxa rkbin fork for DDR init + ATF.
#
# Migrated to the wrynose 6.0 U-Boot configuration flow:
#   - UBOOT_CONFIG[name] flag syntax
#   - UBOOT_CONFIG_BINARY[name]   -> primary boot image
#   - UBOOT_CONFIG_IMAGE_FSTYPES  -> deploy artifact layout
#   - UBOOT_SRC instead of S = ${WORKDIR}/git/uboot
#   - No destsuffix=git/uboot (wrynose drops default git/ prefix)

require recipes-bsp/u-boot/u-boot-common.inc
require recipes-bsp/u-boot/u-boot.inc

SUMMARY = "U-Boot bootloader for Radxa Zero 3W (Rockchip RK3566)"
DESCRIPTION = "Mainline U-Boot 2026.01 with radxa-zero-3-rk3566_defconfig; \
the rkbin fork supplies BL31 + DDR binaries for rockchip's multi-stage \
bootloader (idbloader.img + u-boot.itb)."

SRC_URI = "git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master;tag=v${PV} \
           git://github.com/radxa/rkbin.git;name=rkbin;destsuffix=rkbin;protocol=https;branch=develop-v2024.10"

SRCREV = "127a42c7257a6ffbbd1575ed1cbaa8f5408a44b3"

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

# --- Rockchip multi-stage artefacts (build + deploy) -------------------------
RK = "${WORKDIR}/rkbin"

do_compile:prepend() {
    cd ${S}
    export BL31="${RK}/bin/rk35/rk3568_bl31_v1.44.elf"
    export ROCKCHIP_TPL="${RK}/bin/rk35/rk3566_ddr_1056MHz_v1.23.bin"
    rm -f u-boot.itb idbloader*.img

    if [ ! -f "${BL31}" ]; then
        bbfatal "ATF file ${BL31} not found"
    fi
    if [ ! -f "${ROCKCHIP_TPL}" ]; then
        bbfatal "DDR file ${ROCKCHIP_TPL} not found"
    fi
}

do_deploy:append() {
    install -d ${DEPLOYDIR}
    install -m 755 ${B}/idbloader.img ${DEPLOYDIR}/idbloader.img
    install -m 755 ${B}/u-boot.itb    ${DEPLOYDIR}/u-boot.itb
}

COMPATIBLE_MACHINE = "radxa-zero3w"
