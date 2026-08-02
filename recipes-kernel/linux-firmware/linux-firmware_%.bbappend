FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# The AIC8800D80 firmware is specific to the Radxa Zero 3W. Keep the blobs
# and split package in this BSP layer rather than exposing them to all Arcadia
# machines.
SRC_URI:append = " \
    file://aic_userconfig_8800d80.txt \
    file://fmacfw_8800d80_u02.bin \
    file://fmacfwbt_8800d80_u02.bin \
    file://fw_adid_8800d80_u02.bin \
    file://fw_patch_8800d80_u02.bin \
    file://fw_patch_table_8800d80_u02.bin \
    file://lmacfw_rf_8800d80_u02.bin \
"

do_install:append() {
    install -d ${D}${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80
    install -m 0644 ${UNPACKDIR}/aic_userconfig_8800d80.txt ${D}${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/
    install -m 0644 ${UNPACKDIR}/fmacfw_8800d80_u02.bin ${D}${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/
    install -m 0644 ${UNPACKDIR}/fmacfwbt_8800d80_u02.bin ${D}${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/
    install -m 0644 ${UNPACKDIR}/fw_adid_8800d80_u02.bin ${D}${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/
    install -m 0644 ${UNPACKDIR}/fw_patch_8800d80_u02.bin ${D}${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/
    install -m 0644 ${UNPACKDIR}/fw_patch_table_8800d80_u02.bin ${D}${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/
    install -m 0644 ${UNPACKDIR}/lmacfw_rf_8800d80_u02.bin ${D}${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/
}

PACKAGES:prepend = "${PN}-aic8800d8 "

FILES:${PN}-aic8800d8 = " \
    ${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/aic_userconfig_8800d80.txt \
    ${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/fmacfw_8800d80_u02.bin \
    ${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/fmacfwbt_8800d80_u02.bin \
    ${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/fw_adid_8800d80_u02.bin \
    ${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/fw_patch_8800d80_u02.bin \
    ${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/fw_patch_table_8800d80_u02.bin \
    ${nonarch_base_libdir}/firmware/aic8800_fw/SDIO/aic8800D80/lmacfw_rf_8800d80_u02.bin \
"

# AIC8800D80 is now Airoha Technology (subsumed MediaTek's AIC subsidiary),
# so the corresponding upstream-registered firmware license applies.
LICENSE:${PN}-aic8800d8 = "Firmware-airoha"
RDEPENDS:${PN}-aic8800d8 += "${PN}-airoha-license"
