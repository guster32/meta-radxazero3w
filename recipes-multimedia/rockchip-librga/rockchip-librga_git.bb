# Rockchip RGA (Raster Graphic Acceleration) Library
# Prebuilt binaries from Rockchip

SUMMARY = "Rockchip RGA userspace library (prebuilt)"
DESCRIPTION = "Prebuilt userspace library for Rockchip RGA (Raster Graphic Acceleration) \
providing 2D graphics operations like scaling, rotation, color conversion"
HOMEPAGE = "https://github.com/airockchip/librga"
SECTION = "libs"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://COPYING;md5=89aea4e17d99a7cacdbeed46a0096b10"

SRCREV = "6664094b919d069ae7caf90833ed4d5cc2729585"
SRC_URI = "git://github.com/airockchip/librga.git;protocol=https;branch=main"

S = "${WORKDIR}/git"

DEPENDS = "libdrm"

# This is a prebuilt library package
inherit bin_package

# Disable all compilation
do_configure[noexec] = "1"
do_compile[noexec] = "1"

# Install prebuilt libraries and headers
do_install() {
    # Determine architecture directory
    if [ "${TARGET_ARCH}" = "aarch64" ]; then
        ARCH_DIR="gcc-aarch64"
    elif [ "${TARGET_ARCH}" = "arm" ]; then
        ARCH_DIR="gcc-armhf"
    else
        bbfatal "Unsupported architecture: ${TARGET_ARCH}"
    fi
    
    # Install prebuilt libraries
    install -d ${D}${libdir}
    if [ -f ${S}/libs/Linux/${ARCH_DIR}/librga.so ]; then
        install -m 0755 ${S}/libs/Linux/${ARCH_DIR}/librga.so ${D}${libdir}/
        install -m 0755 ${S}/libs/Linux/${ARCH_DIR}/librga.a ${D}${libdir}/
    else
        bbfatal "Failed to find prebuilt libraries in ${S}/libs/Linux/${ARCH_DIR}/"
    fi
    
    # Install headers
    install -d ${D}${includedir}/rga
    install -m 0644 ${S}/include/*.h ${D}${includedir}/rga/
    install -m 0644 ${S}/include/*.hpp ${D}${includedir}/rga/ || true
    
    # Install pkg-config file if it exists
    if [ -f ${S}/librga.pc ]; then
        install -d ${D}${libdir}/pkgconfig
        install -m 0644 ${S}/librga.pc ${D}${libdir}/pkgconfig/
    fi
}

# Package prebuilt libraries
FILES:${PN} = " \
    ${libdir}/librga.so* \
"

FILES:${PN}-dev = " \
    ${includedir}/rga \
    ${libdir}/pkgconfig \
"

# Skip QA checks for prebuilt binaries
INSANE_SKIP:${PN} += "dev-so already-stripped ldflags"
INSANE_SKIP:${PN}-dev += "dev-elf"

