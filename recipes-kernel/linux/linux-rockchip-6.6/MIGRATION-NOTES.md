# DTS Migration to Non-Monolithic Structure

## Overview
Converted Radxa Zero 3W DTS from monolithic single-file to maintainable split structure matching mainline linux-yocto 6.6 architecture.

## File Structure

### Before (Monolithic)
```
rk3566-radxa-zero-3w.dts (900+ lines - everything in one file)
```

### After (Split Architecture)
```
rk3566-radxa-zero-3.dtsi      - Common base for all Zero 3 variants
rk3566-radxa-zero-3w.dts       - 3W-specific configuration (WiFi/BT/eMMC)
rk3566-radxa-zero-3e.dts       - (future) 3E-specific configuration
```

## Critical Fixes Applied

### 1. ✅ Fixed Regulator Hierarchy
**Problem:** Direct PMIC regulator usage without proper parent chain

**Before:**
```dts
vcc5v0_sys → vcc3v3_sys (fixed) → RK817 DCDC_REG4 (vdd_npu) ❌
```

**After (Correct):**
```dts
vcc_sys (5V) → RK817 DCDC_REG4 (vcc3v3_sys) → fixed regulators
                   ↓ LDO_REG7 (vcc_1v8_p) → vcc_1v8, vcca_1v8, vcca1v8_image
```

### 2. ✅ Fixed DCDC_REG4 Usage
**Before:** `vdd_npu` (WRONG - NPU-only power)  
**After:** `vcc3v3_sys` (CORRECT - main 3.3V system rail)

This was causing ALL 3.3V peripherals to fail!

### 3. ✅ Fixed IO-Domains
**Before:** `pmuio2-supply = <&vcc3v3_pmu>` ❌ WRONG VOLTAGE!  
**After:** `pmuio2-supply = <&vcca1v8_pmu>` ✅ Correct 1.8V

### 4. ✅ Changed CPU Regulator
**Before:** `tcs,tcs4525` @ 0x1c  
**After:** `rockchip,rk8600` @ 0x40

Matches working mainline configuration.

### 5. ✅ Fixed RK817 PMIC Supply Chain
**Before:** `vcc9-supply = <&vcc3v3_sys>` ❌  
**After:** `vcc9-supply = <&vcc5v_midu>` ✅ (BOOST regulator)

### 6. ✅ Enabled eMMC Support
Added full eMMC configuration to match actual hardware:
```dts
&sdhci {
    bus-width = <8>;
    mmc-hs200-1_8v;
    vmmc-supply = <&vcc_3v3>;
    vqmmc-supply = <&vcc_1v8>;
    status = "okay";
};
```

## Benefits

### Maintainability
- **Shared Code:** Common configuration in dtsi (PMIC, regulators, HDMI, USB)
- **Variant-Specific:** Only WiFi/BT/eMMC in board DTS
- **Easy Extension:** New variants (3E) just need simple overlay DTS

### Correctness
- **Matches Mainline:** Architecture identical to working linux-yocto 6.6
- **Power Rails:** Proper regulator hierarchy and dependencies
- **IO-Domains:** Correct voltage levels for all domains

### Debugging
- **Clear Separation:** Easy to identify board-specific vs common issues
- **Reduced Duplication:** Single source of truth for PMIC configuration
- **Better Diffs:** Changes show only what's different per variant

## MMC Device Mapping

```
mmc0 = &sdmmc0  → SD Card slot (common to all variants)
mmc1 = &sdhci   → eMMC (3W specific)
mmc2 = &sdmmc1  → WiFi SDIO (3W specific)
```

## What Should Work Now

✅ **SD Card** - Correct regulator chain and io-domains  
✅ **eMMC** - Properly enabled and configured  
✅ **WiFi/Bluetooth** - Correct power sequencing  
✅ **HDMI** - Correct power supplies (avdd-0v9, avdd-1v8)  
✅ **USB** - Correct USB PHY configuration  
✅ **CPU Frequency Scaling** - vdd_cpu regulator now accessible  
✅ **IO-Domains** - All 7 domains with correct voltage rails  

## Testing Checklist

- [ ] Boot and verify SD card detection
- [ ] Verify eMMC detection and read/write
- [ ] Test WiFi connectivity
- [ ] Test Bluetooth pairing
- [ ] Verify HDMI output
- [ ] Check CPU frequency scaling (/sys/devices/system/cpu/cpu0/cpufreq/)
- [ ] Monitor dmesg for regulator probe errors
- [ ] Verify all MMC devices enumerated correctly

## Migration Path for Other Variants

To add Zero 3E support:
1. Create `rk3566-radxa-zero-3e.dts`
2. Include the common `rk3566-radxa-zero-3.dtsi`
3. Add only Ethernet-specific configuration
4. No need to duplicate PMIC, regulators, HDMI, etc.

## Reference

**Working Source:** `/Volumes/CaseSensitive/git/yocto/linux-yocto/arch/arm64/boot/dts/rockchip/`
- `rk3566-radxa-zero-3.dtsi` (common base)
- `rk3566-radxa-zero-3w.dts` (WiFi variant)

This architecture is proven to work on mainline Linux 6.6.
