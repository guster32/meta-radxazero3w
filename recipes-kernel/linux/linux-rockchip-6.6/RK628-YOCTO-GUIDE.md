# RK628 CSI Device Tree Overlay - Yocto Guide

## Overview

The RK628 HDMI-to-MIPI-CSI bridge support has been added as a device tree overlay for the Radxa Zero 3W, following the same pattern as the IMX708 camera overlay.

## Files

- **rk3566-radxa-zero-3w-rk628.dtso** - RK628 CSI overlay
- **rk3566-radxa-zero-3w-imx708.dtso** - IMX708 camera overlay  
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

## Using the RK628 Overlay

### ⚠️ GPIO Configuration Required

Before using the RK628 overlay, you **MUST** edit the GPIO assignments in:
```
meta-radxazero3w/recipes-kernel/linux/linux-rockchip-6.6/rk3566-radxa-zero-3w-rk628.dtso
```

Update these based on your RK628 board connections:
```dts
interrupt-parent = <&gpio3>;
interrupts = <RK_PA0 IRQ_TYPE_LEVEL_HIGH>;  /* ← Your interrupt GPIO */

reset-gpios = <&gpio3 RK_PA1 GPIO_ACTIVE_LOW>;      /* ← Your reset GPIO */
plugin-det-gpios = <&gpio3 RK_PA2 GPIO_ACTIVE_LOW>; /* ← Your detect GPIO */
```

And update the pinctrl to match:
```dts
rockchip,pins =
    <3 RK_PA0 RK_FUNC_GPIO &pcfg_pull_none>,  /* ← Must match interrupt */
    <3 RK_PA2 RK_FUNC_GPIO &pcfg_pull_none>,  /* ← Must match plugin-det */
    <3 RK_PA1 RK_FUNC_GPIO &pcfg_pull_none>;  /* ← Must match reset */
```

### Loading the Overlay

The overlay needs to be loaded at boot time. This depends on your boot configuration.

#### Method 1: U-Boot extlinux.conf

Edit `/boot/extlinux/extlinux.conf`:

```
label Yocto Radxa Zero 3W
    kernel /Image
    fdt /rk3566-radxa-zero-3w.dtb
    fdtoverlays /overlays/rk3566-radxa-zero-3w-rk628.dtbo
    append root=/dev/mmcblk0p2 rootwait
```

#### Method 2: U-Boot env (if using boot.scr)

Add to your boot script:
```bash
setenv fdtoverlays overlays/rk3566-radxa-zero-3w-rk628.dtbo
```

#### Method 3: config.txt (Raspberry Pi style)

If your bootloader supports it:
```
dtoverlay=rk3566-radxa-zero-3w-rk628
```

## Using Both Overlays (Not Recommended)

⚠️ **Warning:** The IMX708 and RK628 overlays both use the same MIPI CSI pipeline and cannot be used simultaneously.

If you need to switch between them, use only one overlay at a time in your boot configuration.

## Configuration Details

### I2C Bus

The RK628 overlay is configured to use **I2C2**, which is the standard camera I2C bus on the Radxa Zero 3W (same as IMX708).

### I2C Address

Default: `0x50`

If your RK628 board uses a different address, edit the overlay:
```dts
reg = <0x50>;  /* Change this if needed */
```

### MIPI CSI Configuration

- **Mode:** 4-lane (full D-PHY mode)
- **Data lanes:** 1, 2, 3, 4
- **Continuous clock:** Enabled

## Verifying the Overlay

After booting with the RK628 overlay loaded:

### 1. Check Device Tree

```bash
# Check if overlay was applied
ls /sys/firmware/devicetree/base/fragment@*

# Check for RK628 node
ls /sys/firmware/devicetree/base/i2c@*/rk628_csi@50/
```

### 2. Check I2C

```bash
# Scan I2C bus 2
i2cdetect -y 2

# Should show 0x50 if RK628 is detected
```

### 3. Check Kernel Logs

```bash
dmesg | grep -i rk628
dmesg | grep -i csi
```

### 4. Check Video Device

```bash
v4l2-ctl --list-devices
# Should show RK628 CSI device

v4l2-ctl -d /dev/video0 --list-formats-ext
```

## Troubleshooting

### Overlay Not Loading

1. Check boot logs: `dmesg | grep -i overlay`
2. Verify overlay path in boot configuration
3. Check overlay file exists in `/boot/overlays/`

### RK628 Not Detected on I2C

1. Verify GPIO configuration matches your hardware
2. Check I2C bus number (should be 2)
3. Check I2C address (default 0x50)
4. Verify power to RK628 board

### No Video Device

1. Check kernel logs: `dmesg | grep -i rk628`
2. Verify MIPI CSI physical connections
3. Check that RK628 driver is enabled in kernel config
4. GPIO conflicts - another device using same GPIOs

### Conflicts with IMX708

Remove the IMX708 overlay from boot configuration if both are enabled.

## Development

### Modifying the Overlay

1. Edit the `.dtso` file in the recipe directory
2. Rebuild: `bitbake -c clean linux-rockchip && bitbake linux-rockchip`
3. Deploy: `bitbake linux-rockchip -c deploy`
4. Update boot partition with new `.dtbo` file

### Adding to the Recipe

The overlay is already configured in `linux-rockchip_6.6.bbappend`:

```bitbake
SRC_URI:append:radxa-zero3w = " \
    ...
    file://rk3566-radxa-zero-3w-rk628.dtso \
"

KERNEL_DEVICETREE:radxa-zero3w = " \
    ...
    rockchip/rk3566-radxa-zero-3w-rk628.dtbo \
"
```

## Hardware Requirements

- RK628 CSI board
- HDMI source
- Radxa Zero 3W with camera connector
- Proper GPIO connections for:
  - Interrupt signal
  - Reset control  
  - HDMI plugin detection

## References

- RK628 Datasheet: Check Rockchip documentation
- IMX708 overlay: `rk3566-radxa-zero-3w-imx708.dtso` (similar structure)
- Device Tree Overlays: https://www.kernel.org/doc/Documentation/devicetree/overlay-notes.txt
- Yocto Device Tree: https://docs.yoctoproject.org/kernel-dev/common.html#using-device-tree-overlays

## Support

For GPIO assignments and hardware connections:
1. Check your RK628 board schematic/documentation
2. Refer to Radxa Zero 3W pinout
3. Consult similar RK3566/RK3568 reference designs
