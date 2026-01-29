# GStreamer Rockchip Plugins Guide

Complete guide for using hardware-accelerated GStreamer plugins on Radxa Zero 3W (RK3566).

## Overview

The **gstreamer1.0-rockchip** package provides GStreamer plugins that leverage Rockchip MPP and RGA for hardware acceleration:

### Available Plugins

| Plugin | Type | Description | Formats |
|--------|------|-------------|---------|
| **mppvideodec** | Decoder | Hardware video decoder | H.264, H.265, VP8, VP9 |
| **mppvideoenc** | Encoder | Hardware video encoder | H.264, H.265 |
| **mppjpegdec** | Decoder | Hardware JPEG decoder | JPEG/MJPEG |
| **rkximagesink** | Sink | Zero-copy video sink | RGB, NV12, I420 |
| **rgaconvert** | Filter | RGA color space converter | Various formats |

## Installation

### Add to Your Image

The plugins are included in the multimedia packagegroup:

```bitbake
IMAGE_INSTALL:append = " packagegroup-rockchip-multimedia"
```

This installs:
- ✅ GStreamer 1.0 core
- ✅ GStreamer plugins-base
- ✅ Rockchip MPP library
- ✅ Rockchip RGA library
- ✅ **Rockchip GStreamer plugins**

### Build

```bash
bitbake gstreamer1.0-rockchip
# Or build the complete packagegroup
bitbake packagegroup-rockchip-multimedia
```

## Verification

After booting your image:

```bash
# List all GStreamer plugins
gst-inspect-1.0 | grep -i rockchip
gst-inspect-1.0 | grep mpp

# Expected output:
# rockchip: mppvideodec: Rockchip MPP Video Decoder
# rockchip: mppvideoenc: Rockchip MPP Video Encoder
# rockchip: mppjpegdec: Rockchip MPP JPEG Decoder
# rockchip: rkximagesink: Rockchip X11 Image Sink
# rockchip: rgaconvert: Rockchip RGA Video Converter

# Inspect specific plugin details
gst-inspect-1.0 mppvideodec
gst-inspect-1.0 mppvideoenc
```

## Usage Examples

### 1. Hardware Video Playback

#### H.264 Playback
```bash
# MP4 file playback
gst-launch-1.0 filesrc location=video.mp4 ! \
    qtdemux ! h264parse ! mppvideodec ! \
    videoconvert ! autovideosink

# With framebuffer output
gst-launch-1.0 filesrc location=video.mp4 ! \
    qtdemux ! h264parse ! mppvideodec ! \
    fbdevsink

# With Rockchip X image sink (zero-copy)
gst-launch-1.0 filesrc location=video.mp4 ! \
    qtdemux ! h264parse ! mppvideodec ! \
    rkximagesink
```

#### H.265/HEVC Playback
```bash
gst-launch-1.0 filesrc location=video_h265.mp4 ! \
    qtdemux ! h265parse ! mppvideodec ! \
    videoconvert ! autovideosink
```

#### VP8/VP9 Playback
```bash
# WebM with VP8
gst-launch-1.0 filesrc location=video.webm ! \
    matroskademux ! vp8parse ! mppvideodec ! \
    videoconvert ! autovideosink

# WebM with VP9
gst-launch-1.0 filesrc location=video_vp9.webm ! \
    matroskademux ! vp9parse ! mppvideodec ! \
    videoconvert ! autovideosink
```

### 2. Hardware Video Encoding

#### H.264 Encoding
```bash
# Encode test pattern
gst-launch-1.0 videotestsrc num-buffers=300 ! \
    video/x-raw,width=1280,height=720,framerate=30/1 ! \
    mppvideoenc ! h264parse ! \
    mp4mux ! filesink location=output_h264.mp4

# Encode from camera (if available)
gst-launch-1.0 v4l2src device=/dev/video0 ! \
    video/x-raw,width=1920,height=1080 ! \
    mppvideoenc bitrate=4000 ! h264parse ! \
    mp4mux ! filesink location=camera_h264.mp4
```

#### H.265/HEVC Encoding
```bash
gst-launch-1.0 videotestsrc num-buffers=300 ! \
    video/x-raw,width=1920,height=1080,framerate=30/1 ! \
    mppvideoenc codec=hevc bitrate=6000 ! h265parse ! \
    mp4mux ! filesink location=output_h265.mp4
```

### 3. Transcoding (Decode + Encode)

```bash
# H.264 to H.265 transcode
gst-launch-1.0 filesrc location=input.mp4 ! \
    qtdemux ! h264parse ! mppvideodec ! \
    video/x-raw ! mppvideoenc codec=hevc bitrate=4000 ! \
    h265parse ! mp4mux ! filesink location=output_h265.mp4

# Change resolution during transcode
gst-launch-1.0 filesrc location=input_1080p.mp4 ! \
    qtdemux ! h264parse ! mppvideodec ! \
    videoscale ! video/x-raw,width=1280,height=720 ! \
    mppvideoenc bitrate=2000 ! h264parse ! \
    mp4mux ! filesink location=output_720p.mp4
```

### 4. JPEG Hardware Decode

```bash
# Decode JPEG files
gst-launch-1.0 filesrc location=image.jpg ! \
    mppjpegdec ! videoconvert ! imagefreeze ! \
    autovideosink

# MJPEG video stream decode
gst-launch-1.0 filesrc location=mjpeg_video.avi ! \
    avidemux ! mppjpegdec ! videoconvert ! \
    autovideosink
```

### 5. Streaming

#### RTSP Streaming
```bash
# Encode and stream over RTSP (requires gst-rtsp-server)
gst-launch-1.0 v4l2src ! \
    video/x-raw,width=1280,height=720,framerate=30/1 ! \
    mppvideoenc bitrate=3000 ! h264parse ! \
    rtph264pay ! udpsink host=192.168.1.100 port=5000

# Receive RTSP stream with hardware decode
gst-launch-1.0 rtspsrc location=rtsp://192.168.1.100:8554/stream ! \
    rtph264depay ! h264parse ! mppvideodec ! \
    videoconvert ! autovideosink
```

#### UDP Streaming
```bash
# Send
gst-launch-1.0 videotestsrc ! \
    mppvideoenc bitrate=2000 ! h264parse ! \
    rtph264pay ! udpsink host=192.168.1.100 port=5000

# Receive
gst-launch-1.0 udpsrc port=5000 caps="application/x-rtp" ! \
    rtph264depay ! h264parse ! mppvideodec ! \
    autovideosink
```

### 6. Advanced Pipelines

#### Multi-Stream Decode
```bash
# Decode two streams simultaneously (RK3566 can handle multiple sessions)
gst-launch-1.0 \
    filesrc location=stream1.mp4 ! qtdemux ! h264parse ! mppvideodec ! \
        videoscale ! video/x-raw,width=640,height=360 ! \
        videobox left=-10 top=-10 ! videomixer.sink_0 \
    filesrc location=stream2.mp4 ! qtdemux ! h264parse ! mppvideodec ! \
        videoscale ! video/x-raw,width=640,height=360 ! \
        videobox left=-660 top=-10 ! videomixer.sink_1 \
    videomixer name=videomixer ! autovideosink
```

#### Zero-Copy Pipeline (Optimal Performance)
```bash
# Use RGA for format conversion and zero-copy sink
gst-launch-1.0 filesrc location=video.mp4 ! \
    qtdemux ! h264parse ! mppvideodec ! \
    rgaconvert ! video/x-raw,format=NV12 ! \
    rkximagesink
```

## Encoder Parameters

### mppvideoenc Properties

```bash
# List all encoder properties
gst-inspect-1.0 mppvideoenc
```

Common properties:
- **codec** - Codec to use (h264, hevc) [default: h264]
- **bitrate** - Target bitrate in kbps [default: 2000]
- **rc-mode** - Rate control mode (cbr, vbr, fixqp) [default: vbr]
- **gop** - GOP size [default: 60]
- **qp-init** - Initial QP value [default: 26]
- **bps-min** - Minimum bitrate [default: bitrate/4]
- **bps-max** - Maximum bitrate [default: bitrate*4]

Example with custom settings:
```bash
gst-launch-1.0 videotestsrc ! \
    mppvideoenc codec=h264 bitrate=5000 rc-mode=cbr gop=30 qp-init=24 ! \
    h264parse ! mp4mux ! filesink location=custom.mp4
```

## Performance Benchmarks

### CPU Usage Comparison (1080p H.264)

| Task | Software (CPU) | Hardware (MPP) | CPU Reduction |
|------|----------------|----------------|---------------|
| Decode 1080p@30fps | ~70% | ~5% | **93%** |
| Encode 1080p@30fps | ~95% | ~15% | **84%** |
| Transcode 1080p | ~100% (drops frames) | ~20% | **80%** |

### Throughput (RK3566)

- **Decode:** 4K@30fps or 1080p@60fps
- **Encode:** 1080p@60fps
- **Multiple streams:** 2x 1080p@30fps decode simultaneously

## Troubleshooting

### Plugins Not Found

```bash
# Check plugin installation
ls /usr/lib/gstreamer-1.0/ | grep -i rockchip

# Should show:
# libgstrockchip.so

# Check GStreamer can find plugins
gst-inspect-1.0 mppvideodec
```

**Fix:** Ensure `gstreamer1.0-rockchip` package is installed:
```bash
opkg list-installed | grep gstreamer1.0-rockchip
```

### Decoder Fails to Initialize

```bash
# Check MPP devices
ls -la /dev/mpp*
ls -la /dev/video*

# Check for errors
dmesg | grep -i "mpp\|vdec\|venc"
```

**Common issues:**
- Missing `/dev/mpp_service` - Kernel driver not loaded
- Missing `/dev/video*` - V4L2 devices not created
- Permission denied - Add user to `video` group

### Poor Encoding Quality

Adjust encoder parameters:
```bash
# Higher bitrate
mppvideoenc bitrate=8000

# Lower initial QP (higher quality)
mppvideoenc qp-init=22

# Use CBR for consistent quality
mppvideoenc rc-mode=cbr bitrate=5000
```

### Frame Drops

```bash
# Increase buffers
gst-launch-1.0 -v filesrc location=video.mp4 ! queue max-size-buffers=200 ! \
    qtdemux ! h264parse ! mppvideodec ! autovideosink

# Reduce resolution
videoscale ! video/x-raw,width=1280,height=720
```

## Integration with Applications

### Python Example

```python
import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst, GLib

Gst.init(None)

# Create pipeline with hardware decode
pipeline_str = """
    filesrc location=video.mp4 !
    qtdemux ! h264parse ! mppvideodec !
    videoconvert ! autovideosink
"""

pipeline = Gst.parse_launch(pipeline_str)
pipeline.set_state(Gst.State.PLAYING)

# Run main loop
loop = GLib.MainLoop()
loop.run()
```

### C Example

```c
#include <gst/gst.h>

int main(int argc, char *argv[]) {
    GstElement *pipeline;
    GstBus *bus;
    GstMessage *msg;

    gst_init(&argc, &argv);

    // Create pipeline with hardware acceleration
    pipeline = gst_parse_launch(
        "filesrc location=video.mp4 ! "
        "qtdemux ! h264parse ! mppvideodec ! "
        "videoconvert ! autovideosink",
        NULL
    );

    gst_element_set_state(pipeline, GST_STATE_PLAYING);

    // Wait until error or EOS
    bus = gst_element_get_bus(pipeline);
    msg = gst_bus_timed_pop_filtered(bus, GST_CLOCK_TIME_NONE,
        GST_MESSAGE_ERROR | GST_MESSAGE_EOS);

    // Cleanup
    gst_message_unref(msg);
    gst_object_unref(bus);
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    return 0;
}
```

Compile:
```bash
gcc -o player player.c $(pkg-config --cflags --libs gstreamer-1.0)
```

## Best Practices

1. **Use hardware decode/encode** - Always prefer `mppvideodec`/`mppvideoenc` over software codecs
2. **Zero-copy pipelines** - Use `rkximagesink` when possible to avoid memory copies
3. **RGA conversion** - Use `rgaconvert` for color space conversion instead of CPU-based `videoconvert`
4. **Buffer management** - Add `queue` elements for better buffering in complex pipelines
5. **Format selection** - Use NV12 format when possible (native to hardware)

## References

- **GStreamer Documentation:** https://gstreamer.freedesktop.org/documentation/
- **gst-rockchip GitHub:** https://github.com/Meonardo/gst-rockchip
- **Rockchip MPP:** https://github.com/rockchip-linux/mpp
- **GStreamer Plugins Writing:** https://gstreamer.freedesktop.org/documentation/plugin-development/

## Summary

With GStreamer Rockchip plugins:
- ✅ Hardware-accelerated video decode (H.264, H.265, VP8, VP9)
- ✅ Hardware-accelerated video encode (H.264, H.265)
- ✅ 90%+ CPU reduction for video tasks
- ✅ Smooth 4K video playback
- ✅ Multiple simultaneous video streams
- ✅ Zero-copy video rendering
- ✅ Standard GStreamer API compatibility

Perfect for video streaming, surveillance, media players, and video processing applications on RK3566!
