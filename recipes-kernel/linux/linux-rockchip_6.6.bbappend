# Radxa Zero 3W/3E support for Rockchip vendor kernel
# 
# Architecture:
#  - Base DTB: rk3566-radxa-zero-3.dtb (generic, common hardware)
#  - Board overlays: Enable WiFi (3W) or Ethernet (3E)
#  - Camera overlay: Enable IMX708 camera sensor

FILESEXTRAPATHS:prepend := "${THISDIR}/linux-rockchip-6.6:"

SRC_URI:append:radxa-zero3w = " \
    file://rk3566-radxa-zero-3.dtsi \
    file://rk3566-radxa-zero-3.dts \
    file://rk3566-radxa-zero-3w-board.dtso \
    file://rk3566-radxa-zero-3e-board.dtso \
    file://rk3566-radxa-zero-3-imx708.dtso \
    file://radxa-zero3w.cfg \
    file://wifi-bt.cfg \
    file://led-triggers.cfg \
    file://psplash-fb.cfg \
    file://camera-mipi-csi.cfg \
    file://gpu-panfrost.cfg \
    file://0001-arm64-dts-rockchip-Add-Radxa-Zero-3W-support.patch \
    file://0002-media-i2c-Add-Sony-IMX708-sensor-driver.patch \
    file://0003-Adds-support-for-AIC8800D80.patch \
"

# Generic base + board-specific + camera overlays
KERNEL_DEVICETREE:radxa-zero3w = " \
    rockchip/rk3566-radxa-zero-3.dtb \
    rockchip/rk3566-radxa-zero-3w-board.dtbo \
    rockchip/rk3566-radxa-zero-3e-board.dtbo \
    rockchip/rk3566-radxa-zero-3-imx708.dtbo \
"

# Enable overlay support (symbols in base DTB for overlays)
KERNEL_DTC_FLAGS:append = " -@"
DTC_FLAGS:append = " -@"

# Suppress buildpaths QA warning for debug source package
INSANE_SKIP:${PN}-src = "buildpaths"

do_configure:prepend() {
    # Copy common base dtsi
    if [ -f ${WORKDIR}/rk3566-radxa-zero-3.dtsi ]; then
        cp ${WORKDIR}/rk3566-radxa-zero-3.dtsi ${S}/arch/arm64/boot/dts/rockchip/
    fi
    
    # Copy generic base device tree
    if [ -f ${WORKDIR}/rk3566-radxa-zero-3.dts ]; then
        cp ${WORKDIR}/rk3566-radxa-zero-3.dts ${S}/arch/arm64/boot/dts/rockchip/
    fi
    
    # Copy board-specific overlays
    if [ -f ${WORKDIR}/rk3566-radxa-zero-3w-board.dtso ]; then
        cp ${WORKDIR}/rk3566-radxa-zero-3w-board.dtso ${S}/arch/arm64/boot/dts/rockchip/
    fi
    if [ -f ${WORKDIR}/rk3566-radxa-zero-3e-board.dtso ]; then
        cp ${WORKDIR}/rk3566-radxa-zero-3e-board.dtso ${S}/arch/arm64/boot/dts/rockchip/
    fi
    
    # Copy camera overlay
    if [ -f ${WORKDIR}/rk3566-radxa-zero-3-imx708.dtso ]; then
        cp ${WORKDIR}/rk3566-radxa-zero-3-imx708.dtso ${S}/arch/arm64/boot/dts/rockchip/
    fi
}

COMPATIBLE_MACHINE:radxa-zero3w = "radxa-zero3w"
