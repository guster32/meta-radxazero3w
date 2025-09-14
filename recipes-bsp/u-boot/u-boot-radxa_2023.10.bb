require recipes-bsp/u-boot/u-boot.inc

DESCRIPTION = "Radxa Zero3W boot loader (modern Rockchip flow)"
SECTION = "bootloaders"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://Licenses/gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263"

PROVIDES += "virtual/bootloader u-boot"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}-2023.10:"

UBOOT_INITIAL_ENV = ""

SRC_URI = " \
    git://source.denx.de/u-boot/u-boot.git;name=uboot;destsuffix=git/uboot;protocol=https;branch=master \
    git://github.com/radxa/rkbin.git;name=rkbin;protocol=https;branch=develop-v2024.10;subdir=rkbin \
    file://kconfig.conf \
"

SRCREV_uboot = "d892702080d45468b4b5c1cbd3358705d182d4ef"
SRCREV_rkbin = "a45caf5db84fddb3422142a77cf2b50336f11161"
SRCREV_FORMAT = "uboot_rkbin"

PR = "${PV}+git${SRCPV}"

DEPENDS += "python3-native python3-pyelftools-native gcc libgcc bc-native coreutils-native"
UBOOT_SUFFIX ?= "bin"

PACKAGE_ARCH = "${MACHINE_ARCH}"

S = "${WORKDIR}/git/uboot"
RK = "${WORKDIR}/rkbin"
B = "${S}"

inherit uboot-boot-scr

EXTRA_OEMAKE += ' CC="${TARGET_PREFIX}gcc --sysroot=${RECIPE_SYSROOT} -Wno-maybe-uninitialized -Wno-enum-int-mismatch" '

do_configure () {
    cp ${WORKDIR}/kconfig.conf ${S}/kconfig.conf
    cd ${S}
    cat ${S}/kconfig.conf >> ${S}/configs/${UBOOT_MACHINE}
    oe_runmake ${UBOOT_MACHINE}
}

do_compile () {
    cd ${S}
    export BL31="${RK}/bin/rk35/rk3568_bl31_v1.44.elf"
    export ROCKCHIP_TPL="${RK}/bin/rk35/rk3566_ddr_1056MHz_v1.23.bin"

    rm -f u-boot.itb idbloader*.img

    [ -f "${BL31}" ] || bbfatal "ATF file ${BL31} not found"
    [ -f "${ROCKCHIP_TPL}" ] || bbfatal "DDR file ${ROCKCHIP_TPL} not found"

    # Build SPL + U-Boot proper
    oe_runmake CROSS_COMPILE=${TARGET_PREFIX} \
        BL31=${BL31} ROCKCHIP_TPL=${ROCKCHIP_TPL} all

    # --- Stage 1: idbloader-sd.img ---
    # This is SPL (u-boot-spl.bin) + TPL (DDR init), wrapped with an rksd header.
    # It is written at 32 KB offset on SD/eMMC so BootROM can find it.
    # Build idbloader (TPL + SPL with DTB)
    ${RK}/tools/mkimage -n rk3568 -T rksd -d ${ROCKCHIP_TPL} idbloader-sd.img
    cat spl/u-boot-spl-dtb.bin >> idbloader-sd.img

    # --- Stage 2: u-boot.itb ---
    # FIT image containing U-Boot proper + BL31 + DTBs.
    # SPL loads this once DRAM is initialized.
    [ -f u-boot.itb ] || cp u-boot.bin u-boot.itb
}

do_deploy:append() {
    install -d ${DEPLOYDIR}

    # Stage 1: SPL+TPL for SD/eMMC boot
    install -m 644 ${B}/idbloader-sd.img ${DEPLOYDIR}/idbloader-sd.img

    # Stage 2: U-Boot proper FIT image
    install -m 644 ${B}/u-boot.itb ${DEPLOYDIR}/u-boot.itb

    # Optional: environment binary if provided
    if [ -n "${UBOOT_ENV_BINARY}" ] && [ -f ${WORKDIR}/${UBOOT_ENV_BINARY} ]; then
        install -m 644 ${WORKDIR}/${UBOOT_ENV_BINARY} ${DEPLOYDIR}/${UBOOT_ENV_BINARY}
    fi
}

### USB LOAD ###
#sudo ./upgrade_tool db rk356x_spl_loader_ddr1056_v1.10.111.bin   # Rockchip miniloader
#sudo ./upgrade_tool di -b tmp/deploy/images/radxa-zero3w/u-boot.itb

COMPATIBLE_MACHINE = "radxa-zero3w"
