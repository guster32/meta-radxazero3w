require recipes-bsp/u-boot/u-boot.inc
DESCRIPTION = "Odroid m1s boot loader supported by the hardkernel product"
SECTION = "bootloaders"
LICENSE = "GPLv2"

PROVIDES += "virtual/bootloader u-boot"

LIC_FILES_CHKSUM = "file://Licenses/gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}-2023.10:"

SRC_URI = "git://github.com/radxa/u-boot.git;name=uboot;destsuffix=git/uboot;protocol=https;branch=rk3568-2023.10 \
	git://github.com/radxa/rkbin.git;name=rkbin;destsuffix=git/rkbin;protocol=https;branch=develop-v2024.10 \
	git://github.com/ARM-software/arm-trusted-firmware.git;name=atf;destsuffix=git/atf;protocol=https;nobranch=1 \
	file://enable-logging.atf;apply=yes;striplevel=1;patchdir=git/atf \
	file://rk3328-efuse-init.atf;apply=yes;striplevel=1;patchdir=git/atf \
	"
SRCREV_uboot = "cc60ff4058d8b84f762dd75190da2a8d5bf45c85"
SRCREV_rkbin = "a45caf5db84fddb3422142a77cf2b50336f11161"
SRCREV_atf = "a1be69e6c5db450f841f0edd9d734bf3cffb6621"
SRCREV_FORMAT = "uboot_rkbin_atf"


PR = "${PV}+git${SRCPV}"

DEPENDS = " python3-native gcc libgcc bc-native coreutils-native "
UBOOT_SUFFIX ?= "bin"

PACKAGE_ARCH = "${MACHINE_ARCH}"

S = "${WORKDIR}/git/uboot"
RK = "${WORKDIR}/git/rkbin"
B = "${S}"


COMPATIBLE_MACHINE = "radxa-zero3w"
