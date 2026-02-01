# Multi-Board Device Tree Overlay System

## Overview

The Radxa Zero 3 series uses a **unified overlay system** that allows a single kernel image to boot on multiple board variants:

- **Zero 3** - Generic base board (common hardware)
- **Zero 3W** - WiFi/Bluetooth variant
- **Zero 3E** - Gigabit Ethernet variant

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Single Kernel Image                          │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
         ┌──────▼─────┐ ┌────▼────┐ ┌──────▼─────┐
         │  Base DTB  │ │3W Overlay│ │3E Overlay │
         │ rk3566-    │ │WiFi/BT   │ │Ethernet   │
         │ radxa-     │ │          │ │           │
         │ zero-3.dtb │ └──────────┘ └───────────┘
         │            │
         │(+cam_pins) │
         └────────────┘
              │
        ┌─────▼──────┐
        │IMX708      │
        │Overlay     │
        │(Optional)  │
        └────────────┘
```

## Files Built

After `bitbake linux-rockchip`, you'll have:

### Base Device Tree

- `rk3566-radxa-zero-3.dtb` - Generic base with common hardware + camera pinctrl

### Board Overlays (Required - Select One)

- `rk3566-radxa-zero-3w-board.dtbo` - WiFi/BT functionality
- `rk3566-radxa-zero-3e-board.dtbo` - Ethernet functionality

### Camera Overlay (Optional)

- `rk3566-radxa-zero-3-imx708.dtbo` - IMX708 camera sensor (works on both 3W and 3E)

## Boot Configuration (extlinux)

The system provides **2 boot options** via extlinux menu:

### Default Boot Menu

```
DEFAULT arcadia-3w
TIMEOUT 30
MENU TITLE Arcadia Linux Boot Menu

LABEL arcadia-3w
    MENU LABEL Radxa Zero 3W (WiFi)
    LINUX /Image-initramfs-radxa-zero3w.bin
    FDT /rk3566-radxa-zero-3.dtb
    FDTOVERLAYS /rockchip/rk3566-radxa-zero-3w-board.dtbo
    APPEND root=LABEL=rootfs rootwait rw ...

LABEL arcadia-3e
    MENU LABEL Radxa Zero 3E (Ethernet)
    LINUX /Image-initramfs-radxa-zero3w.bin
    FDT /rk3566-radxa-zero-3.dtb
    FDTOVERLAYS /rockchip/rk3566-radxa-zero-3e-board.dtbo
    APPEND root=LABEL=rootfs rootwait rw ...
```

**Benefits:**

- Same image works on both boards
- Select board variant at boot time
- No rebuild required

## What Each Component Contains

### Base DTB (`rk3566-radxa-zero-3.dtb`)

**From rk3566-radxa-zero-3.dtsi:**

- CPU, RAM, PMIC configuration
- I2C, SPI, UART interfaces
- MIPI CSI-2 interface
- GPIO controllers
- All common peripherals

**From rk3566-radxa-zero-3.dts:**

- `cam_pins` pinctrl (GPIO3_C6 powerdown, GPIO3_C5 reset)
- Shared by both 3W and 3E for camera support

### Zero 3W Board Overlay (`rk3566-radxa-zero-3w-board.dtbo`)

- WiFi/Bluetooth SDIO interface (sdmmc1)
- WiFi/BT power sequencing (sdio_pwrseq)
- UART1 for Bluetooth with RTS/CTS
- WiFi/BT pinctrl:
  - `wifi_reg_on_h` (GPIO0_PC0)
  - `wifi_wake_host_h` (GPIO0_PB7)
  - `bt_reg_on_h` (GPIO0_PC1)
  - `bt_wake_host_h` (GPIO0_PB3)
  - `host_wake_bt_h` (GPIO0_PB4)
- MMC aliases for WiFi

### Zero 3E Board Overlay (`rk3566-radxa-zero-3e-board.dtbo`)

- Gigabit Ethernet (GMAC1) with RGMII
- Ethernet PHY configuration (Realtek RTL8211F)
- PHY reset timing
- Ethernet pinctrl:
  - `gmac1_rstn` (GPIO3_PC0)
- MDIO bus configuration
- Clock assignments for GMAC1

### IMX708 Camera Overlay (`rk3566-radxa-zero-3-imx708.dtbo`)

- Sony IMX708 12MP camera sensor
- I2C2 interface (address 0x10)
- MIPI CSI-2 data lanes configuration
- Camera clocking (24MHz MCLK)
- References `<&cam_pins>` from base DTB
- Works on **both 3W and 3E** boards

## GPIO and Pinctrl Design

### Shared Pinctrl (in base DTS)

✅ **Camera pins** - Both boards can use cameras

- `cam_pins` in rk3566-radxa-zero-3.dts
- Used by IMX708 overlay
- Ensures camera overlay is board-agnostic

### Board-Specific Pinctrl (in overlays)

✅ **3W Overlay** - WiFi/BT GPIOs only on 3W  
✅ **3E Overlay** - Ethernet GPIO only on 3E

**Why this design?**

- Camera connector exists on both 3W and 3E hardware
- IMX708 overlay can work on either board without modification
- Board-specific features stay isolated in their overlays

## Usage Scenarios

### Scenario 1: Zero 3W with WiFi/BT (Default)

Boot menu automatically selects 3W:

```
DEFAULT arcadia-3w
```

No manual configuration needed - just boot the 3W board.

**Verification:**

```bash
# WiFi interface
iwconfig

# Bluetooth controller
hciconfig

# SDIO device
ls /sys/bus/sdio/devices/
```

### Scenario 2: Zero 3E with Ethernet

Select "Radxa Zero 3E (Ethernet)" from boot menu, or change default:

```bash
# Edit /boot/extlinux/extlinux.conf
DEFAULT arcadia-3e
```

**Verification:**

```bash
# Ethernet interface
ip link show eth0

# PHY status
ethtool eth0

# Check link speed
ethtool eth0 | grep Speed
```

### Scenario 3: Adding Camera Support (Manual)

Camera overlay is **not in boot menu** - must be loaded manually.

#### Option A: Runtime Loading (fdtoverlay command)

```bash
# Install dtc package for fdtoverlay
# Merge camera overlay at runtime
fdtoverlay -i /boot/rk3566-radxa-zero-3.dtb \
           -o /boot/rk3566-radxa-zero-3-camera.dtb \
           /boot/rockchip/rk3566-radxa-zero-3w-board.dtbo \
           /boot/rockchip/rk3566-radxa-zero-3-imx708.dtbo

# Update extlinux.conf to use merged DTB
# Change: FDT /rk3566-radxa-zero-3-camera.dtb
```

#### Option B: Modify extlinux.conf (Permanent)

```bash
# Edit /boot/extlinux/extlinux.conf
LABEL arcadia-3w-camera
    MENU LABEL Radxa Zero 3W (WiFi) + IMX708 Camera
    LINUX /Image-initramfs-radxa-zero3w.bin
    FDT /rk3566-radxa-zero-3.dtb
    FDTOVERLAYS /rockchip/rk3566-radxa-zero-3w-board.dtbo /rockchip/rk3566-radxa-zero-3-imx708.dtbo
    APPEND root=LABEL=rootfs rootwait rw ...
```

**Note**: U-Boot must support multiple `FDTOVERLAYS` for Option B.

**Verification:**

```bash
# I2C2 should show camera at 0x10
i2cdetect -y 2

# V4L2 device
ls /dev/video*

# Camera info
v4l2-ctl --list-devices
```

## Advantages of Current System

### 1. Unified Image

- ✅ One kernel image for both 3W and 3E
- ✅ Reduced build time and storage
- ✅ Simplified CI/CD pipeline

### 2. Boot-Time Board Selection

- ✅ Same SD card works on both boards
- ✅ Select variant from boot menu
- ✅ No reflashing required

### 3. Modular Camera Support

- ✅ Camera overlay works on both 3W and 3E
- ✅ Optional - doesn't bloat default boot
- ✅ Easy to add/remove

### 4. Clean Architecture

- ✅ Base DTB has only common hardware
- ✅ Board overlays are self-contained
- ✅ No code duplication

## Switching Between Boards

### Same SD Card, Different Boards

**Just move the SD card!**  
The boot menu will let you select the correct variant:

1. Insert SD card into board
2. Power on
3. Select from boot menu:
   - "Radxa Zero 3W (WiFi)" for 3W board
   - "Radxa Zero 3E (Ethernet)" for 3E board

### Change Default Boot Option

```bash
# SSH into the board
ssh root@<board-ip>

# Edit boot config
nano /boot/extlinux/extlinux.conf

# Change DEFAULT line:
DEFAULT arcadia-3e   # For 3E
# or
DEFAULT arcadia-3w   # For 3W

# Reboot
reboot
```

## Verification Commands

### Check Device Tree

```bash
# See board model
cat /sys/firmware/devicetree/base/model

# Check compatible string
cat /sys/firmware/devicetree/base/compatible

# List loaded overlays (if supported)
ls /sys/firmware/devicetree/overlays/
```

### Zero 3W Verification

```bash
# WiFi should be present
iwconfig
nmcli device

# Bluetooth should be available
hciconfig
bluetoothctl list

# SDIO WiFi device
ls /sys/bus/sdio/devices/
dmesg | grep -i wifi
```

### Zero 3E Verification

```bash
# Ethernet interface
ip link show eth0
ethtool eth0

# Ethernet PHY
cat /sys/class/net/eth0/phydev/phy_id

# Link status
cat /sys/class/net/eth0/carrier
```

### Camera Verification (if overlay loaded)

```bash
# I2C2 camera detection
i2cdetect -y 2
# Should show device at 0x10

# V4L2 devices
ls -la /dev/video*

# Camera info
media-ctl -p
v4l2-ctl --list-devices
```

## Troubleshooting

### Wrong Board Features Active

**Problem**: WiFi works on 3E or Ethernet on 3W

**Solution**: Wrong overlay selected

```bash
# Check current boot config
cat /boot/extlinux/extlinux.conf | grep -A5 "^DEFAULT"

# Verify loaded device tree
cat /sys/firmware/devicetree/base/model

# Change DEFAULT to correct board variant
```

### Overlay Not Loading

**Problem**: Boot shows base DTB but no board features

**Solution 1**: Check extlinux.conf syntax

```bash
# Verify FDTOVERLAYS line exists
grep FDTOVERLAYS /boot/extlinux/extlinux.conf

# Check file paths are correct
ls /boot/rockchip/*.dtbo
```

**Solution 2**: Check U-Boot overlay support

```bash
# U-Boot must have CONFIG_OF_LIBFDT_OVERLAY=y
# Check U-Boot version
cat /proc/cmdline
```

### Camera Not Detected

**Problem**: No /dev/video\* devices

**Checklist**:

1. ✅ Is IMX708 overlay loaded?
2. ✅ Is camera physically connected?
3. ✅ Is FFC cable orientation correct?
4. ✅ Check I2C2: `i2cdetect -y 2` (should show 0x10)
5. ✅ Check kernel config: `CONFIG_VIDEO_IMX708=m`
6. ✅ Check dmesg: `dmesg | grep imx708`

### Both WiFi and Ethernet Present (Error!)

**Problem**: Both overlays loaded simultaneously

**This is incorrect!** 3W and 3E overlays are mutually exclusive.

**Solution**: Only load ONE board overlay at boot:

```bash
# Correct:
FDTOVERLAYS /rockchip/rk3566-radxa-zero-3w-board.dtbo

# OR:
FDTOVERLAYS /rockchip/rk3566-radxa-zero-3e-board.dtbo

# NOT BOTH!
```

## Development

### Creating New Board Variant

To add a new variant (e.g., Zero 3X):

1. **Create overlay source**: `rk3566-radxa-zero-3x-board.dtso`
2. **Add to kernel recipe**: `linux-rockchip_6.6.bbappend`
   ```bitbake
   SRC_URI:append = " file://rk3566-radxa-zero-3x-board.dtso"
   KERNEL_DEVICETREE:append = " rockchip/rk3566-radxa-zero-3x-board.dtbo"
   ```
3. **Add to do_configure**: Copy dtso to kernel source
4. **Update IMAGE_BOOT_FILES**: Deploy to boot partition
5. **Add extlinux entry**: New boot menu option

### Modifying Existing Overlay

```bash
# 1. Edit overlay source
cd meta-radxazero3w/recipes-kernel/linux/linux-rockchip-6.6/
nano rk3566-radxa-zero-3w-board.dtso

# 2. Rebuild kernel
bitbake -c clean linux-rockchip
bitbake linux-rockchip

# 3. Deploy new overlay
cp tmp/deploy/images/radxa-zero3w/rk3566-radxa-zero-3w-board.dtbo /boot/rockchip/

# 4. Reboot to test
reboot
```

## File Location Summary

### Source Files (meta-radxazero3w)

```
recipes-kernel/linux/linux-rockchip-6.6/
├── rk3566-radxa-zero-3.dtsi           # Common hardware (DTSI)
├── rk3566-radxa-zero-3.dts            # Base DTS + cam_pins
├── rk3566-radxa-zero-3w-board.dtso    # 3W WiFi/BT overlay
├── rk3566-radxa-zero-3e-board.dtso    # 3E Ethernet overlay
└── rk3566-radxa-zero-3-imx708.dtso    # Camera overlay (optional)
```

### Deployed Files (Boot Partition)

```
/boot/
├── Image-initramfs-radxa-zero3w.bin   # Kernel image
├── rk3566-radxa-zero-3.dtb            # Base device tree
├── extlinux/
│   └── extlinux.conf                  # Boot menu config
└── rockchip/
    ├── rk3566-radxa-zero-3w-board.dtbo    # 3W overlay
    ├── rk3566-radxa-zero-3e-board.dtbo    # 3E overlay
    └── rk3566-radxa-zero-3-imx708.dtbo    # Camera overlay
```

## Best Practices

1. ✅ **Use boot menu** for board selection - easiest for end users
2. ✅ **One board overlay** per boot - never mix 3W and 3E
3. ✅ **Camera overlay is optional** - load only when needed
4. ✅ **Test on actual hardware** - both 3W and 3E boards
5. ✅ **Document custom configurations** in your deployment notes
6. ✅ **Keep base DTB minimal** - only common hardware and camera pins

## Migration from Old System

### Old System (Deprecated)

- Separate complete DTBs: `rk3566-radxa-zero-3w.dtb`, `rk3566-radxa-zero-3e.dtb`
- Board-specific DTS files that duplicated common hardware
- Camera overlay tied to 3W: `rk3566-radxa-zero-3w-imx708.dtbo`
- RK628 overlay (removed)

### New System (Current)

- Single base DTB: `rk3566-radxa-zero-3.dtb`
- Board-specific overlays only contain unique features
- Camera overlay is board-agnostic: `rk3566-radxa-zero-3-imx708.dtbo`
- Cleaner, more maintainable architecture

### What Changed

- ✅ Deleted: `rk3566-radxa-zero-3w.dts` and `rk3566-radxa-zero-3e.dts`
- ✅ Renamed: `rk3566-radxa-zero-3w-imx708.dtso` → `rk3566-radxa-zero-3-imx708.dtso`
- ✅ Removed: RK628 HDMI-to-CSI support
- ✅ Added: `cam_pins` to base DTS for camera support on both boards

## References

- **Device Tree Specification**: https://www.devicetree.org/
- **Device Tree Overlays**: https://www.kernel.org/doc/Documentation/devicetree/overlay-notes.txt
- **U-Boot Overlays**: https://docs.u-boot.org/en/latest/usage/fdt_overlays.html
- **Yocto Device Tree**: https://docs.yoctoproject.org/kernel-dev/common.html

## Support

For issues:

- **Boot menu not appearing**: Check U-Boot version and extlinux support
- **3W WiFi not working**: Verify AIC8800 driver and firmware loaded
- **3E Ethernet not working**: Check PHY detection and cable
- **Camera not detected**: Ensure overlay loaded and FFC cable correct
- **Wrong features active**: Verify correct board overlay selected
