# Radxa Zero 3W - Kernel Configuration Guide

This document explains all kernel configuration files and what features they enable.

## Configuration File Structure

The kernel configuration is split into **modular, focused files** instead of one large config:

```
linux-rockchip-6.6/
├── radxa-zero3w.cfg           # Main board config (WiFi, regulators, video codecs)
├── gpu-panfrost.cfg           # Open-source GPU driver (Mesa/Wayland)
├── psplash-fb.cfg             # Boot splash screen / framebuffer console
├── camera-mipi-csi.cfg        # Complete MIPI CSI camera infrastructure
└── linux-rockchip_6.6.bbappend # Yocto recipe (includes all configs)
```

## File Descriptions

### 1. `radxa-zero3w.cfg` - Main Board Configuration

**Purpose:** Board-specific hardware that's unique to Radxa Zero 3W

**Enables:**
- ✅ AIC8800 WiFi/Bluetooth module
- ✅ FAN53555 voltage regulator (board-specific)
- ✅ Rockchip video codecs (VDEC, VENC, RKJPEG)
- ✅ RGA3 hardware 2D accelerator

**Disables:**
- ❌ ARM proprietary Mali drivers (replaced by Panfrost)
- ❌ Legacy RGA/RGA2 (RGA3 is used instead)

**Why separate?** These are board-specific and won't change often.

---

### 2. `gpu-panfrost.cfg` - Open-Source GPU Driver

**Purpose:** Enable Mesa/Wayland graphics with open-source Panfrost driver

**What it does:**
- Replaces ARM's proprietary Mali Bifrost driver with Panfrost
- Enables hardware-accelerated OpenGL ES 3.1 via Mesa
- Provides better Linux integration and mainline support
- Enables GPU thermal management

**Enables:**
- ✅ `CONFIG_DRM_PANFROST=y` - Main Panfrost driver
- ✅ `CONFIG_DRM_PANFROST_THERMAL=y` - Thermal/DVFS support
- ✅ `CONFIG_DRM_ROCKCHIP=y` - Rockchip display controller
- ✅ `CONFIG_ROCKCHIP_DW_HDMI=y` - HDMI output

**Disables:** ALL Mali proprietary drivers
- ❌ `CONFIG_MALI400`, `CONFIG_MALI450`
- ❌ `CONFIG_MALI_MIDGARD`, `CONFIG_MALI_BIFROST`
- ❌ `CONFIG_MALI_KBASE`, `CONFIG_MALI_UTGARD`

**Why separate?** You might want to switch back to vendor Mali driver for testing.

**See also:** `PANFROST-GUIDE.md` for userspace setup (Mesa packages)

---

### 3. `psplash-fb.cfg` - Boot Splash & Framebuffer

**Purpose:** Enable boot splash screen (psplash) and early console display

**Required for:**
- ✅ PSplash boot logo during system startup
- ✅ Framebuffer console (text mode on HDMI)
- ✅ Early kernel messages on display
- ✅ Virtual terminal switching (Ctrl+Alt+F1-F7)

**Key Configs:**
```cfg
CONFIG_FB=y                              # Core framebuffer
CONFIG_FRAMEBUFFER_CONSOLE=y             # Console on framebuffer
CONFIG_DRM_FBDEV_EMULATION=y             # DRM->FB compatibility
CONFIG_LOGO=y                            # Kernel boot logo
CONFIG_VT=y                              # Virtual terminals
CONFIG_FONTS=y                           # Console fonts (8x8, 8x16)
```

**Why needed?** Without this:
- No boot splash (blank screen until Wayland starts)
- No console access via HDMI
- Harder to debug boot issues

**Why separate?** Headless systems might not need this.

---

### 4. `camera-mipi-csi.cfg` - Complete Camera Infrastructure

**Purpose:** Enable Sony IMX708 camera and full MIPI CSI-2 pipeline

**What it enables:**

#### V4L2 Core Infrastructure
```cfg
CONFIG_MEDIA_SUPPORT=y                   # Media subsystem
CONFIG_MEDIA_CONTROLLER=y                # Media controller framework
CONFIG_VIDEO_DEV=y                       # V4L2 core
CONFIG_VIDEO_V4L2_SUBDEV_API=y           # Subdev API for sensors
```

#### Memory Management
```cfg
CONFIG_VIDEOBUF2_CORE=y                  # Video buffer management
CONFIG_VIDEOBUF2_DMA_CONTIG=y            # DMA buffers
CONFIG_V4L2_MEM2MEM_DEV=y                # Memory-to-memory
```

#### Rockchip Camera Hardware
```cfg
CONFIG_PHY_ROCKCHIP_MIPI_RX=y            # MIPI D-PHY receiver
CONFIG_VIDEO_ROCKCHIP_CIF=y              # Camera Interface
CONFIG_VIDEO_ROCKCHIP_ISP=y              # Image Signal Processor (ISP)
CONFIG_VIDEO_ROCKCHIP_ISP_VERSION_V1=y   # RK3566 uses ISP v1
```

#### Camera Sensor
```cfg
CONFIG_VIDEO_IMX708=m                    # Sony IMX708 sensor (module)
```

#### Supporting Infrastructure
```cfg
CONFIG_I2C_RK3X=y                        # I2C for sensor control
CONFIG_GPIOLIB=y                         # GPIO for power/reset
CONFIG_COMMON_CLK_ROCKCHIP=y             # MCLK clock
CONFIG_REGULATOR_FIXED_VOLTAGE=y         # Power regulators
CONFIG_ROCKCHIP_IOMMU=y                  # IOMMU for ISP
CONFIG_PL330_DMA=y                       # DMA engine
CONFIG_OF_OVERLAY=y                      # Device tree overlays
```

**Device Tree Integration:**
- Base DTS: `rk3566-radxa-zero-3w.dts` - Enables MIPI CSI pipeline
- Overlay: `rk3566-radxa-zero-3w-imx708.dtbo` - Adds IMX708 sensor

**Why separate?** Cameras are optional; headless systems don't need this.

**Testing Camera:**
```bash
# List camera devices
v4l2-ctl --list-devices

# Capture test image
v4l2-ctl --device /dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=NV12
v4l2-ctl --device /dev/video0 --stream-mmap --stream-to=test.raw --stream-count=1

# Using libcamera (recommended)
libcamera-still -o test.jpg
```

---

## How Configs Are Applied

### In Yocto Build

The `linux-rockchip_6.6.bbappend` file includes all configs:

```bitbake
SRC_URI:append:radxa-zero3w = " \
    file://radxa-zero3w.cfg \
    file://psplash-fb.cfg \
    file://camera-mipi-csi.cfg \
    file://gpu-panfrost.cfg \
    ...
"
```

Yocto's `kernel.bbclass` automatically merges these fragments into `.config`.

### Order of Application

1. Start with `rockchip_linux_defconfig` (kernel's default)
2. Apply `radxa-zero3w.cfg` (board basics)
3. Apply `psplash-fb.cfg` (display support)
4. Apply `camera-mipi-csi.cfg` (camera support)
5. Apply `gpu-panfrost.cfg` (GPU driver - last, to override Mali)

**Why this order?** Later configs can override earlier ones.

---

## Minimal vs Full Configuration

### Minimal Build (Headless Server)

If you don't need display or camera:

```bitbake
SRC_URI:append:radxa-zero3w = " \
    file://radxa-zero3w.cfg \
    # Omit psplash-fb.cfg
    # Omit camera-mipi-csi.cfg
    # Omit gpu-panfrost.cfg (or keep for compute)
"
```

**Use case:** IoT device, server, headless operation

### Standard Build (Desktop/Embedded Display)

```bitbake
SRC_URI:append:radxa-zero3w = " \
    file://radxa-zero3w.cfg \
    file://psplash-fb.cfg \
    file://gpu-panfrost.cfg \
    # Omit camera if not needed
"
```

**Use case:** Media player, digital signage, HMI

### Full Build (Camera + Display)

Use all configs (current setup).

**Use case:** Computer vision, video recording, full-featured SBC

---

## Verifying Configs

### Check if Config is Applied

After building, check the final `.config`:

```bash
# In Yocto build directory
cd tmp/work/radxa_zero3w-poky-linux/linux-rockchip/6.6.x-r0/build/

# Check specific config
grep CONFIG_DRM_PANFROST .config
grep CONFIG_VIDEO_IMX708 .config
grep CONFIG_FRAMEBUFFER_CONSOLE .config
```

### Expected Output

```
CONFIG_DRM_PANFROST=y
CONFIG_VIDEO_IMX708=m
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_VIDEO_ROCKCHIP_ISP=y
```

### Check for Conflicts

```bash
# Should NOT see Mali drivers if using Panfrost
grep CONFIG_MALI .config
# Expected: All should be "is not set"
```

---

## Runtime Verification

### GPU (Panfrost)

```bash
# Check if GPU is detected
dmesg | grep panfrost
# Expected: "panfrost fde60000.gpu: mali-g52 id 0x7402 major 0x1 minor 0x0"

# Check GPU device
ls /dev/dri/
# Expected: card0, renderD128

# Test OpenGL
glmark2-es2-drm
```

### Framebuffer Console

```bash
# Check framebuffer devices
ls /dev/fb*
# Expected: /dev/fb0

# Check console
cat /proc/fb
# Expected: "0 rockchipdrm"

# Test console
echo "Hello" > /dev/tty1
# Should appear on HDMI display
```

### Camera (MIPI CSI)

```bash
# Check camera devices
v4l2-ctl --list-devices
# Expected: rkcif, rkisp, imx708

# Check media pipeline
media-ctl -p -d /dev/media0
# Should show complete pipeline: imx708 -> mipi-dphy -> csi2 -> isp -> video

# Test capture
libcamera-hello --list-cameras
# Expected: "0 : imx708 [4608x2592] (/base/i2c@fdd40000/imx708@10)"
```

---

## Troubleshooting

### GPU Not Working

**Symptom:** No `/dev/dri/card0`, Mesa errors

**Check:**
```bash
# Verify Panfrost is enabled
grep CONFIG_DRM_PANFROST /boot/config-$(uname -r)

# Check for Mali driver conflicts
dmesg | grep -i mali
# Should be empty or show "not loaded"

# Verify kernel module
lsmod | grep panfrost
modprobe panfrost  # If not loaded
```

**Solution:** Rebuild with `gpu-panfrost.cfg` included

---

### No Boot Splash / Blank Console

**Symptom:** No boot logo, can't see console on HDMI

**Check:**
```bash
# Verify framebuffer
ls /dev/fb0
cat /proc/fb

# Check if DRM fbdev emulation is enabled
grep CONFIG_DRM_FBDEV_EMULATION /boot/config-$(uname -r)
```

**Solution:** Rebuild with `psplash-fb.cfg` included

---

### Camera Not Detected

**Symptom:** `v4l2-ctl --list-devices` shows nothing

**Check:**
```bash
# Verify camera config
grep CONFIG_VIDEO_IMX708 /boot/config-$(uname -r)

# Check ISP driver
grep CONFIG_VIDEO_ROCKCHIP_ISP /boot/config-$(uname -r)

# Verify device tree overlay is loaded
ls /proc/device-tree/
cat /proc/device-tree/compatible
# Should include "radxa,zero-3w"

# Check I2C
i2cdetect -y 2
# Should show device at 0x10

# Check kernel messages
dmesg | grep imx708
dmesg | grep rkisp
dmesg | grep rkcif
```

**Solutions:**
1. Rebuild with `camera-mipi-csi.cfg` included
2. Verify device tree overlay is applied: Check `/boot/overlays/` or boot config
3. Check hardware connections (camera cable, power)

---

## Customization

### Adding More Camera Sensors

Edit `camera-mipi-csi.cfg`, add sensor driver:

```cfg
# CONFIG_VIDEO_OV5647=m      # Raspberry Pi Camera v1
# CONFIG_VIDEO_IMX219=m      # Raspberry Pi Camera v2
# CONFIG_VIDEO_IMX477=m      # Raspberry Pi HQ Camera
```

Then create matching device tree overlay.

### Switching to Mali Proprietary Driver

If you need vendor Mali instead of Panfrost:

1. Remove `gpu-panfrost.cfg` from SRC_URI
2. Create `gpu-mali.cfg`:
```cfg
CONFIG_MALI_BIFROST=y
CONFIG_MALI_MIDGARD=y
# Re-enable other Mali options as needed
```

**Note:** You'll lose Mesa compatibility and need ARM's proprietary userspace.

---

## Summary Table

| Config File | Purpose | Size Impact | Required For |
|-------------|---------|-------------|--------------|
| `radxa-zero3w.cfg` | Board basics | Small | Everyone |
| `gpu-panfrost.cfg` | Open-source GPU | Medium | Desktop/Wayland |
| `psplash-fb.cfg` | Boot splash/console | Small | Display users |
| `camera-mipi-csi.cfg` | Camera support | Large | Camera users |

**Total size:** ~2-5 MB in kernel image, ~10-20 MB in modules

---

## Additional Resources

- **GPU Setup:** See `PANFROST-GUIDE.md` for Mesa/userspace configuration
- **DTS Integration:** See `KERNEL-INTEGRATION-GUIDE.md` for device tree details
- **Migration Notes:** See `MIGRATION-NOTES.md` for upgrade paths

---

## Quick Reference

**All configs enabled (full features):**
```bash
bitbake -c cleansstate linux-rockchip
bitbake linux-rockchip
# Includes: WiFi + GPU + Display + Camera
```

**Verify in running system:**
```bash
# GPU
ls /dev/dri/card0 && echo "✅ GPU OK"

# Framebuffer
ls /dev/fb0 && echo "✅ FB OK"

# Camera
v4l2-ctl --list-devices | grep -q imx708 && echo "✅ Camera OK"

# WiFi
nmcli device | grep wlan && echo "✅ WiFi OK"
```

Done! All features configured and documented.
