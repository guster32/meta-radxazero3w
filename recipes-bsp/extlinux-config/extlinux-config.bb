SUMMARY = "Initial extlinux.conf configuration for Arcadia"
DESCRIPTION = "Provides initial extlinux.conf that gets updated by kernel hooks"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://extlinux.conf"

S = "${WORKDIR}"

PV = "1.0.0"
PR = "r1"

inherit deploy

do_deploy() {
    install -d ${DEPLOYDIR}/boot/extlinux
    install -m 0644 ${WORKDIR}/extlinux.conf ${DEPLOYDIR}/boot/extlinux/extlinux.conf
}
