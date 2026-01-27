# Panfrost GPU Driver Guide for Radxa Zero 3W

## Overview

The Radxa Zero 3W with RK3566 SoC includes a Mali-G52 GPU. You have two driver options:

### 1. ARM Proprietary Mali Driver (Default in rockchip_linux_defconfig)
- **Pros:** Rockchip-tuned, vendor-optimized
- **Cons:** Closed-source, userspace binaries required, limited mainline support

### 2. Panfrost Open-Source Driver (Recommended for Mesa/Wayland)
- **Pros:** Open-source, Mesa/Wayland native, mainline kernel, active development
- **Cons:** May have different performance characteristics vs proprietary

## Configuration Applied

We've created `panfrost.cfg` which:
- **Disables** all ARM proprietary Mali drivers (`MALI400`, `MALI450`, `MALI_MIDGARD`)
- **Enables** `CONFIG_DRM_PANFROST=y` (open-source driver)
- **Keeps** Rockchip DRM display drivers (required for HDMI/display output)
- **Enables** Panfrost thermal management for GPU DVFS

## Device Tree Requirements (Already Applied)

The DTS changes we made are **critical** for Panfrost:

```c
&gpu {
    compatible = "arm,mali-bifrost";
    interrupt-names = "gpu", "job", "mmu";  // Panfrost expects this exact order
    clocks = <&cru ACLK_GPU_PRE>, <&cru CLK_GPU>;
    clock-names = "bus", "core";  // Panfrost standard names
    mali-supply = <&vdd_gpu_npu>;
    operating-points-v2 = <&gpu_opp_table>;
    status = "okay";
};
```

## Userspace Requirements

### Mesa 3D Graphics Stack

Install Mesa with Panfrost support:

```bash
# Yocto/OE: Add to image
IMAGE_INSTALL:append = " \
    mesa \
    mesa-megadriver \
    libgbm \
"

# Or runtime check
ls -l /usr/lib/dri/panfrost_dri.so
```

### Required Libraries

- **libdrm** - DRM/KMS userspace library
- **mesa** - OpenGL/Vulkan implementation with Panfrost
- **libgbm** - Generic Buffer Management
- **wayland/X11** - Display server

### Verification Commands

```bash
# Check kernel driver loaded
dmesg | grep -i panfrost
# Expected: panfrost fde60000.gpu: ... GPU identified as ...

# Verify DRM device
ls -l /dev/dri/
# Expected: card0, renderD128

# Check Mesa driver
glxinfo | grep -i "OpenGL renderer"
# Expected: "Mali-G52"

# Test GPU acceleration
es2_info
es2gears_wayland
```

## Thermal Throttling & DVFS

With Panfrost enabled:

```bash
# Monitor GPU frequency
watch -n1 'cat /sys/class/devfreq/fde60000.gpu/cur_freq'

# Monitor temperature
cat /sys/class/thermal/thermal_zone1/temp  # GPU thermal zone

# Available frequencies
cat /sys/class/devfreq/fde60000.gpu/available_frequencies
# Should show: 200000000 300000000 400000000 600000000 700000000 800000000
```

## Performance Tuning

### Governor Selection

```bash
# Available governors
cat /sys/class/devfreq/fde60000.gpu/available_governors

# Performance mode (max frequency)
echo performance > /sys/class/devfreq/fde60000.gpu/governor

# Power-saving mode
echo simple_ondemand > /sys/class/devfreq/fde60000.gpu/governor
```

## Troubleshooting

### GPU Not Detected

```bash
# Check Panfrost loaded
lsmod | grep panfrost

# Check DTS configuration
dtc -I fs /sys/firmware/devicetree/base | grep -A20 "gpu@"

# Verify interrupts are correct
grep gpu /proc/interrupts
```

### Poor Performance

1. **Check governor:** Ensure not stuck in power-saving mode
2. **Verify voltage:** Check `vdd_gpu_npu` regulator is working
3. **Temperature:** Ensure not thermal throttling

### Display Issues

Panfrost handles GPU only. Display uses Rockchip DRM:

```bash
# Verify Rockchip DRM loaded
dmesg | grep -i "rockchip drm"

# Check HDMI status
cat /sys/class/drm/card0-HDMI-A-1/status
cat /sys/class/drm/card0-HDMI-A-1/modes
```

## Switching Back to Proprietary Driver

If needed, remove `panfrost.cfg` from SRC_URI in bbappend:

```diff
 SRC_URI:append:radxa-zero3w = " \
     file://rk3566-radxa-zero-3.dtsi \
     file://rk3566-radxa-zero-3w.dts \
     file://radxa-zero3w.cfg \
-    file://panfrost.cfg \
 "
```

Then rebuild kernel.

## References

- **Panfrost Documentation:** https://docs.mesa3d.org/drivers/panfrost.html
- **Mali-G52 Datasheet:** ARM Bifrost architecture
- **Kernel Driver:** `drivers/gpu/drm/panfrost/`
- **DT Bindings:** `Documentation/devicetree/bindings/gpu/arm,mali-bifrost.yaml`

## Summary

✅ **Kernel:** panfrost.cfg enables open-source driver  
✅ **DTS:** Correct interrupt-names & clocks for Panfrost  
✅ **Userspace:** Mesa with Panfrost backend  
✅ **DVFS:** GPU frequency scaling and thermal throttling working  
✅ **Display:** Rockchip DRM handles HDMI/VOP independently  

Your Radxa Zero 3W is now configured for full open-source GPU acceleration! 🎉
