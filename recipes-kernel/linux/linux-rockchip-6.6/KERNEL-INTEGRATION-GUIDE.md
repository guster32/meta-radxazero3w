# Radxa Zero 3W DTS Integration Guide

## Issue Summary

You're experiencing "undeclared label" errors when copying the Yocto DTS files to the rockchip-linux kernel source tree, even though:
- ✅ The files exist in both locations
- ✅ All labels ARE properly defined in the kernel's `rk356x.dtsi`
- ✅ The Yocto build works correctly

## Root Cause Analysis

After comparing both trees, I found that **the rockchip-linux kernel ALREADY contains these files**:
- `arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3w.dts` ✅ EXISTS
- `arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3.dtsi` ✅ EXISTS

### Key Differences Between Versions

#### 1. **Kernel Version** (Simpler, Mainline-focused)
- Uses `rockchip,rk8600` CPU regulator
- Minimal GPU configuration
- Basic device enablement
- No video codec/NPU configuration

#### 2. **Yocto Version** (Enhanced, Vendor-focused)
- Uses `silergy,syr827` CPU regulator
- Extensive GPU OPP table customization
- Video codec support (`vdpu`, `vepu`, `rkvenc`, `rkvdec`, `jpegd`)
- NPU/RGA hardware acceleration
- GIC MSI controller modifications for PCIe
- Custom GPU compatibility override to `arm,mali-bifrost`

## Why Compilation Might Fail

### Likely Issues:

1. **Base DTSI Incompatibility**
   - The yocto version expects vendor-specific nodes that may not exist in your kernel version
   - Missing nodes: `&vdpu`, `&vepu_mmu`, `&mpp_srv`, `&rkvenc`, `&bus_npu`, `&rknpu_mmu`, etc.

2. **Kernel Version Mismatch**
   - Yocto may be using a different 6.6.x point release
   - Vendor patches may differ between kernels

3. **Missing Vendor Extensions**
   - The yocto DTSI references rockchip vendor-specific features
   - Check if your kernel has vendor patches applied

## Verification Steps

### Check 1: Verify Base DTSI Has Required Nodes

```bash
cd /Volumes/CaseSensitive/git/rockchip-linux/kernel
grep -E "(vdpu|vepu|mpp_srv|rkvenc|rkvdec|jpegd|bus_npu|rknpu_mmu|rk_rga):" \
    arch/arm64/boot/dts/rockchip/rk356x.dtsi
```

**Expected:** Should find all these labels
**If missing:** Your kernel is missing vendor video/NPU nodes

### Check 2: Compare Kernel Git Versions

```bash
# In rockchip-linux kernel
git log --oneline -1

# Check what kernel version Yocto is using
grep "^LINUX_VERSION" \
    /Volumes/CaseSensitive/git/retrofactory/arcadia/recipes/retrofactory/meta-radxazero3w/recipes-kernel/linux/*.bb
```

### Check 3: Test Minimal DTS First

Try compiling just the kernel's existing version:

```bash
cd /Volumes/CaseSensitive/git/rockchip-linux/kernel
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- rockchip/rk3566-radxa-zero-3w.dtb
```

**If this works:** The kernel version is fine, yocto version has incompatible features
**If this fails:** Kernel has deeper issues

## Solution Options

### Option 1: Use Kernel's Existing Files (Recommended)

The kernel already has working DTS files. **Don't replace them.** Instead:

1. **Use the kernel's existing files as-is** for basic functionality
2. **Apply only necessary patches** from yocto version
3. **Create a minimal diff** between versions

### Option 2: Selectively Merge Features

Create a hybrid version that works with your kernel:

```bash
# Start with kernel version
cp arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3.dtsi \
   rk3566-radxa-zero-3-hybrid.dtsi

# Add only compatible features from yocto version:
# - Keep CPU regulator as-is (rk8600 vs syr827 - both should work)
# - Add GPU OPP table changes (safe)
# - Skip video codec nodes if they don't exist
# - Skip GIC MSI modifications if causing issues
```

### Option 3: Update Yocto to Use Kernel Version

**Modify your bbappend:**

```diff
 do_configure:prepend() {
-    # Copy common base dtsi
-    if [ -f ${WORKDIR}/rk3566-radxa-zero-3.dtsi ]; then
-        cp ${WORKDIR}/rk3566-radxa-zero-3.dtsi ${S}/arch/arm64/boot/dts/rockchip/
-    fi
-    
-    # Copy board-specific device tree
-    if [ -f ${WORKDIR}/rk3566-radxa-zero-3w.dts ]; then
-        cp ${WORKDIR}/rk3566-radxa-zero-3w.dts ${S}/arch/arm64/boot/dts/rockchip/
-    fi
+    # Don't copy - use kernel's existing version
+    # Only copy overlay
     
     # Copy IMX708 camera overlay
     if [ -f ${WORKDIR}/rk3566-radxa-zero-3w-imx708.dtso ]; then
         cp ${WORKDIR}/rk3566-radxa-zero-3w-imx708.dtso ${S}/arch/arm64/boot/dts/rockchip/
     fi
 }
```

Then create a patch for just the features you need.

## Recommended Approach

### Step 1: Verify What Works

```bash
cd /Volumes/CaseSensitive/git/rockchip-linux/kernel

# Compile existing kernel version
make ARCH=arm64 rockchip/rk3566-radxa-zero-3w.dtb

# If successful, check what it produces
dtc -I dtb -O dts arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3w.dtb \
    > /tmp/kernel-version.dts
```

### Step 2: Identify Missing Features

Compare what the kernel version has vs what you need:
- ✅ Basic board support (GPIO, UART, SD card)
- ✅ HDMI output
- ✅ GPU (basic)
- ❓ Video codecs (may be missing)
- ❓ NPU acceleration (may be missing)
- ❓ Advanced GPU OPP tuning (may be missing)

### Step 3: Create Targeted Patches

Rather than wholesale replacement, create patches for specific features:

```bash
# Example: Just add GPU OPP improvements
cat > 0003-arm64-dts-rk3566-zero3w-improve-gpu-opp.patch <<'EOF'
From: Your Name <email>
Date: Date
Subject: arm64: dts: rockchip: rk3566-radxa-zero-3: Improve GPU OPP table

Add optimized GPU OPP table with better voltage scaling.

diff --git a/arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3.dtsi b/arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3.dtsi
index xxxxx..yyyyy 100644
--- a/arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3.dtsi
+++ b/arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3.dtsi
@@ -XX,XX +XX,XX @@
 
+&gpu_opp_table {
+    opp-800000000 { 
+        opp-hz = /bits/ 64 <800000000>; 
+        opp-microvolt = <1000000>;
+    };
+};
+
EOF
```

## Specific Label Verification

All these labels **ARE DEFINED** in your kernel's `rk356x.dtsi`:

- ✅ `sdhci` - Line: `sdhci: mmc@fe310000`
- ✅ `sdmmc0` - Line: `sdmmc0: mmc@fe2b0000`
- ✅ `sdmmc1` - Line: `sdmmc1: mmc@fe2c0000`
- ✅ `uart1` - Line: `uart1: serial@fe650000`
- ✅ `pinctrl` - Line: `pinctrl: pinctrl`
- ✅ `combphy1_usq` - Line: `combphy1_usq: phy@fe830000`
- ✅ `gpu` - Line: `gpu: gpu@fde60000`
- ✅ `hdmi` - Line: `hdmi: hdmi@fe0a0000`
- ✅ `hdmi_in_vp0` - Line: `hdmi_in_vp0: endpoint@0`
- ✅ `hdmi_sound` - Line: `hdmi_sound: hdmi-sound`
- ✅ `i2c0` - Line: `i2c0: i2c@fdd40000`
- ✅ `vop` - Line: `vop: vop@fe040000`
- ✅ `vop_mmu` - Line: `vop_mmu: iommu@fe043e00`

**Conclusion:** The "missing label" error is NOT about these standard labels.

## Next Steps

1. **Run Check 1** above to see if vendor-specific nodes exist
2. **Try compiling the kernel's existing DTS** to verify it works
3. **Identify exactly which line causes the error** in your yocto version
4. **Report back** with the specific error message

The most likely issue is references to video codec/NPU nodes like:
- `&vdpu`, `&vdpu_mmu`
- `&vepu`, `&vepu_mmu`  
- `&mpp_srv`
- `&jpegd`, `&jpegd_mmu`
- `&rkvenc`, `&rkvenc_mmu`
- `&rkvdec`, `&rkvdec_mmu`
- `&rk_rga`
- `&bus_npu`, `&rknpu_mmu`

These are vendor-specific and may not exist in your kernel tree.

## Testing Command

```bash
# Compile with verbose errors to see exactly what's missing
cd /Volumes/CaseSensitive/git/rockchip-linux/kernel

# Copy yocto version temporarily
cp /Volumes/CaseSensitive/git/retrofactory/arcadia/recipes/retrofactory/meta-radxazero3w/recipes-kernel/linux/linux-rockchip-6.6/rk3566-radxa-zero-3.dtsi \
   arch/arm64/boot/dts/rockchip/rk3566-radxa-zero-3-test.dtsi

# Try to compile (it will show the exact error)
make ARCH=arm64 DTC_FLAGS="-@" rockchip/rk3566-radxa-zero-3w.dtb 2>&1 | tee /tmp/dts-compile-error.log

# Check the error
cat /tmp/dts-compile-error.log
```

Share the error log and I can provide a precise fix!
