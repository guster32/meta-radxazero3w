# Rockchip Media Process Platform (MPP)
# Hardware-accelerated video encoding/decoding library for RK3566

SUMMARY = "Rockchip Media Process Platform (MPP)"
DESCRIPTION = "Rockchip MPP provides hardware-accelerated video encode/decode \
for H.264, H.265/HEVC, VP8, VP9, JPEG and more on Rockchip SoCs"
HOMEPAGE = "https://github.com/rockchip-linux/mpp"
SECTION = "multimedia"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSES/Apache-2.0;md5=7f43e699e0a26fae98c2938092f008d2"

SRCREV = "37145900a208d5ca6eb2adbb0f9bab5d52f38270"
SRC_URI = "git://github.com/HermanChen/mpp.git;protocol=https;branch=develop"


DEPENDS = "libdrm"

inherit cmake pkgconfig

EXTRA_OECMAKE = " \
    -DRKPLATFORM=ON \
    -DHAVE_DRM=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TEST=OFF \
"

# MPP uses non-standard install paths
FILES:${PN} += " \
    ${libdir}/librockchip_mpp.so* \
    ${libdir}/librockchip_vpu.so* \
    ${libdir}/libmpp_ext.so* \
"

FILES:${PN}-dev += " \
    ${includedir}/rockchip \
"

# Ensure proper RPATH for the libraries
# libmpp_ext.so is a plugin library, not a development symlink
INSANE_SKIP:${PN} += "dev-so already-stripped ldflags"
INSANE_SKIP:${PN}-dev += "dev-elf"

do_install:append() {
    # Create symlinks for compatibility
    cd ${D}${libdir}
    if [ -f librockchip_mpp.so.0 ]; then
        ln -sf librockchip_mpp.so.0 librockchip_mpp.so
    fi
    if [ -f librockchip_vpu.so.0 ]; then
        ln -sf librockchip_vpu.so.0 librockchip_vpu.so
    fi
}

