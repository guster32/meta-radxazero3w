# RK628 CSI Configuration Guide for Radxa Zero 3W

This guide explains how to configure the RK628 HDMI-to-MIPI-CSI board with your Radxa Zero 3W.

## Overview

The RK628 is a bridge chip that converts HDMI input to MIPI CSI-2 output, allowing you to capture HDMI video through the camera interface on your RK3566-based Radxa Zero 3W board.

## Files Modified

1. **rk3566-radxa-zero-3w.dts** - Main device tree file (now includes RK628 configuration)
2. **rk3566-radxa-zero-3w-rk628-hdmi2csi.dtsi** - RK628 CSI configuration include file

## Hardware Configuration Required

Before using this device tree, you **MUST** customize the following parameters based on your actual hardware connections:

### 1. I2C Bus Selection

The RK628 communicates via I2C. Based on the Radxa Zero 3W camera configuration (IMX708), the standard camera I2C bus is **I2C2**.

**Current setting:** `&i2c2` ✅ **Already configured correctly**

**Available I2C buses on RK3566:**
- i2c0 - Usually used for PMIC (already in use)
- i2c1 - Available
- **i2c2 - Standard camera I2C bus on Radxa Zero 3W (RECOMMENDED)**
- i2c3 - Available
- i2c4 - Available
- i2c5 - Available

**How to change (if needed):**
If your RK628 board uses a different I2C bus, edit `rk3566-radxa-zero-3w-rk628-hdmi2csi.dtsi` and change `&i2c2` to your I2C bus.

Also update the pinctrl setting:
```dts
pinctrl-0 = <&i2c2m0_xfer>;  /* Change to match your bus, e.g., &i2c3m0_xfer */
```

### 2. I2C Address

The RK628 typically uses I2C address **0x50** (default in the configuration).

**Current setting:** `reg = <0x50>;`

If your board uses a different address, update this value in the `rk628_csi@50` node.

### 3. GPIO Pin Assignments

**CRITICAL:** You must configure three GPIOs based on your hardware schematic:

#### a) Interrupt GPIO
```dts
interrupt-parent = <&gpio3>;
interrupts = <RK_PA0 IRQ_TYPE_LEVEL_HIGH>;
```

#### b) Reset GPIO
```dts
reset-gpios = <&gpio3 RK_PA1 GPIO_ACTIVE_LOW>;
```

#### c) HDMI Plugin Detection GPIO
```dts
plugin-det-gpios = <&gpio3 RK_PA2 GPIO_ACTIVE_LOW>;
```

**GPIO Format:** `<&gpio[BANK] RK_P[PORT][PIN] [FLAGS]>`

**Examples:**
- GPIO0_C5 → `<&gpio0 RK_PC5 ...>`
- GPIO3_A0 → `<&gpio3 RK_PA0 ...>`
- GPIO4_B3 → `<&gpio4 RK_PB3 ...>`

**Port naming:**
- A = 0-7 (PA0-PA7)
- B = 8-15 (PB0-PB7) 
- C = 16-23 (PC0-PC7)
- D = 24-31 (PD0-PD7)

### 4. Pinctrl Configuration

Update the pinctrl section to match your GPIO assignments:

```dts
&pinctrl {
	rk628_hdmiin {
		rk628_hdmiin_pins: rk628-hdmiin-pins {
			rockchip,pins =
				/* Interrupt pin - match interrupt GPIO above */
				<3 RK_PA0 RK_FUNC_GPIO &pcfg_pull_none>,
				/* Plugin detection pin - match plugin-det GPIO above */
				<3 RK_PA2 RK_FUNC_GPIO &pcfg_pull_none>,
				/* Reset pin - match reset GPIO above */
				<3 RK_PA1 RK_FUNC_GPIO &pcfg_pull_none>;
		};
	};
};
```

The first number is the GPIO bank (0-4), and the pins must match what you specified in the GPIOs section.

## How to Find Your GPIO Assignments

1. **Check your board schematic** - This is the most reliable source
2. **Check the RK628 CSI board documentation** - May specify which GPIOs to use
3. **Look at reference designs** - Check other RK3566/RK3568 boards with RK628
4. **Use available GPIOs** - Make sure the GPIOs you choose aren't already used by other devices

### Common GPIO Banks on RK3566:
- **GPIO0** - Often used for system functions
- **GPIO1** - Available for general use
- **GPIO2** - Available for general use
- **GPIO3** - Available for general use (good choice for RK628)
- **GPIO4** - Available for general use

## Checking Available I2C Buses

To see which I2C buses are available on your 40-pin header, refer to:
- Radxa Zero 3W pinout diagram
- Hardware documentation at https://radxa.com

## Device Tree Pipeline

The configuration sets up this video pipeline:

```
HDMI Input → RK628 → MIPI CSI-2 → CSI2 DPHY → MIPI CSI2 Host → RKCIF → V4L2
```

Components configured:
- `csi2_dphy_hw` - CSI-2 D-PHY hardware (4-lane mode)
- `csi2_dphy0` - CSI-2 D-PHY logical interface
- `mipi_csi2` - MIPI CSI-2 host controller
- `rkcif_mipi_lvds` - Rockchip Camera Interface
- `rkcif` - Camera interface (already enabled in base dtsi)
- `i2c3` - I2C bus for RK628 control

## Building the Device Tree

After customizing the configuration:

```bash
# Build the device tree
make dtbs

# Or build the whole kernel with device trees
make -j$(nproc)

# The compiled device tree will be at:
# arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3w.dtb
```

## Installing the Device Tree

```bash
# Copy to boot partition (adjust path for your system)
sudo cp arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3w.dtb /boot/dtbs/rockchip/

# Or if using a specific boot directory structure
sudo cp arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3w.dtb /boot/dtb/
```

## Verifying the Configuration

After booting with the new device tree:

### 1. Check if RK628 is detected on I2C
```bash
# Install i2c-tools if not present
sudo apt-get install i2c-tools

# Scan I2C bus 2 (standard camera I2C on Radxa Zero 3W)
sudo i2cdetect -y 2

# You should see address 0x50 (or your configured address)
```

### 2. Check kernel logs
```bash
# Check for RK628 driver messages
dmesg | grep -i rk628

# Check for CSI/camera messages
dmesg | grep -i csi
dmesg | grep -i mipi
dmesg | grep -i rkcif
```

### 3. Check V4L2 devices
```bash
# List video devices
v4l2-ctl --list-devices

# You should see the RK628 CSI device
```

### 4. Check video device capabilities
```bash
# Check available formats (replace /dev/videoX with actual device)
v4l2-ctl -d /dev/video0 --list-formats-ext
```

## Testing HDMI Input

Once configured and detected:

```bash
# Test capturing a frame (replace /dev/videoX with actual device)
v4l2-ctl -d /dev/video0 --set-fmt-video=width=1920,height=1080 \
  --stream-mmap --stream-count=1 --stream-to=test.raw

# Or use ffmpeg to capture video
ffmpeg -f v4l2 -i /dev/video0 -frames:v 1 test.jpg
```

## Troubleshooting

### RK628 not detected on I2C
- Verify I2C bus number is correct
- Check I2C address (try `i2cdetect -y <bus>`)
- Verify power supply to RK628 board
- Check physical connections

### No video devices appear
- Check kernel logs for errors: `dmesg | grep -i rk628`
- Verify all GPIOs are correctly configured
- Ensure RK628 driver is compiled in kernel
- Check MIPI CSI interface is properly connected

### Driver errors in dmesg
- GPIO conflicts: Another device may be using the same GPIO
- Pinctrl errors: Verify pinctrl configuration matches GPIO assignments
- I2C communication errors: Check I2C bus and address

### HDMI not detected
- Verify plugin-det GPIO is correctly configured
- Check HDMI cable and source are working
- Review RK628 interrupt GPIO configuration

## Disabling RK628 Configuration

If you need to disable the RK628 configuration:

1. **Comment out the include in the main DTS:**
   ```dts
   #include "rk3566-radxa-zero-3.dtsi"
   // #include "rk3566-radxa-zero-3w-rk628-hdmi2csi.dtsi"
   ```

2. **Or set status to "disabled" in the DTSI:**
   ```dts
   &rk628_csi {
       status = "disabled";
   };
   ```

## Additional Resources

- RK628 Datasheet: Check Rockchip documentation
- RK3566 TRM (Technical Reference Manual): GPIO and I2C configuration details
- Linux kernel RK628 driver: `drivers/media/i2c/rk628/`
- Radxa Zero 3W Wiki: https://wiki.radxa.com/Zero/3w

## Support

For hardware-specific GPIO and I2C assignments, consult:
1. Your RK628 CSI board schematic/documentation
2. Radxa Zero 3W hardware documentation
3. Similar reference designs with RK628 and RK3566/RK3568

## Notes

- The configuration uses 4-lane MIPI CSI-2 (full D-PHY mode)
- Default I2C clock frequency is set to 100kHz
- Continuous clock mode is enabled for the MIPI interface
- The camera module index is set to 0 (can be changed if multiple cameras exist)
