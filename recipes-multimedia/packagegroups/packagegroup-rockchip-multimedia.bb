# Package group for Rockchip hardware multimedia acceleration

SUMMARY = "Rockchip multimedia hardware acceleration packages"
DESCRIPTION = "Package group containing Rockchip MPP, RGA and related \
multimedia acceleration libraries for video encode/decode and 2D graphics"

inherit packagegroup

# Note that it may be possible that we could use rockchip-drm instead of linux-rockchip
RDEPENDS:${PN} = " \
    rockchip-mpp \
    rockchip-librga \
"

# Optional: Add FFmpeg with MPP support if available
RRECOMMENDS:${PN} = " \
    ffmpeg \
    gstreamer1.0 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
"
