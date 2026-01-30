# RK628 CSI Quick Start - Radxa Zero 3W

## ⚠️ IMPORTANT: Hardware-Specific Configuration Required

The RK628 CSI device tree has been added but **REQUIRES CUSTOMIZATION** for your specific hardware setup!

## Files Created/Modified

1. ✅ `rk3566-radxa-zero-3w.dts` - Updated to include RK628 configuration
2. ✅ `rk3566-radxa-zero-3w-rk628-hdmi2csi.dtsi` - RK628 CSI configuration (NEEDS CUSTOMIZATION)
3. 📖 `RK628-CSI-SETUP.md` - Complete configuration guide

## Quick Customization Checklist

Edit `rk3566-radxa-zero-3w-rk628-hdmi2csi.dtsi` and update these settings:

### ☑️ 1. I2C Bus (Line ~116)
```dts
&i2c2 {  /* ← Already set to i2c2 (standard camera I2C on Radxa Zero 3W) */
```

Also update pinctrl on line ~121:
```dts
pinctrl-0 = <&i2c2m0_xfer>;  /* ← Already set for i2c2 */
```

✅ **Good news!** I2C2 is already configured correctly for the Radxa Zero 3W. This is the same I2C bus used by the IMX708 camera.

### ☑️ 2. I2C Address (Line ~126)
```dts
reg = <0x50>;  /* ← Verify this matches your RK628 board (usually 0x50) */
```

### ☑️ 3. GPIO Assignments (Lines ~143-147)

**CRITICAL:** Set these based on your hardware schematic:

```dts
interrupt-parent = <&gpio3>;                        /* ← GPIO bank */
interrupts = <RK_PA0 IRQ_TYPE_LEVEL_HIGH>;         /* ← Interrupt pin */

reset-gpios = <&gpio3 RK_PA1 GPIO_ACTIVE_LOW>;     /* ← Reset pin */
plugin-det-gpios = <&gpio3 RK_PA2 GPIO_ACTIVE_LOW>; /* ← HDMI detect pin */
```

### ☑️ 4. Pinctrl Configuration (Lines ~175-182)

**Must match GPIO assignments above:**

```dts
rk628_hdmiin_pins: rk628-hdmiin-pins {
    rockchip,pins =
        <3 RK_PA0 RK_FUNC_GPIO &pcfg_pull_none>,  /* ← Interrupt (bank, pin) */
        <3 RK_PA2 RK_FUNC_GPIO &pcfg_pull_none>,  /* ← Plugin detect */
        <3 RK_PA1 RK_FUNC_GPIO &pcfg_pull_none>;  /* ← Reset */
};
```

## GPIO Reference Table

| Notation | Example      | Bank | Port | Pin | Full Name |
|----------|--------------|------|------|-----|-----------|
| RK_PA0   | gpio3_PA0    | 3    | A    | 0   | GPIO3_A0  |
| RK_PA7   | gpio3_PA7    | 3    | A    | 7   | GPIO3_A7  |
| RK_PB0   | gpio3_PB0    | 3    | B    | 0   | GPIO3_B0  |
| RK_PC5   | gpio0_PC5    | 0    | C    | 5   | GPIO0_C5  |
| RK_PD3   | gpio4_PD3    | 4    | D    | 3   | GPIO4_D3  |

## How to Determine Your Hardware Settings

1. **Check RK628 Board Documentation** - Should specify I2C address and GPIO requirements
2. **Review Hardware Schematic** - Shows actual connections between RK628 and RK3566
3. **Radxa Zero 3W Pinout** - Check which pins are available on your board
4. **Reference Designs** - Look at other RK3566/RK3568 boards using RK628

## Build and Install

```bash
# 1. Navigate to kernel directory
cd /Volumes/CaseSensitive/git/rockchip-linux/kernel

# 2. Build device tree
make dtbs

# 3. Install (adjust path for your system)
sudo cp arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3w.dtb /boot/dtbs/rockchip/

# 4. Reboot
sudo reboot
```

## Quick Test After Boot

```bash
# Check I2C detection on bus 2 (camera I2C on Radxa Zero 3W)
sudo i2cdetect -y 2

# Check kernel messages
dmesg | grep -i rk628

# List video devices
v4l2-ctl --list-devices
```

## If It Doesn't Work

1. **I2C not detected:** Wrong bus or address
2. **Driver errors:** GPIO conflicts or incorrect pin assignments
3. **No video device:** Check kernel logs with `dmesg | grep -i rk628`

📖 **See RK628-CSI-SETUP.md for detailed troubleshooting!**

## Disabling RK628 (if needed)

Comment out the include in `rk3566-radxa-zero-3w.dts`:

```dts
#include "rk3566-radxa-zero-3.dtsi"
// #include "rk3566-radxa-zero-3w-rk628-hdmi2csi.dtsi"  /* ← Comment out */
```

## Common I2C Buses on 40-Pin Header

Check Radxa Zero 3W documentation, but typically:
- **I2C2** - Often on 40-pin header (pins 3/5 or 27/28)
- **I2C3** - May be available
- **I2C4** - May be available

## Need Help?

- 📖 Read the full guide: `RK628-CSI-SETUP.md`
- 🌐 Radxa Wiki: https://wiki.radxa.com/Zero/3w
- 📋 Check your RK628 board documentation for pin assignments
