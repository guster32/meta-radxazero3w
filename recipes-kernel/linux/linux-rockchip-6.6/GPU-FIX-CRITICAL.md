# CRITICAL: GPU Hard Hang Fix for Panfrost

## Problem Identified

Your GPU configuration has **TWO CRITICAL BUGS** causing immediate hard hangs:

### Bug #1: Wrong Interrupt Order
**Your config (WRONG):**
```dts
interrupts = <GIC_SPI 39 IRQ_TYPE_LEVEL_HIGH>,
             <GIC_SPI 41 IRQ_TYPE_LEVEL_HIGH>,
             <GIC_SPI 40 IRQ_TYPE_LEVEL_HIGH>;
interrupt-names = "gpu", "job", "mmu";
```

**Panfrost expects:**
```dts
interrupts = <GIC_SPI 39 IRQ_TYPE_LEVEL_HIGH>,  // Job IRQ
             <GIC_SPI 40 IRQ_TYPE_LEVEL_HIGH>,  // MMU IRQ  
             <GIC_SPI 41 IRQ_TYPE_LEVEL_HIGH>;  // GPU IRQ
interrupt-names = "job", "mmu", "gpu";
```

**Why it hangs:** Panfrost reads IRQs by name, but if names don't match or order is wrong, it registers the wrong handlers. When GPU tries to signal completion on the "job" interrupt but Panfrost is listening on the wrong one, it hangs forever waiting.

### Bug #2: Missing Power Domain
Your override **completely replaces** the GPU node, removing:
- `power-domains = <&power RK3568_PD_GPU>;` ❌ CRITICAL!
- `clocks` using SCMI ❌ 
- Other vendor-specific properties

Without power-domain, the GPU can't be powered on correctly.

## The Fix

**DO NOT** completely override `&gpu`. Instead, modify only what's needed:

```dts
&gpu {
    /* Keep base compatible, just ensure it's set */
    compatible = "arm,mali-bifrost";
    
    /* FIX: Correct interrupt order for Panfrost */
    interrupt-names = "job", "mmu", "gpu";
    interrupts = <GIC_SPI 39 IRQ_TYPE_LEVEL_HIGH>,  /* job */
                 <GIC_SPI 40 IRQ_TYPE_LEVEL_HIGH>,  /* mmu */
                 <GIC_SPI 41 IRQ_TYPE_LEVEL_HIGH>;  /* gpu */
    
    /* Keep vendor clocks - Panfrost will use them */
    /* DO NOT override clocks/clock-names */
    
    /* Keep power domain - CRITICAL! */
    /* DO NOT override power-domains */
    
    /* Override regulator name to match your PMIC */
    mali-supply = <&vdd_gpu_npu>;
    
    /* Keep cooling cells */
    #cooling-cells = <2>;
    
    /* Simplified OPP table reference */
    operating-points-v2 = <&gpu_opp_table>;
    
    status = "okay";
};
```

## Why This Happens

Rockchip vendor kernel uses their proprietary Mali driver with different IRQ expectations. When you switch to Panfrost (open-source), you MUST fix the IRQ configuration to match Panfrost's expectations.

### Vendor Mali vs Panfrost IRQ Differences:

| Driver | IRQ Order | Names |
|--------|-----------|-------|
| ARM Mali (vendor) | GPU, JOB, MMU | "GPU", "JOB", "MMU" or any |
| Panfrost (open) | JOB, MMU, GPU | "job", "mmu", "gpu" (strict!) |

Panfrost is **strict** about interrupt names and order!

## Other Common Hang Causes

1. **Clock mismatch** - Your override removes `clocks = <&scmi_clk 1>` which is needed
2. **No power domain** - GPU can't turn on without `power-domains = <&power RK3568_PD_GPU>`
3. **Wrong regulator** - Must point to actual PMIC regulator
4. **IOMMU not configured** - But kernel's base config has this

## Testing the Fix

After fixing, check dmesg:

```bash
# Should see successful probe
dmesg | grep panfrost
# Expected: "panfrost fde60000.gpu: mali-g52 id 0x7402 major 0x1 minor 0x0"
# Expected: "panfrost fde60000.gpu: Linked as a consumer to...power-domain"

# Should NOT see
# ERROR: "panfrost fde60000.gpu: failed to get power domain"
# ERROR: "panfrost fde60000.gpu: failed to get interrupt"
# Hang with no output = wrong IRQ order!
```

## The Minimal Safe Override

```dts
&gpu {
    /* Only override what's absolutely necessary for Panfrost */
    
    /* Fix interrupt configuration for Panfrost */
    interrupt-names = "job", "mmu", "gpu";
    
    /* Ensure mali-supply points to your regulator */
    mali-supply = <&vdd_gpu_npu>;
    
    /* Keep everything else from base DTS! */
    status = "okay";
};
```

Do **NOT** override:
- compatible (already correct in base)
- interrupts (already correct in base - just fix names!)
- clocks (base has correct SCMI clocks)
- clock-names (base is correct)
- power-domains (base is correct)
- reg (base is correct)

## Summary

The hard hang is caused by:
1. ❌ **Wrong IRQ order**: `gpu, job, mmu` should be `job, mmu, gpu`
2. ❌ **Wrong IRQ mapping**: IRQ 39 → gpu (should be job), IRQ 41 → job (should be gpu)
3. ❌ **Missing power-domain**: Removed by complete override
4. ❌ **Wrong clock configuration**: Using non-SCMI clocks

Fix: Minimal override that only changes what's needed for Panfrost compatibility.
