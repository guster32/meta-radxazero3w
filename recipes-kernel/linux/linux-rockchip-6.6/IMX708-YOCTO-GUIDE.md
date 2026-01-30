# IMX708 Camera Device Tree Overlay - Yocto Guide

## Overview

The Sony IMX708 camera sensor support has been added as a device tree overlay for the Radxa Zero 3W. This is the official camera sensor used in Raspberry Pi Camera Module 3.

## Files

- **rk3566-radxa-zero-3w-imx708.dtso** - IMX708 camera sensor overlay
- **rk3566-radxa-zero-3w-rk628.dtso** - RK628 HDMI-to-CSI overlay
- **linux-rockchip_6.6.bbappend** - Yocto recipe that builds both overlays

## Architecture

```
Base DTB: rk3566-radxa-zero-3w.dtb
  ├─ MIPI CSI pipeline (always available)
  ├─ I2C buses
  └─ GPIO infrastructure

Overlays (load at runtime):
  ├─ rk3566-radxa-zero-3w-imx708.dtbo  (IMX708 camera sensor)
  └─ rk3566-radxa-zero-3w-rk628.dtbo   (RK628 HDMI-to-CSI)
```

## Building with Yocto

The overlays are automatically built when you build the kernel:

```bash
# Build kernel with overlays
bitbake linux-rockchip

# Or build the full image
bitbake retrofactory-image
```

### Output Files

After building, you'll have:
- `/boot/rk3566-radxa-zero-3w.dtb` - Base device tree
- `/boot/overlays/rk3566-radxa-zero-3w-imx708.dtbo` - IMX708 overlay
- `/boot/overlays/rk3566-radxa-zero-3w-rk628.dtbo` - RK628 overlay

## GPIO Configuration

### ✅ Default GPIOs (Standard Radxa Zero 3W Camera Connector)

The IMX708 overlay is pre-configured for the **standard camera connector** on the Radxa Zero 3W:

```dts
powerdown-gpios = <&gpio3 22 GPIO_ACTIVE_HIGH>;  /* GPIO3_C6 */
reset-gpios = <&gpio3 21 GPIO_ACTIVE_LOW>;       /* GPIO3_C5 */
```

**Do you need to change these?**

- ✅ **NO** - If using official Radxa camera connector
- ⚠️ **YES** - If using custom hardware or different camera connector

The GPIOs (GPIO3_21 and GPIO3_22) are standard for the Radxa Zero 3W camera interface and should work with:
- Raspberry Pi Camera Module 3 (IMX708)
- Compatible camera modules using IMX708 sensor
- Standard 22-pin camera FPC connector

### If You Need Different GPIOs

Edit `rk3566-radxa-zero-3w-imx708.dtso`:

```dts
powerdown-gpios = <&gpio3 22 GPIO_ACTIVE_HIGH>;  /* Change GPIO bank/pin */
reset-gpios = <&gpio3 21 GPIO_ACTIVE_LOW>;       /* Change GPIO bank/pin */
```

Then rebuild:
```bash
bitbake -c clean linux-rockchip && bitbake linux-rockchip
```

## Using the IMX708 Overlay

### Loading the Overlay

The overlay needs to be loaded at boot time. This depends on your boot configuration.

#### Method 1: U-Boot extlinux.conf

Edit `/boot/extlinux/extlinux.conf`:

```
label Yocto Radxa Zero 3W
    kernel /Image
    fdt /rk3566-radxa-zero-3w.dtb
    fdtoverlays /overlays/rk3566-radxa-zero-3w-imx708.dtbo
    append root=/dev/mmcblk0p2 rootwait
```

#### Method 2: U-Boot env (if using boot.scr)

Add to your boot script:
```bash
setenv fdtoverlays overlays/rk3566-radxa-zero-3w-imx708.dtbo
```

#### Method 3: config.txt (Raspberry Pi style)

If your bootloader supports it:
```
dtoverlay=rk3566-radxa-zero-3w-imx708
```

## Configuration Details

### I2C Bus

The IMX708 overlay uses **I2C2**, which is the standard camera I2C bus on the Radxa Zero 3W.

### I2C Address

Default: `0x10`

This is the standard I2C address for the IMX708 sensor.

### Camera Clock

The sensor receives its clock from the SoC:
```dts
clocks = <&cru 109>;  /* CLK_CIF_OUT */
```

### MIPI CSI Configuration

- **Mode:** 4-lane
- **Data lanes:** 1, 2, 3, 4
- **Link frequency:** 450 MHz

## Verifying the Camera

After booting with the IMX708 overlay loaded:

### 1. Check Device Tree

```bash
# Check if overlay was applied
ls /sys/firmware/devicetree/base/fragment@*

# Check for IMX708 node
ls /sys/firmware/devicetree/base/i2c@*/imx708@10/
```

### 2. Check I2C

```bash
# Scan I2C bus 2
i2cdetect -y 2

# Should show 0x10 if IMX708 is detected
```

### 3. Check Kernel Logs

```bash
dmesg | grep -i imx708
dmesg | grep -i csi
```

### 4. Check Video Device

```bash
# List video devices
v4l2-ctl --list-devices

# Should show IMX708 device
# Example output:
# rkisp-mipi-luma (platform:rkisp-vir0):
#     /dev/video0
#     /dev/video1
```

### 5. Check Camera Capabilities

```bash
# List supported formats
v4l2-ctl -d /dev/video0 --list-formats-ext

# Camera information
v4l2-ctl -d /dev/video0 --all
```

## Testing the Camera

### Capture a Still Image

```bash
# Using v4l2-ctl
v4l2-ctl -d /dev/video0 \
  --set-fmt-video=width=4608,height=2592,pixelformat=RGGB \
  --stream-mmap --stream-count=1 \
  --stream-to=capture.raw

# Using ffmpeg
ffmpeg -f v4l2 -video_size 4608x2592 -i /dev/video0 \
  -frames:v 1 capture.jpg
```

### Capture Video

```bash
ffmpeg -f v4l2 -video_size 1920x1080 -i /dev/video0 \
  -c:v libx264 -preset fast \
  -t 10 output.mp4
```

### Using GStreamer

```bash
# View live preview
gst-launch-1.0 v4l2src device=/dev/video0 ! \
  videoconvert ! autovideosink

# Record video
gst-launch-1.0 v4l2src device=/dev/video0 ! \
  video/x-raw,width=1920,height=1080 ! \
  videoconvert ! x264enc ! mp4mux ! \
  filesink location=output.mp4
```

## Troubleshooting

### Overlay Not Loading

1. Check boot logs: `dmesg | grep -i overlay`
2. Verify overlay path in boot configuration
3. Check overlay file exists in `/boot/overlays/`

### Camera Not Detected on I2C

1. Verify camera module is properly connected to FPC connector
2. Check camera cable orientation (blue side up typically)
3. Check I2C bus number (should be 2)
4. Check power supply to camera module
5. Verify GPIOs if using custom hardware

### No Video Device Appears

1. Check kernel logs: `dmesg | grep -i imx708`
2. Verify MIPI CSI physical connections
3. Check that IMX708 driver is enabled in kernel config:
   ```bash
   zcat /proc/config.gz | grep IMX708
   # Should show: CONFIG_VIDEO_IMX708=y or =m
   ```
4. GPIO conflicts - check no other device uses GPIO3_21/GPIO3_22

### Image Quality Issues

1. Check focus - IMX708 modules may have adjustable focus
2. Verify lighting conditions
3. Check for lens dirt or scratches
4. Try different resolutions and formats

### Performance Issues

1. Use hardware encoding when available:
   ```bash
   gst-launch-1.0 v4l2src ! v4l2h264enc ! ...
   ```
2. Reduce resolution for better framerate
3. Check system load and CPU frequency
4. Ensure adequate cooling for sustained operation

## Supported Resolutions

The IMX708 sensor supports various resolutions:

- **Full resolution:** 4608 x 2592 (12MP)
- **2x2 binned:** 2304 x 1296
- **1080p:** 1920 x 1080 (cropped)
- **720p:** 1280 x 720
- **VGA:** 640 x 480

Check available formats:
```bash
v4l2-ctl -d /dev/video0 --list-formats-ext
```

## Camera Module Compatibility

### Confirmed Working

- Raspberry Pi Camera Module 3 (IMX708)
- Third-party IMX708 camera modules with standard pinout

### Requirements

- 22-pin MIPI CSI camera connector
- IMX708 sensor
- Compatible with 4-lane MIPI CSI-2
- Standard GPIO pinout (GPIO3_21/GPIO3_22)

## Development

### Modifying the Overlay

1. Edit `rk3566-radxa-zero-3w-imx708.dtso` in the recipe directory
2. Rebuild: `bitbake -c clean linux-rockchip && bitbake linux-rockchip`
3. Deploy: `bitbake linux-rockchip -c deploy`
4. Update boot partition with new `.dtbo` file

### Adding Custom Sensor Properties

You can add sensor-specific properties to the overlay:

```dts
imx708: imx708@10 {
    compatible = "sony,imx708";
    reg = <0x10>;
    
    /* Add custom properties */
    rotation = <180>;
    orientation = <2>;
    
    /* Lens info */
    lens-focus = <0x0 0x10 0x3ff>;
    
    ...
};
```

## Using with libcamera

The IMX708 sensor is well-supported by libcamera:

```bash
# List cameras
libcamera-hello --list-cameras

# Capture image
libcamera-still -o test.jpg

# Record video
libcamera-vid -t 10000 -o test.h264

# Live preview
libcamera-hello
```

## Hardware Connections

### Camera Connector Pinout (Typical)

The Radxa Zero 3W camera connector uses a standard 22-pin FPC:

- **Pins 1-2:** GND
- **Pins 3-6:** MIPI CSI data lanes (D0+, D0-, D1+, D1-)
- **Pins 7-8:** GND
- **Pins 9-12:** MIPI CSI data lanes (D2+, D2-, D3+, D3-)
- **Pins 13-14:** GND
- **Pins 15-16:** MIPI CSI clock (CLK+, CLK-)
- **Pins 17-18:** I2C (SDA, SCL)
- **Pins 19-20:** GPIO (reset, powerdown)
- **Pins 21-22:** Power (3.3V, GND)

## References

- IMX708 Datasheet: Sony IMX708 documentation
- Raspberry Pi Camera Module 3: https://www.raspberrypi.com/products/camera-module-3/
- libcamera: https://libcamera.org/
- V4L2 Documentation: https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/v4l2.html

## Support

For camera issues:
1. Check camera module documentation
2. Verify physical connections and cable orientation
3. Test with known-good camera module
4. Check Radxa Zero 3W camera documentation at https://wiki.radxa.com
