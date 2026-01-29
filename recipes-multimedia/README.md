# Rockchip Multimedia Hardware Acceleration

Quick reference for using hardware video acceleration on Radxa Zero 3W (RK3566).

## Quick Start

### 1. Add to Your Image

Add this line to your image recipe (`conf/local.conf` or image `.bb` file):

```bitbake
IMAGE_INSTALL:append = " packagegroup-rockchip-multimedia"
```

### 2. Build

```bash
bitbake packagegroup-rockchip-multimedia
bitbake your-image
```

### 3. Verify on Target

```bash
# Check libraries installed
ls /usr/lib/librockchip_mpp.so
ls /usr/lib/librga.so

# Check video devices
ls /dev/video*
# Should show: /dev/video0 (decode), /dev/video1 (jpeg), /dev/video2 (encode)
```

## What's Included

### Recipes
- `rockchip-mpp` - Video encode/decode library (H.264, H.265, VP8, VP9)
- `rockchip-librga` - 2D graphics acceleration (scale, rotate, convert)
- `gstreamer1.0-rockchip` - GStreamer plugins with MPP/RGA acceleration
- `packagegroup-rockchip-multimedia` - Everything bundled together

### Kernel Support
All required kernel configs are already enabled in `radxa-zero3w.cfg`:
- ✅ VIDEO_ROCKCHIP_VDEC (hardware decode)
- ✅ VIDEO_ROCKCHIP_VENC (hardware encode)
- ✅ VIDEO_ROCKCHIP_RKJPEG (JPEG acceleration)
- ✅ ROCKCHIP_RGA3 (2D graphics)
- ✅ ROCKCHIP_IOMMU (required for video)

## Supported Codecs

### Hardware Decode
- H.264/AVC (up to 4K@30fps)
- H.265/HEVC (up to 4K@30fps)
- VP8 (up to 1080p@60fps)
- VP9 (up to 4K@30fps)
- MPEG-2, MPEG-4
- VC1

### Hardware Encode
- H.264/AVC (up to 1080p@60fps)
- H.265/HEVC (up to 1080p@60fps)
- VP8 (up to 1080p@60fps)
- MJPEG

## Usage Examples

### Direct MPP API
```c
#include <rockchip/rk_mpi.h>

MppCtx ctx;
MppApi *mpi;
mpp_create(&ctx, &mpi);
mpi->init(ctx, MPP_CTX_DEC, MPP_VIDEO_CodingAVC);
// Use for decode/encode
```

### FFmpeg (if configured with MPP)
```bash
ffmpeg -c:v h264_rkmpp -i input.mp4 output.yuv
```

### GStreamer
```bash
gst-launch-1.0 filesrc location=video.mp4 ! qtdemux ! h264parse ! mppvideodec ! autovideosink
```

## Performance

| Task | Software (CPU) | Hardware (MPP) |
|------|----------------|----------------|
| 1080p H.264 Decode | 60% CPU @ 24fps | 5% CPU @ 60fps |
| 4K H.264 Decode | 100% CPU (drops) | 10% CPU @ 30fps |

## Documentation

- **MPP Guide:** [ROCKCHIP-MPP-GUIDE.md](ROCKCHIP-MPP-GUIDE.md) - Direct MPP API usage
- **GStreamer Guide:** [gstreamer1.0-rockchip/GSTREAMER-ROCKCHIP-GUIDE.md](gstreamer1.0-rockchip/GSTREAMER-ROCKCHIP-GUIDE.md) - GStreamer plugins
- **Upstream MPP:** https://github.com/rockchip-linux/mpp
- **Upstream RGA:** https://github.com/airockchip/librga
- **GStreamer Plugins:** https://github.com/Meonardo/gst-rockchip

## Troubleshooting

### Libraries not found
```bash
ldconfig -p | grep mpp
# If empty, rebuild: bitbake -c cleansstate rockchip-mpp && bitbake rockchip-mpp
```

### No /dev/video* devices
```bash
dmesg | grep -i "rkvdec\|rkvenc"
# If nothing, check kernel config is applied
```

### Permission denied on /dev/video*
```bash
# Add user to video group
usermod -a -G video root
```

## File Structure

```
recipes-multimedia/
├── rockchip-mpp/
│   └── rockchip-mpp_git.bb          # MPP library recipe
├── rockchip-librga/
│   └── rockchip-librga_git.bb       # RGA library recipe
├── packagegroups/
│   └── packagegroup-rockchip-multimedia.bb  # Bundle everything
├── ROCKCHIP-MPP-GUIDE.md             # Detailed guide
└── README.md                         # This file
```

## Support

- RK3566 (Radxa Zero 3W) ✅
- RK3568 ✅
- RK3588 ✅ (compatible)

---

**Note:** Hardware video acceleration significantly improves performance and reduces power consumption. Highly recommended for video applications!
