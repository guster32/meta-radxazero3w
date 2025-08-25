# Rockchip MPP Driver Integration Guide

## Overview
This guide provides step-by-step instructions for applying and verifying the Rockchip MPP (Media Process Platform) driver patch to linux-yocto mainline 6.6.

## Files Created/Modified
- `include/uapi/linux/rk-mpp.h` - UAPI header for userspace interface
- `drivers/media/platform/rockchip/mpp/` - Complete MPP driver directory
- `drivers/media/platform/rockchip/Kconfig` - Updated to include MPP
- `drivers/media/platform/rockchip/Makefile` - Updated to build MPP

## Patch Application

### 1. Apply the Patch
```bash
cd /path/to/linux-yocto
git apply rockchip-mpp-driver.patch
```

### 2. Verify Patch Application
```bash
# Check that all files are present
ls -la include/uapi/linux/rk-mpp.h
ls -la drivers/media/platform/rockchip/mpp/
```

## Kernel Configuration

### 3. Enable MPP Driver in Kernel Config
Add these configuration options to your kernel config:

```
CONFIG_ROCKCHIP_MPP_SERVICE=m
CONFIG_ROCKCHIP_MPP_PROC_FS=y
CONFIG_ROCKCHIP_MPP_RKVDEC=y
CONFIG_ROCKCHIP_MPP_RKVDEC2=y
CONFIG_ROCKCHIP_MPP_RKVENC=y
CONFIG_ROCKCHIP_MPP_RKVENC2=y
CONFIG_ROCKCHIP_MPP_VDPU1=y
CONFIG_ROCKCHIP_MPP_VEPU1=y
CONFIG_ROCKCHIP_MPP_VDPU2=y
CONFIG_ROCKCHIP_MPP_VEPU2=y
CONFIG_ROCKCHIP_MPP_IEP2=y
CONFIG_ROCKCHIP_MPP_JPGDEC=y
CONFIG_ROCKCHIP_MPP_JPGENC=y
CONFIG_ROCKCHIP_MPP_AV1DEC=y
CONFIG_ROCKCHIP_MPP_VDPP=y
```

### 4. Required Dependencies
Ensure these dependencies are enabled:
```
CONFIG_HAS_DMA=y
CONFIG_VIDEOBUF2_DMA_CONTIG=y
CONFIG_PROC_FS=y (optional, for procfs support)
```

## Compilation Verification

### 5. Test Module Compilation
```bash
# Configure kernel first
make defconfig
make menuconfig  # Enable MPP options under Device Drivers -> Multimedia -> Media platform drivers -> Rockchip

# Test compilation of just the MPP module
make M=drivers/media/platform/rockchip/mpp/
```

### 6. Full Kernel Build Test
```bash
make -j$(nproc)
```

## Runtime Verification

### 7. Module Loading Test
After booting the kernel:
```bash
# Load the module
modprobe rk_vcodec

# Verify module loaded
lsmod | grep rk_vcodec

# Check for device nodes
ls -la /dev/mpp*
```

### 8. Device Tree Requirements
The MPP driver requires appropriate device tree entries for your Rockchip SoC. Example for RK3588:

```dts
mpp: mpp@fdb50000 {
    compatible = "rockchip,rk3588-mpp", "rockchip,mpp";
    reg = <0x0 0xfdb50000 0x0 0x800>;
    interrupts = <GIC_SPI 118 IRQ_TYPE_LEVEL_HIGH>;
    clocks = <&cru ACLK_RKVDEC>, <&cru HCLK_RKVDEC>;
    clock-names = "aclk", "hclk";
    power-domains = <&power RK3588_PD_RKVDEC>;
    iommus = <&rkvdec_mmu>;
};
```

## Key Changes Made for Mainline Compatibility

### 9. Architecture Independence
- Removed `depends on ARCH_ROCKCHIP` from Kconfig
- Added `depends on ARM64 || ARM || COMPILE_TEST`
- Added proper DMA and videobuf2 dependencies

### 10. Build System Integration
- Moved from `drivers/video/rockchip/mpp/` to `drivers/media/platform/rockchip/mpp/`
- Integrated into existing rockchip media platform structure
- Removed CPU-specific hack dependencies

### 11. UAPI Header
- Fixed void __user pointer issue for UAPI compatibility
- Changed to __u64 data field for cross-architecture compatibility

## Troubleshooting

### Common Issues:

1. **Missing UAPI header**: Ensure `include/uapi/linux/rk-mpp.h` is present
2. **Build failures**: Check that all dependencies are enabled in kernel config
3. **Module load failures**: Verify device tree has proper MPP entries
4. **No device nodes**: Check that udev rules are creating /dev/mpp* devices

### Debug Steps:
```bash
# Check kernel messages
dmesg | grep -i mpp

# Verify module symbols
modinfo rk_vcodec

# Check procfs entries (if enabled)
ls -la /proc/mpp/
```

## Hardware Support

This driver supports the following Rockchip SoCs:
- RK3588/RK3588S
- RK3568/RK3566
- RK3399
- RK3328
- RK3326/PX30
- And other Rockchip SoCs with MPP hardware

## Minimum Required Configuration:

__Core MPP Service (REQUIRED):__

```javascript
CONFIG_ROCKCHIP_MPP_SERVICE=m
```

__Essential Dependencies:__

```javascript
CONFIG_HAS_DMA=y
CONFIG_VIDEOBUF2_DMA_CONTIG=y
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_PLATFORM_SUPPORT=y
```

## Codec Engines (Enable based on your hardware):

__For RK3588/RK3588S (latest generation):__

```javascript
CONFIG_ROCKCHIP_MPP_RKVDEC2=y     # H.264/H.265 decoder v2
CONFIG_ROCKCHIP_MPP_RKVENC2=y     # H.264/H.265 encoder v2
CONFIG_ROCKCHIP_MPP_AV1DEC=y      # AV1 decoder
CONFIG_ROCKCHIP_MPP_JPGDEC=y      # JPEG decoder
CONFIG_ROCKCHIP_MPP_JPGENC=y      # JPEG encoder
CONFIG_ROCKCHIP_MPP_VDPP=y        # Video processor
```

__For RK3568/RK3566:__

```javascript
CONFIG_ROCKCHIP_MPP_RKVDEC2=y
CONFIG_ROCKCHIP_MPP_RKVENC2=y
CONFIG_ROCKCHIP_MPP_VEPU2=y
CONFIG_ROCKCHIP_MPP_JPGDEC=y
CONFIG_ROCKCHIP_MPP_JPGENC=y
```

__For RK3399:__

```javascript
CONFIG_ROCKCHIP_MPP_RKVDEC=y      # H.264/H.265 decoder v1
CONFIG_ROCKCHIP_MPP_RKVENC=y      # H.264/H.265 encoder v1
CONFIG_ROCKCHIP_MPP_VDPU1=y       # VP8/VP9 decoder
CONFIG_ROCKCHIP_MPP_VEPU1=y       # VP8 encoder
CONFIG_ROCKCHIP_MPP_JPGDEC=y
```

## Optional but Recommended:

```javascript
CONFIG_ROCKCHIP_MPP_PROC_FS=y     # For debugging via /proc/mpp/
CONFIG_PROC_FS=y
```

## Performance Notes

- The driver provides hardware-accelerated video encoding/decoding
- Supports multiple concurrent codec sessions
- Requires proper IOMMU configuration for optimal performance
- Memory bandwidth and clock frequencies affect performance

## Integration with Userspace

The driver works with:
- FFmpeg with rockchip MPP support
- GStreamer rockchipmpp plugins
- Custom applications using the rk-mpp.h UAPI

For userspace integration, applications should use the MPP library which interfaces with this kernel driver through the /dev/mpp* device nodes.
