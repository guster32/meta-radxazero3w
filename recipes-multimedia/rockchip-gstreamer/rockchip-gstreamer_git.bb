# GStreamer Rockchip Hardware-Accelerated Plugins
# Provides MPP video encode/decode plugins for GStreamer

SUMMARY = "GStreamer plugins for Rockchip hardware acceleration"
DESCRIPTION = "GStreamer 1.0 plugins using Rockchip MPP for hardware-accelerated \
video encoding, decoding, and RGA for color space conversion"
HOMEPAGE = "https://github.com/Meonardo/gst-rockchip"
SECTION = "multimedia"
LICENSE = "LGPL-2.1-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=4fbd65380cdd255951079008b364516c"

DEPENDS = " \
    gstreamer1.0 \
    gstreamer1.0-plugins-base \
    rockchip-mpp \
    rockchip-librga \
    libdrm \
"

SRCREV = "fa0d862a2a5135f0b5e19cdb19aac2355bad2dd3"
SRC_URI = "git://github.com/Meonardo/gst-rockchip.git;protocol=https;branch=main"

S = "${WORKDIR}/git"

inherit meson pkgconfig

EXTRA_OEMESON = " \
    -Ddefault_library=shared \
"

# GStreamer plugins install to gstreamer-1.0 directory
FILES:${PN} += " \
    ${libdir}/gstreamer-1.0/*.so \
"

FILES:${PN}-dev += " \
    ${libdir}/gstreamer-1.0/*.a \
    ${libdir}/gstreamer-1.0/pkgconfig \
"

# Runtime dependencies
RDEPENDS:${PN} += " \
    gstreamer1.0 \
    gstreamer1.0-plugins-base \
    rockchip-mpp \
    rockchip-librga \
"

# Skip QA checks for GStreamer plugins (they're loaded dynamically)
INSANE_SKIP:${PN} += "dev-so"

COMPATIBLE_MACHINE = "(rk3566|rk3568|rk3588)"
