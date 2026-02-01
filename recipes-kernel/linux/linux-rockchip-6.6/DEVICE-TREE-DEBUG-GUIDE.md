# Device Tree Overlay Debugging Guide

## Overview

This guide provides detailed instructions for loading device trees and overlays from U-Boot with comprehensive logging for debugging overlay issues.

## Quick Diagnostics

### 1. Check Current Boot Configuration

```bash
# Check current device tree
cat /proc/device-tree/model

# Check which device tree was loaded
dmesg | grep -i "machine model"

# List loaded overlays (if any)
ls /sys/firmware/devicetree/base/fragment@* 2>/dev/null && echo "Overlays detected" || echo "No overlays loaded"

# Check for device tree errors
dmesg | grep -iE "device.tree|overlay|dtb|fdt"
```

### 2. Verify Files on Boot Partition

```bash
# List available device trees
ls -lh /boot/*.dtb

# List available overlays
ls -lh /boot/overlays/*.dtbo
```

## U-Boot Device Tree Loading

### Method 1: Using extlinux.conf (Recommended)

#### Basic Configuration (No Overlay)

Edit `/boot/extlinux/extlinux.conf`:

```conf
label Radxa Zero 3E - No Overlay
    kernel /Image
    fdt /rk3566-radxa-zero-3e.dtb
    append root=/dev/mmcblk0p2 rootwait console=ttyS2,1500000n8 loglevel=7
```

#### With Overlay

```conf
label Radxa Zero 3E - With Overlay
    kernel /Image
    fdt /rk3566-radxa-zero-3.dtb
    fdtoverlays /overlays/rk3566-radxa-zero-3e-board.dtbo
    append root=/dev/mmcblk0p2 rootwait console=ttyS2,1500000n8 loglevel=7
```

#### With Multiple Overlays

```conf
label Radxa Zero 3E - Full Stack
    kernel /Image
    fdt /rk3566-radxa-zero-3.dtb
    fdtoverlays /overlays/rk3566-radxa-zero-3e-board.dtbo /overlays/rk3566-radxa-zero-3w-imx708.dtbo
    append root=/dev/mmcblk0p2 rootwait console=ttyS2,1500000n8 loglevel=7
```

### Method 2: U-Boot Manual Commands

#### At U-Boot Prompt

```bash
# Stop autoboot by pressing any key at U-Boot prompt

# Load kernel
load mmc 0:1 ${kernel_addr_r} Image

# Load base device tree
load mmc 0:1 ${fdt_addr_r} rk3566-radxa-zero-3.dtb

# Apply overlay (OPTIONAL)
load mmc 0:1 ${fdtoverlay_addr_r} overlays/rk3566-radxa-zero-3e-board.dtbo
fdt addr ${fdt_addr_r}
fdt resize 8192
fdt apply ${fdtoverlay_addr_r}

# Set boot arguments with debug logging
setenv bootargs root=/dev/mmcblk0p2 rootwait console=ttyS2,1500000n8 loglevel=7 debug

# Boot
booti ${kernel_addr_r} - ${fdt_addr_r}
```

#### Save U-Boot Environment

```bash
# If you want to make changes permanent
setenv fdtfile rk3566-radxa-zero-3.dtb
setenv fdtoverlays overlays/rk3566-radxa-zero-3e-board.dtbo
saveenv
```

## Kernel Debug Parameters

### Essential Debug Parameters

Add these to your `append` line in extlinux.conf:

```conf
append root=/dev/mmcblk0p2 rootwait console=ttyS2,1500000n8 \
       loglevel=8 \
       debug \
       initcall_debug \
       log_buf_len=8M
```

### Parameter Explanations

| Parameter | Purpose | Values |
|-----------|---------|---------|
| `loglevel=N` | Kernel message verbosity | 0=panic only, 7=debug, 8=everything |
| `debug` | Enable debug messages | N/A |
| `initcall_debug` | Log driver init sequence | N/A |
| `log_buf_len=8M` | Increase log buffer size | Default too small for debug |
| `earlycon` | Early console output | `earlycon=uart8250,mmio32,0xfe660000` |
| `dyndbg="file drivers/of/* +p"` | Device tree dynamic debug | Verbose DT logging |

### Maximum Debug Configuration

```conf
label Radxa Zero 3E - MAX DEBUG
    kernel /Image
    fdt /rk3566-radxa-zero-3.dtb
    fdtoverlays /overlays/rk3566-radxa-zero-3e-board.dtbo
    append root=/dev/mmcblk0p2 rootwait \
           console=ttyS2,1500000n8 \
           earlycon=uart8250,mmio32,0xfe660000 \
           loglevel=8 \
           debug \
           initcall_debug \
           log_buf_len=16M \
           dyndbg="file drivers/of/* +p"
```

## Debugging Device Tree Issues

### Check Device Tree Structure

```bash
# Dump full device tree
dtc -I fs -O dts /sys/firmware/devicetree/base > /tmp/current.dts
cat /tmp/current.dts | less

# Check specific node
ls -la /sys/firmware/devicetree/base/ethernet@fe010000/
cat /sys/firmware/devicetree/base/ethernet@fe010000/status

# Check if overlay fragments exist
ls -la /sys/firmware/devicetree/base/fragment@*/
```

### Check Overlay Application

```bash
# Look for overlay application messages
dmesg | grep -i "overlay"
dmesg | grep -i "applying overlay"

# Check for errors
dmesg | grep -iE "error|fail|warn" | grep -i "device.tree\|dtb\|fdt\|overlay"
```

### Check Ethernet Specifically

```bash
# Check if ethernet device exists
ls -la /sys/class/net/

# Check ethernet driver
dmesg | grep -i "eth\|gmac\|stmmac"

# Check device tree ethernet node
ls -la /sys/firmware/devicetree/base/*ethernet*/
cat /sys/firmware/devicetree/base/ethernet@fe010000/status
cat /sys/firmware/devicetree/base/ethernet@fe010000/phy-mode
```

## Common Issues and Solutions

### Issue 1: Overlay Not Loading

**Symptoms:**
- No `/sys/firmware/devicetree/base/fragment@*` directories
- `dmesg` shows no overlay messages

**Solutions:**

1. **Check U-Boot overlay support:**
   ```bash
   # At U-Boot prompt
   fdt help
   # Should show 'apply' command
   ```

2. **Verify overlay file exists:**
   ```bash
   ls -lh /boot/overlays/rk3566-radxa-zero-3e-board.dtbo
   ```

3. **Check extlinux.conf syntax:**
   ```bash
   cat /boot/extlinux/extlinux.conf
   # Ensure no typos in fdtoverlays path
   ```

4. **Try loading manually from U-Boot** (see Method 2 above)

### Issue 2: Overlay Loads But Ethernet Not Working

**Symptoms:**
- Overlay fragments present
- No `eth0` interface

**Diagnosis:**

```bash
# Check if gmac1 device exists
ls -la /sys/firmware/devicetree/base/ethernet@fe010000/

# Check status property
cat /sys/firmware/devicetree/base/ethernet@fe010000/status
# Should be "okay"

# Check driver logs
dmesg | grep -i stmmac
```

**Solutions:**

1. **Check PHY reset GPIO:**
   ```bash
   # GPIO should be exported
   cat /sys/firmware/devicetree/base/ethernet@fe010000/mdio/ethernet-phy@1/reset-gpios
   ```

2. **Verify power supply:**
   ```bash
   cat /sys/firmware/devicetree/base/ethernet@fe010000/phy-supply
   ```

3. **Check clock configuration:**
   ```bash
   dmesg | grep -i "assigned-clock"
   ```

### Issue 3: Base DTB vs Overlay Conflicts

**Symptoms:**
- Overlay loads but features don't work
- Duplicate node warnings in dmesg

**Solution - Use Complete DTB Instead:**

```conf
label Radxa Zero 3E - Complete DTB
    kernel /Image
    fdt /rk3566-radxa-zero-3e.dtb
    # NO fdtoverlays line
    append root=/dev/mmcblk0p2 rootwait console=ttyS2,1500000n8 loglevel=7
```

### Issue 4: Overlay Syntax Errors

**Symptoms:**
```
Failed to apply overlay
Error: FDT_ERR_BADSTRUCTURE
```

**Validation:**

```bash
# Decompile overlay to check syntax
dtc -I dtb -O dts /boot/overlays/rk3566-radxa-zero-3e-board.dtbo

# Check for errors in output
```

## Serial Console Access

### Hardware Setup

Connect USB-TTL adapter to UART2:
- **TX** → GPIO0_D0 (Pin 8)
- **RX** → GPIO0_D1 (Pin 10)  
- **GND** → GND

### Software Access

```bash
# Linux/Mac
screen /dev/ttyUSB0 1500000

# Or using picocom
picocom -b 1500000 /dev/ttyUSB0

# Windows
# Use PuTTY or TeraTerm
# Baud: 1500000, 8N1
```

### Capturing Boot Log

```bash
# Capture to file
screen -L -Logfile boot.log /dev/ttyUSB0 1500000

# Power cycle the board
# Watch boot process
# Press Ctrl+A, K to exit
# View log: cat boot.log
```

## Testing Procedures

### Test 1: Baseline - Complete DTB

```conf
label Test 1 - Complete DTB
    kernel /Image
    fdt /rk3566-radxa-zero-3e.dtb
    append root=/dev/mmcblk0p2 rootwait console=ttyS2,1500000n8 loglevel=7
```

**Expected:** Ethernet works ✅

### Test 2: Generic Base Only

```conf
label Test 2 - Base Only
    kernel /Image
    fdt /rk3566-radxa-zero-3.dtb
    append root=/dev/mmcblk0p2 rootwait console=ttyS2,1500000n8 loglevel=7
```

**Expected:** No ethernet ❌

### Test 3: Base + Overlay

```conf
label Test 3 - Base + Overlay
    kernel /Image
    fdt /rk3566-radxa-zero-3.dtb
    fdtoverlays /overlays/rk3566-radxa-zero-3e-board.dtbo
    append root=/dev/mmcblk0p2 rootwait console=ttyS2,1500000n8 loglevel=7
```

**Expected:** Ethernet works ✅

## Collecting Debug Information

### Full Debug Report

```bash
#!/bin/bash
# Save as /tmp/dt-debug.sh

echo "=== Device Tree Debug Report ===" > /tmp/dt-report.txt
echo "" >> /tmp/dt-report.txt

echo "1. BOOT CONFIGURATION" >> /tmp/dt-report.txt
cat /boot/extlinux/extlinux.conf >> /tmp/dt-report.txt
echo "" >> /tmp/dt-report.txt

echo "2. DEVICE TREE FILES" >> /tmp/dt-report.txt
ls -lh /boot/*.dtb >> /tmp/dt-report.txt
ls -lh /boot/overlays/*.dtbo >> /tmp/dt-report.txt
echo "" >> /tmp/dt-report.txt

echo "3. LOADED DEVICE TREE" >> /tmp/dt-report.txt
cat /proc/device-tree/model >> /tmp/dt-report.txt
echo "" >> /tmp/dt-report.txt

echo "4. OVERLAY FRAGMENTS" >> /tmp/dt-report.txt
ls -la /sys/firmware/devicetree/base/fragment@* >> /tmp/dt-report.txt 2>&1
echo "" >> /tmp/dt-report.txt

echo "5. ETHERNET STATUS" >> /tmp/dt-report.txt
ip link show >> /tmp/dt-report.txt
echo "" >> /tmp/dt-report.txt

echo "6. DEVICE TREE MESSAGES" >> /tmp/dt-report.txt
dmesg | grep -iE "device.tree|overlay|dtb|fdt" >> /tmp/dt-report.txt
echo "" >> /tmp/dt-report.txt

echo "7. ETHERNET MESSAGES" >> /tmp/dt-report.txt
dmesg | grep -iE "eth|gmac|stmmac|phy" >> /tmp/dt-report.txt
echo "" >> /tmp/dt-report.txt

echo "Report saved to /tmp/dt-report.txt"
cat /tmp/dt-report.txt
```

## U-Boot Environment Variables

### View Current Settings

```bash
# At U-Boot prompt
printenv

# Key variables
printenv fdtfile
printenv fdtoverlays
printenv bootargs
printenv boot_targets
```

### Useful U-Boot Commands

```bash
# List files on boot partition
ls mmc 0:1

# List overlay directory
ls mmc 0:1 overlays/

# Check FDT in memory
fdt addr ${fdt_addr_r}
fdt print /

# Reset environment to defaults
env default -a
saveenv
```

## Rockchip-Specific Notes

### Clock Configuration

The RK3566 GMAC1 requires specific clock setup. In overlays, clock assignments may not work due to preprocessor limitations. Solutions:

1. **Use complete DTB** - All clocks pre-configured
2. **Base DTB has clock setup** - Overlay just enables interface
3. **Remove assigned-clocks from overlay** - Already handled in base

### Reset GPIO

The ethernet PHY reset (GPIO3_C0) must be:
- Configured as GPIO (not alternate function)
- Proper timing (20ms assert, 50ms deassert)
- Active-low polarity

## Additional Resources

### Kernel Documentation

```bash
# On target
zcat /proc/config.gz | grep -i "OF\|DTB\|OVERLAY"

# Check overlay support
zcat /proc/config.gz | grep CONFIG_OF_OVERLAY
# Should be: CONFIG_OF_OVERLAY=y
```

### U-Boot Documentation

- Device Tree: https://u-boot.readthedocs.io/en/latest/develop/devicetree/index.html
- Overlays: https://u-boot.readthedocs.io/en/latest/usage/fdt_overlays.html

### Rockchip Resources

- RK3566 TRM: Check clock and pinmux requirements
- Vendor kernel: `/Volumes/CaseSensitive/git/rockchip-linux/kernel`

## Quick Reference

### extlinux.conf Syntax

```conf
label <Description>
    kernel <path to Image>
    fdt <path to base DTB>
    fdtoverlays <path to overlay1> <path to overlay2> ...
    append <kernel parameters>
```

### Debug Kernel Parameters (One Line)

```
console=ttyS2,1500000n8 earlycon=uart8250,mmio32,0xfe660000 loglevel=8 debug initcall_debug log_buf_len=16M
```

### Quick Ethernet Test

```bash
# Check interface
ip link show eth0

# Bring up
sudo ip link set eth0 up

# Get IP
sudo dhclient eth0

# Test
ping -c 4 8.8.8.8
```

## Support Checklist

When reporting issues, provide:

- [ ] Full boot log (from serial console)
- [ ] Output of `cat /boot/extlinux/extlinux.conf`
- [ ] Output of `ls -lh /boot/*.dtb /boot/overlays/*.dtbo`
- [ ] Output of `dmesg | grep -iE "device.tree|overlay"`
- [ ] Output of `dmesg | grep -iE "eth|gmac|stmmac"`
- [ ] Output of `ip link show`
- [ ] Output of `cat /proc/device-tree/model`
- [ ] Hardware variant (3W or 3E)
