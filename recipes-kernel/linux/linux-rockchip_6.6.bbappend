# Radxa Zero 3W support for Rockchip vendor kernel
# 
# Architecture:
#  - Base DTS: MIPI CSI pipeline (board infrastructure)
#  - Overlay: IMX708 sensor (camera-specific)

FILESEXTRAPATHS:prepend := "${THISDIR}/linux-rockchip-6.6:"

SRC_URI:append:radxa-zero3w = " \
    file://rk3566-radxa-zero-3.dtsi \
    file://rk3566-radxa-zero-3w.dts \
    file://rk3566-radxa-zero-3w-imx708.dtso \
    file://radxa-zero3w.cfg \
    file://wifi-bt.cfg \
    file://rk628-hdmi-mipi.cfg \
    file://led-triggers.cfg \
    file://psplash-fb.cfg \
    file://camera-mipi-csi.cfg \
    file://gpu-panfrost.cfg \
    file://0001-arm64-dts-rockchip-Add-Radxa-Zero-3W-support.patch \
    file://0002-media-i2c-Add-Sony-IMX708-sensor-driver.patch \
"

# Base device tree + overlay
KERNEL_DEVICETREE:radxa-zero3w = " \
    rockchip/rk3566-radxa-zero-3w.dtb \
    rockchip/rk3566-radxa-zero-3w-imx708.dtbo \
"

# Enable overlay support (symbols in base DTB for overlays)
KERNEL_DTC_FLAGS += "-@"

# Suppress buildpaths QA warning for debug source package
INSANE_SKIP:${PN}-src = "buildpaths"

do_configure:prepend() {
    # Copy common base dtsi
    if [ -f ${WORKDIR}/rk3566-radxa-zero-3.dtsi ]; then
        cp ${WORKDIR}/rk3566-radxa-zero-3.dtsi ${S}/arch/arm64/boot/dts/rockchip/
    fi
    
    # Copy board-specific device tree
    if [ -f ${WORKDIR}/rk3566-radxa-zero-3w.dts ]; then
        cp ${WORKDIR}/rk3566-radxa-zero-3w.dts ${S}/arch/arm64/boot/dts/rockchip/
    fi
    
    # Copy IMX708 camera overlay
    if [ -f ${WORKDIR}/rk3566-radxa-zero-3w-imx708.dtso ]; then
        cp ${WORKDIR}/rk3566-radxa-zero-3w-imx708.dtso ${S}/arch/arm64/boot/dts/rockchip/
    fi
}

COMPATIBLE_MACHINE:radxa-zero3w = "radxa-zero3w"
