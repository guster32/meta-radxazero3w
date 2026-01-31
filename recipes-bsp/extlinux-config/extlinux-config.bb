SUMMARY = "extlinux.conf configuration for Arcadia with DTBO support"
DESCRIPTION = "Provides extlinux.conf with multi-boot menu for DTBO selection (IMX708, RK628)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://extlinux.conf"

S = "${WORKDIR}"

PV = "1.0.0"
PR = "r3"

inherit deploy

do_install() {
    install -d ${D}/boot/extlinux
    install -m 0644 ${WORKDIR}/extlinux.conf ${D}/boot/extlinux/
}

do_deploy() {
    install -d ${DEPLOYDIR}
    install -m 0644 ${WORKDIR}/extlinux.conf ${DEPLOYDIR}/extlinux.conf
}
addtask deploy after do_install before do_build

FILES:${PN} = "/boot/extlinux/extlinux.conf"