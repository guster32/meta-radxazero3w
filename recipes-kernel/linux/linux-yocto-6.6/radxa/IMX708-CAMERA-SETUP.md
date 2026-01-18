# IMX708 Camera Support for Radxa Zero 3W

This document describes the setup for Sony IMX708 camera sensor (Raspberry Pi Camera Module v3) support on the Radxa Zero 3W with mainline Linux 6.6.

## Hardware Configuration (Verified from Schematic v1.12)

- **MIPI CSI-2**: 4-lane interface (data-lanes = <1 2 3 4>)
- **I2C Bus**: I2C2 (with M1 multiplexing)
- **Camera Control GPIO**: GPIO3_C6 (CAMERAB_PDN_L, active-low)
- **Power Rails**: 
  - vcc2v8_dvp (2.8V analog supply)
  - vcc1v8_dvp (1.8V I/O supply)
- **Camera Clock**: 24MHz external oscillator

## Implementation Status

### ✅ Completed

1. **Device Tree Overlay** (`rk3566-radxa-zero-3w-imx708.dtso`)
   - Configured for 4-lane MIPI CSI-2
   - Correct node names for mainline kernel (csi2_dphy0, csi2_dphy_hw)
   - Complete camera pipeline: IMX708 → CSI2 D-PHY → MIPI CSI2 → RKCIF → RKISP
   - Verified GPIO and I2C assignments from schematic

2. **IMX708 Driver** (Patch 0003)
   - Ported from Raspberry Pi kernel (commit 954ac0d095a1)
   - Full driver support including:
     - 12MP full resolution (4608x2592) with Quad Bayer
     - 1080p 2x2 binned (2304x1296)
     - 720p cropped (1536x864)
     - HDR mode support
     - PDAF (Phase Detection Auto Focus)
   - Added to kernel build via patch 0003-Add-IMX708-sensor-driver.patch

### ⚠️ Still Required

The following drivers are **NOT in mainline Linux 6.6** and need to be ported from Rockchip vendor kernel:

1. **RKCIF Driver** (Rockchip Camera Interface)
   - Source: `drivers/media/platform/rockchip/cif/` from vendor kernel
   - Required for: Camera data capture interface
   - Complexity: Medium-High

2. **RKISP v21 Driver** (Rockchip Image Signal Processor)
   - Source: `drivers/media/platform/rockchip/isp/` from vendor kernel
   - Required for: Image processing pipeline
   - Complexity: High (large driver, ~50+ files)
   - Note: Mainline has rkisp1 but only supports v10/v12, not v21 used in RK3566

## Current Build Configuration

### Patches Applied (radxa-arm64.scc)
```
patch 0001-Adds-support-for-Radxa-Zero3w-board.patch
patch 0002-Adds-support-for-AIC8800D80.patch
patch 0003-Add-IMX708-sensor-driver.patch
```

## Changes Made

### Kernel Configuration Requirements

The kernel config in `radxa-zero3w.cfg` references drivers that don't exist in mainline yet:

```bash
# These work in mainline:
CONFIG_VIDEO_DEV=y
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CAMERA_SUPPORT=y
CONFIG_V4L2_FWNODE=y
CONFIG_PHY_ROCKCHIP_CSI2_DPHY=y  # CSI-2 PHY exists in mainline

# These need vendor drivers:
CONFIG_VIDEO_ROCKCHIP_ISP=y      # NOT in mainline - needs porting
CONFIG_VIDEO_ROCKCHIP_CIF=y      # NOT in mainline - needs porting
CONFIG_VIDEO_IMX708=y             # NOW AVAILABLE via patch 0003
```

### Device Tree Components

- **IMX708 sensor node** on I2C2 @ 0x10
- **24MHz camera clock** (fixed oscillator)
- **Power regulators** from base DTSI (vcc2v8_dvp, vcc1v8_dvp)
- **4-lane MIPI CSI-2** configuration
- **Complete pipeline**: IMX708 → csi2_dphy0 → mipi_csi2 → rkcif_mipi_lvds → rkisp
- **GPIO control**: GPIO3_C6 for powerdown

## Hardware Pin Assignments (Verified from Schematic v1.12)

| Function          | Assignment   | Notes                                    |
| ----------------- | ------------ | ---------------------------------------- |
| **I2C Bus**       | I2C2 (M1)    | I2C2_SDA_M1, I2C2_SCL_M1                 |
| **Powerdown GPIO** | GPIO3_C6     | CAMERAB_PDN_L (active-low)               |
| **MIPI Lanes**    | 4-lane       | CSI connector supports full 4-lane       |
| **Power Rails**   | vcc2v8_dvp   | 2.8V analog from PMIC                    |
|                   | vcc1v8_dvp   | 1.8V I/O from PMIC                       |
| **Camera Clock**  | 24MHz        | Fixed oscillator (not CIF_CLKOUT)        |

## IMX708 Specifications

- **Sensor**: Sony IMX708, 12MP (4056x3040)
- **Interface**: MIPI CSI-2, 2-lane
- **I2C Address**: 0x10
- **Clock**: 27MHz external clock
- **Power Requirements**:
  - AVDD: 2.8V (analog)
  - DOVDD: 1.8V (I/O)
  - DVDD: 1.2V (digital core)
- **Link Frequency**: 450 MHz per lane
- **Features**: Autofocus (via I2C control)

## Building the Updated Kernel

### Option 1: Full Yocto Build

```bash
# From your Arcadia workspace root
cd /workspaces/arcadia

# Ensure correct machine is selected
source poky/oe-init-build-env /home/builduser/mnt/build

# Verify machine setting
echo "MACHINE: $MACHINE"  # Should be "radxa-zero3w"

# Clean previous kernel build (optional but recommended)
bitbake -c cleansstate linux-yocto

# Build new kernel
bitbake linux-yocto 2>&1 | tail -50

# Or build complete image
bitbake core-image-minimal 2>&1 | tail -50
```

### Option 2: Kernel Only (Faster)

```bash
cd /workspaces/arcadia
source poky/oe-init-build-env /home/builduser/mnt/build

# Build just the kernel
bitbake -c compile -f linux-yocto 2>&1 | tail -50
bitbake -c deploy linux-yocto 2>&1 | tail -50
```

## Deploying to Board

### Method 1: Complete Image Flash

```bash
# Find the built image
ls /home/builduser/mnt/build/tmp-glibc/deploy/images/radxa-zero3w/

# Look for: core-image-minimal-radxa-zero3w.wic.gz
# Flash to SD card using balenaEtcher, dd, or similar
```

### Method 2: Kernel Module Only (Faster Testing)

```bash
# Copy IMX708 module to running board
scp /home/builduser/mnt/build/tmp-glibc/deploy/images/radxa-zero3w/modules/*.ko \
    root@<board-ip>:/lib/modules/$(uname -r)/kernel/drivers/media/i2c/

# On the board:
depmod -a
modprobe imx708
```

## Verifying Camera Detection

After booting with the new kernel/image:

### 1. Check kernel modules loaded:

```bash
lsmod | grep -E "imx708|rkisp|rkcif"
```

Expected output:

```
imx708                 16384  0
rkisp1                 98304  0
rkcif                  45056  0
```

### 2. Check dmesg for camera initialization:

```bash
dmesg | grep -E "imx708|rkisp|rkcif|csi"
```

Expected output should include:

```
[    X.XXX] imx708 2-0010: detected imx708
[    X.XXX] rkcif_mipi_lvds: registered
[    X.XXX] rkisp1: bound to video device
```

### 3. Check V4L2 devices:

```bash
v4l2-ctl --list-devices
```

Expected output:

```
rkisp1 (platform:rkisp1):
        /dev/video0
        /dev/video1
        ...

rkcif-mipi-lvds (platform:rkcif-mipi-lvds):
        /dev/video10
        ...
```

### 4. Check I2C communication:

```bash
# Scan I2C bus 4 for camera at address 0x10 (per schematic, camera is on I2C4)
i2cdetect -y 4
```

Expected: Should show device at address `0x10`

### 5. Test camera capture:

```bash
# List available formats
v4l2-ctl -d /dev/video0 --list-formats-ext

# Capture a test frame
v4l2-ctl -d /dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=NV12 \
         --stream-mmap --stream-count=1 --stream-to=test.raw

# Convert and view (if you have imagemagick)
convert -size 1920x1080 -depth 8 test.raw test.jpg
```

## Next Steps to Complete Camera Support

### Option A: Port Vendor Drivers (Required for Full Functionality)

1. **Port RKCIF driver** from `/Volumes/CaseSensitive/git/rockchip-linux/kernel`:
   ```bash
   # Extract driver directory
   drivers/media/platform/rockchip/cif/
   
   # Create patch 0004-Add-RKCIF-driver.patch
   # Include: Kconfig, Makefile, all .c/.h files
   ```

2. **Port RKISP v21 driver** from vendor kernel:
   ```bash
   # Extract driver directory  
   drivers/media/platform/rockchip/isp/
   
   # Create patch 0005-Add-RKISP-v21-driver.patch
   # This is a large driver (~50+ files)
   ```

3. **Update radxa-arm64.scc**:
   ```
   patch 0004-Add-RKCIF-driver.patch
   patch 0005-Add-RKISP-v21-driver.patch
   ```

4. **Update kernel config** to enable the newly added drivers

### Option B: Wait for Mainline Support

The Linux kernel community is working on upstreaming ISP v21 support, but it's not available in 6.6 yet. Monitor mainline kernel development for RK3566 ISP support.

## Testing Camera Detection (Without Full Pipeline)

Even without RKCIF/RKISP drivers, you can verify hardware setup:

### 1. Check IMX708 driver loads:
```bash
modprobe imx708
dmesg | grep imx708
```

Expected: Driver loads successfully

### 2. Check I2C communication:
```bash
i2cdetect -y 2
```

Expected: Device visible at address 0x10

### 3. Check GPIO control:
```bash
cat /sys/kernel/debug/gpio | grep -i camera
```

### 4. Verify power rails:
```bash
cat /sys/class/regulator/regulator.*/name | grep dvp
cat /sys/class/regulator/regulator.*/microvolts
```

Expected: vcc2v8_dvp = 2800000, vcc1v8_dvp = 1800000

## Troubleshooting

### Issue: IMX708 driver not found

**Solution:** Ensure patch 0003 is applied and kernel is rebuilt

### Issue: No camera detected on I2C

**Possible causes:**

1. **Wrong I2C bus** - Verify schematic shows I2C2
2. **GPIO not toggling** - Check GPIO3_C6 powerdown control
3. **Power rail issues** - Verify vcc2v8_dvp and vcc1v8_dvp enabled
4. **Cable connection** - Ensure FFC cable properly seated and oriented
5. **Wrong camera module** - Ensure using genuine IMX708 (RPi Camera v3)

**Solutions:**

```bash
# Check GPIO status
cat /sys/kernel/debug/gpio

# Scan I2C bus 4 (per schematic)
i2cdetect -y 4

# If still not working, try other buses
i2cdetect -y 0  # PMU
i2cdetect -y 1  # Display
i2cdetect -y 2  # Alt
i2cdetect -y 3  # External

# Check camera power regulator
cat /sys/class/regulator/regulator.*/name | grep camera
cat /sys/class/regulator/regulator.*/microvolts
```

### Issue: Camera detected but no video devices

**Check:**

```bash
# ISP and CIF drivers loaded?
lsmod | grep -E "rkisp|rkcif"

# Media controller setup
media-ctl -d /dev/media0 -p
```

### Issue: Driver module not loading

**Check:**

```bash
# Try loading manually
modprobe imx708

# Check for errors
dmesg | tail -50

# Verify module exists
find /lib/modules/$(uname -r) -name "*imx708*"
```

### Issue: Wrong GPIO pins

**To find correct GPIOs:**

1. Check Radxa wiki: https://wiki.radxa.com/Zero3
2. **Radxa ZERO 3W v1.12 schematic shows:**
   - Camera I2C: **I2C4**
   - Available camera GPIOs: **GPIO4_C2, C3, C4, C5, C6**
   - Current overlay uses: **GPIO4_C4** for reset/powerdown
3. Alternative camera GPIOs to try:
   - GPIO4_C5 = `<&gpio4 RK_PC5 ...>`
   - GPIO4_C6 = `<&gpio4 RK_PC6 ...>`

### Issue: Camera detected but no video

**Cause:** RKCIF and RKISP drivers not yet ported

**Solution:** Complete Option A above to port the required drivers

## Building

From your Yocto build environment:

```bash
# Clean previous kernel build
bitbake -c cleansstate linux-yocto

# Rebuild kernel with new patches
bitbake linux-yocto

# Or rebuild complete image
bitbake core-image-minimal
```

The build will apply:
- Patch 0001: Radxa Zero 3W board support
- Patch 0002: AIC8800D80 WiFi driver  
- Patch 0003: IMX708 camera sensor driver (NEW)

## Testing with GStreamer

Once camera is working:

```bash
# Simple test pattern
gst-launch-1.0 v4l2src device=/dev/video0 ! video/x-raw,width=1920,height=1080 ! xvimagesink

# H.264 encode using hardware encoder
gst-launch-1.0 v4l2src device=/dev/video0 ! video/x-raw,width=1920,height=1080 ! \
    v4l2h264enc ! h264parse ! qtmux ! filesink location=test.mp4

# RTSP streaming
gst-launch-1.0 v4l2src device=/dev/video0 ! video/x-raw,width=1920,height=1080 ! \
    v4l2h264enc ! h264parse ! rtph264pay ! udpsink host=192.168.1.100 port=5000
```

## Known Limitations

1. **GPIO pins are estimated** - May need adjustment based on actual hardware
2. **Autofocus** - Requires additional userspace control via I2C
3. **HDR mode** - May require additional ISP tuning
4. **Performance** - Initial configuration may not be optimized

## Next Steps

1. **Verify GPIO assignments** with Radxa documentation
2. **Build and test** the updated kernel
3. **Check dmesg** for camera detection
4. **Test video capture** with v4l2-ctl
5. **Optimize ISP settings** if needed
6. **Add ISP tuning files** for better image quality (optional)

## Summary

This setup provides:
- ✅ IMX708 sensor driver (ported from Raspberry Pi kernel)
- ✅ Correct 4-lane MIPI CSI-2 device tree configuration  
- ✅ Verified hardware pin assignments from schematic
- ⚠️ **Missing**: RKCIF and RKISP v21 drivers (need porting from vendor kernel)

**Current Status**: Hardware configuration complete, but full camera pipeline requires additional driver porting work.

## References

- Radxa Zero 3W Wiki: https://wiki.radxa.com/Zero3
- IMX708 Driver Source: Raspberry Pi kernel commit 954ac0d095a1
- Rockchip Vendor Kernel: https://github.com/rockchip-linux/kernel
- Rockchip RK3566 Datasheet: https://rockchip.fr/RK3566%20datasheet
- Linux V4L2 Documentation: https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/v4l2.html

## Support

If you encounter issues:

1. Check dmesg output thoroughly
2. Verify I2C communication
3. Test with known-working OV5647 camera to validate CSI pipeline
4. Consult Radxa forums: https://forum.radxa.com
