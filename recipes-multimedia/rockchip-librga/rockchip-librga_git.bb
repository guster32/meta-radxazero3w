# Rockchip RGA (Raster Graphic Acceleration) Library
# 2D graphics acceleration library for Rockchip SoCs

SUMMARY = "Rockchip RGA userspace library"
DESCRIPTION = "Userspace library for Rockchip RGA (Raster Graphic Acceleration) \
providing 2D graphics operations like scaling, rotation, color conversion"
HOMEPAGE = "https://github.com/airockchip/librga"
SECTION = "libs"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://COPYING;md5=89aea4e17d99a7cacdbeed46a0096b10"

SRCREV = "d3c5e5b7510e46c8c85e37695aef60cfef9b11c6"
SRC_URI = "git://github.com/airockchip/librga.git;protocol=https;branch=main"

S = "${WORKDIR}/git"

DEPENDS = "libdrm"

inherit meson pkgconfig

EXTRA_OEMESON = " \
    -Dcpp_rtti=true \
    -Dlibdrm=true \
"

# RGA library files
FILES:${PN} += " \
    ${libdir}/librga.so* \
"

FILES:${PN}-dev += " \
    ${includedir}/rga \
"

INSANE_SKIP:${PN} += "dev-so already-stripped"

