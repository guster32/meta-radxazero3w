require recipes-bsp/u-boot/u-boot.inc
DESCRIPTION = "Radxa Zero3w boot loader"
SECTION = "bootloaders"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://Licenses/gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263"

PROVIDES += "virtual/bootloader u-boot"


FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}-2023.10:"

UBOOT_INITIAL_ENV = ""

SRC_URI = "git://github.com/radxa/u-boot.git;name=uboot;destsuffix=git/uboot;protocol=https;branch=rk3568-2023.10 \
	git://github.com/radxa/rkbin.git;name=rkbin;protocol=https;branch=develop-v2024.10;subdir=rkbin \
	git://github.com/ARM-software/arm-trusted-firmware.git;name=atf;protocol=https;nobranch=1;subdir=atf \
	file://enable-logging.atf;striplevel=1 \
	file://rk3328-efuse-init.atf;striplevel=1 \
	"
SRC_URI += "file://rockchip-scripts.sh"
SRC_URI += "file://kconfig.conf"

SRCREV_uboot = "cc60ff4058d8b84f762dd75190da2a8d5bf45c85"
SRCREV_rkbin = "a45caf5db84fddb3422142a77cf2b50336f11161"
SRCREV_atf = "a1be69e6c5db450f841f0edd9d734bf3cffb6621"
SRCREV_FORMAT = "uboot_rkbin_atf"


PR = "${PV}+git${SRCPV}"

DEPENDS += " python3-native python3-pyelftools-native gcc libgcc bc-native coreutils-native "
UBOOT_SUFFIX ?= "bin"

PACKAGE_ARCH = "${MACHINE_ARCH}"

S = "${WORKDIR}/git/uboot"
RK = "${WORKDIR}/rkbin"
ATF = "${WORKDIR}/atf"
B = "${S}"

inherit uboot-boot-scr

EXTRA_OEMAKE += ' CC="${TARGET_PREFIX}gcc --sysroot=${RECIPE_SYSROOT} -Wno-maybe-uninitialized -Wno-enum-int-mismatch" '

do_configure () {
	cp -a ${RK} ${S}
	cp -a ${ATF} ${S}
	cd ${S}

	###############################################################
	# Ensure python2 is available since SPL_FIT_GENERATOR need it
	###############################################################
	if [ ! -e "${RECIPE_SYSROOT_NATIVE}/usr/bin/python2" ]; then
  	ln -s ${RECIPE_SYSROOT_NATIVE}/usr/bin/python3-native/python3 ${RECIPE_SYSROOT_NATIVE}/usr/bin/python2
	fi
	oe_runmake ${UBOOT_MACHINE}
}

do_configure:append() {
    # Apply the fragment on top of the default configuration
    cp ${WORKDIR}/kconfig.conf ${B}/kconfig.conf
    cat ${B}/kconfig.conf >> ${B}/.config
    oe_runmake olddefconfig
}


do_patch () {
    cd ${ATF}
    for patch in ${WORKDIR}/enable-logging.atf ${WORKDIR}/rk3328-efuse-init.atf; do
        patch -p1 < $patch
    done
}

do_compile () {
	cd ${S}
	rm -f "tee.bin"
	export BL31="${RK}/bin/rk35/rk3568_bl31_v1.44.elf"
	export ROCKCHIP_TPL="${RK}/bin/rk35/rk3566_ddr_1056MHz_v1.23.bin"

	oe_runmake all

	###############################################################
	# Source rockchip scripts for yocto
	###############################################################
	. ${WORKDIR}/rockchip-scripts.sh

	###############################################################
	# Creates the idblock.bin
	###############################################################
	./tools/mkimage -n rk3568 -T rksd -d ${ROCKCHIP_TPL}:spl/u-boot-spl.bin idblock.bin

	###############################################################
	# Generates u-boot.its file (Image Tree Source) and u-boot.itb (Image Tree Binary)
    #./make.sh itb rkbin/RKTRUST/RK3568TRUST.ini
	###############################################################
	export INI_TRUST="${S}/rkbin/RKTRUST/RK3568TRUST.ini"
	export INI_LOADER="${S}/rkbin/RKBOOT/RK3566MINIALL.ini"
	export RKBIN_TOOLS="${S}/rkbin/tools"
	export ARM64_TRUSTZONE=""
	export RKBIN=""
	export PLAT_TYPE=""
	export FIT_DIR="fit"
	export ITB_UBOOT="${FIT_DIR}/uboot.itb"
	export ITS_UBOOT="u-boot.its"
	export IMG_UBOOT="u-boot.img"
	export ARG_VER_UBOOT="0"
	###############################################################
	# Read in some variables
	###############################################################
	prepare

	###############################################################
	# create Itb image and pack loader No siging.
	# see function fit_gen_uboot_itb() on fit-core.sh
	###############################################################
	# offs
	if grep -q '^CONFIG_FIT_ENABLE_RSA4096_SUPPORT=y' .config ; then
		export OFFS_DATA="0x1200"
	else
		export OFFS_DATA="0x1000"
	fi

    #pack_uboot_itb_image

	#mkdir -p ${FIT_DIR}

	#./tools/mkimage -f ${ITS_UBOOT} -E -p ${OFFS_DATA} ${ITB_UBOOT} -v ${ARG_VER_UBOOT}

	pack_loader_image

    ###############################################################

	###############################################################
	# Using previous files generate uboot_img
	###############################################################
    #fit_gen_uboot_img
	###############################################################

	####
	# sudo dd if=idblock.bin of=<DEVICE/NODE/OF/YOUR/STORAGE> conv=fsync seek=64
  # sudo dd if=uboot.img of=<DEVICE/NODE/OF/YOUR/STORAGE> conv=fsync seek=2048
}

do_deploy:append() {
	install -d ${DEPLOYDIR}
	install -m 755 ${B}/idblock.bin ${DEPLOYDIR}/idblock.bin
	install -m 755 ${B}/u-boot.img ${DEPLOYDIR}/uboot.img
	install -m 755 ${WORKDIR}/${UBOOT_ENV_BINARY} ${DEPLOYDIR}/${UBOOT_ENV_BINARY}
}

COMPATIBLE_MACHINE = "radxa-zero3w"
