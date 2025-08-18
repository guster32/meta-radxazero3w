require recipes-bsp/u-boot/u-boot.inc
DESCRIPTION = "Radxa Zero3w boot loader"
SECTION = "bootloaders"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://Licenses/gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263"

PROVIDES += "virtual/bootloader u-boot"


FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}-2023.10:"

UBOOT_INITIAL_ENV = ""

SRC_URI = "git://source.denx.de/u-boot/u-boot.git;name=uboot;destsuffix=git/uboot;protocol=https;branch=master \
	git://github.com/radxa/rkbin.git;name=rkbin;protocol=https;branch=develop-v2024.10;subdir=rkbin \
	"
SRC_URI += "file://kconfig.conf"

SRCREV_uboot = "d892702080d45468b4b5c1cbd3358705d182d4ef"
SRCREV_rkbin = "a45caf5db84fddb3422142a77cf2b50336f11161"
SRCREV_FORMAT = "uboot_rkbin"


PR = "${PV}+git${SRCPV}"

DEPENDS += " python3-native python3-pyelftools-native gcc libgcc bc-native coreutils-native "
UBOOT_SUFFIX ?= "bin"

PACKAGE_ARCH = "${MACHINE_ARCH}"

S = "${WORKDIR}/git/uboot"
RK = "${WORKDIR}/rkbin"
B = "${S}"

inherit uboot-boot-scr

EXTRA_OEMAKE += ' CC="${TARGET_PREFIX}gcc --sysroot=${RECIPE_SYSROOT} -Wno-maybe-uninitialized -Wno-enum-int-mismatch" '

do_configure () {
	cp -a ${RK} ${S}
	cp ${WORKDIR}/kconfig.conf ${S}/kconfig.conf
	cd ${S}

	cat ${S}/kconfig.conf >> ${S}/configs/${UBOOT_MACHINE}
	oe_runmake ${UBOOT_MACHINE}
}

do_compile () {
	cd ${S}
	# Use pre-built ATF from rkbin - try alternative version for better compatibility
	export BL31="${RK}/bin/rk35/rk3568_bl31_v1.43.elf"
	export ROCKCHIP_TPL="${RK}/bin/rk35/rk3566_ddr_1056MHz_v1.18.bin"

	# Fallback to v1.44 if v1.43 doesn't exist
	if [ ! -f "${BL31}" ]; then
		export BL31="${RK}/bin/rk35/rk3568_bl31_v1.44.elf"
	fi

	# Clean any previous build artifacts that might cause hash issues
	rm -f u-boot.itb u-boot-rockchip.bin

	# Verify ATF file exists and is readable
	if [ ! -f "${BL31}" ]; then
		bbfatal "ATF file ${BL31} not found"
	fi

	# List available ATF files for debugging
	echo "Available ATF files:"
	ls -la ${RK}/bin/rk35/rk3568_bl31_*.elf || true

	oe_runmake all
}

do_deploy:append() {
	install -d ${DEPLOYDIR}
	install -m 755 ${B}/u-boot-rockchip.bin ${DEPLOYDIR}/u-boot-rockchip.bin
	install -m 755 ${B}/u-boot.img ${DEPLOYDIR}/uboot.img
	install -m 755 ${WORKDIR}/${UBOOT_ENV_BINARY} ${DEPLOYDIR}/${UBOOT_ENV_BINARY}
}

COMPATIBLE_MACHINE = "radxa-zero3w"
