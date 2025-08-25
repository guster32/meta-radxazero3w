# Rockchip MPP IOMMU Configuration Guide

## Overview
The Rockchip MPP driver requires proper IOMMU (Input-Output Memory Management Unit) configuration for optimal performance. The IOMMU allows the MPP hardware to access system memory efficiently and securely.

## Required Kernel Configuration

### 1. Enable IOMMU Support
```bash
CONFIG_IOMMU_SUPPORT=y
CONFIG_ROCKCHIP_IOMMU=y
CONFIG_IOMMU_DMA=y
CONFIG_IOMMU_DEFAULT_DMA_STRICT=y
CONFIG_IOMMU_DEFAULT_DMA_LAZY=n
```

### 2. ARM SMMU Support (for newer SoCs like RK3588)
```bash
CONFIG_ARM_SMMU=y
CONFIG_ARM_SMMU_V3=y
CONFIG_IOMMU_IO_PGTABLE_ARMV7S=y
CONFIG_IOMMU_IO_PGTABLE_LPAE=y
```

### 3. DMA and CMA Configuration
```bash
CONFIG_DMA_CMA=y
CONFIG_CMA=y
CONFIG_CMA_SIZE_MBYTES=256    # Adjust based on your memory requirements
CONFIG_DMA_COHERENT_POOL_SIZE=2097152
```

## Device Tree Configuration

### 1. IOMMU Device Node Example (RK3588)
```dts
mmu_rkvdec0: iommu@fdb60480 {
    compatible = "rockchip,rk3588-iommu", "rockchip,rk3568-iommu";
    reg = <0x0 0xfdb60480 0x0 0x40>;
    interrupts = <GIC_SPI 119 IRQ_TYPE_LEVEL_HIGH>;
    clocks = <&cru ACLK_RKVDEC>, <&cru HCLK_RKVDEC>;
    clock-names = "aclk", "iface";
    power-domains = <&power RK3588_PD_RKVDEC>;
    #iommu-cells = <0>;
};

mmu_rkvenc0: iommu@fdbd0480 {
    compatible = "rockchip,rk3588-iommu", "rockchip,rk3568-iommu";
    reg = <0x0 0xfdbd0480 0x0 0x40>;
    interrupts = <GIC_SPI 120 IRQ_TYPE_LEVEL_HIGH>;
    clocks = <&cru ACLK_RKVENC>, <&cru HCLK_RKVENC>;
    clock-names = "aclk", "iface";
    power-domains = <&power RK3588_PD_RKVENC>;
    #iommu-cells = <0>;
};
```

### 2. MPP Device Node with IOMMU Reference
```dts
rkvdec0: rkvdec@fdb50000 {
    compatible = "rockchip,rk3588-rkvdec", "rockchip,rkvdec";
    reg = <0x0 0xfdb50000 0x0 0x800>;
    interrupts = <GIC_SPI 118 IRQ_TYPE_LEVEL_HIGH>;
    clocks = <&cru ACLK_RKVDEC>, <&cru HCLK_RKVDEC>, <&cru CLK_RKVDEC_CA>,
             <&cru CLK_RKVDEC_CORE>, <&cru CLK_RKVDEC_HEVC_CA>;
    clock-names = "aclk", "hclk", "clk_cabac", "clk_core", "clk_hevc_cabac";
    assigned-clocks = <&cru ACLK_RKVDEC>, <&cru CLK_RKVDEC_CA>,
                      <&cru CLK_RKVDEC_CORE>, <&cru CLK_RKVDEC_HEVC_CA>;
    assigned-clock-rates = <800000000>, <800000000>, <600000000>, <200000000>;
    resets = <&cru SRST_A_RKVDEC>, <&cru SRST_H_RKVDEC>, <&cru SRST_RKVDEC_CA>,
             <&cru SRST_RKVDEC_CORE>, <&cru SRST_RKVDEC_HEVC_CA>;
    reset-names = "rst_a", "rst_h", "rst_ca", "rst_core", "rst_hevc_ca";
    power-domains = <&power RK3588_PD_RKVDEC>;
    iommus = <&mmu_rkvdec0>;  // <-- CRITICAL: Links MPP to IOMMU
};

rkvenc0: rkvenc@fdbd0000 {
    compatible = "rockchip,rk3588-rkvenc", "rockchip,rkvenc";
    reg = <0x0 0xfdbd0000 0x0 0x800>;
    interrupts = <GIC_SPI 121 IRQ_TYPE_LEVEL_HIGH>;
    clocks = <&cru ACLK_RKVENC>, <&cru HCLK_RKVENC>, <&cru CLK_RKVENC_CORE>;
    clock-names = "aclk", "hclk", "clk_core";
    assigned-clocks = <&cru ACLK_RKVENC>, <&cru CLK_RKVENC_CORE>;
    assigned-clock-rates = <800000000>, <600000000>;
    resets = <&cru SRST_A_RKVENC>, <&cru SRST_H_RKVENC>, <&cru SRST_RKVENC_CORE>;
    reset-names = "rst_a", "rst_h", "rst_core";
    power-domains = <&power RK3588_PD_RKVENC>;
    iommus = <&mmu_rkvenc0>;  // <-- CRITICAL: Links MPP to IOMMU
};
```

## Runtime Configuration and Verification

### 1. Check IOMMU Status
```bash
# Check if IOMMU is enabled in kernel
dmesg | grep -i iommu

# Expected output should show:
# rockchip-iommu fdb60480.iommu: version = 2
# rockchip-iommu fdb60480.iommu: allocate 4 pages for page table
```

### 2. Verify IOMMU Groups
```bash
# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort

# Check specific device IOMMU binding
ls -la /sys/bus/platform/devices/fdb50000.rkvdec/iommu_group
```

### 3. Monitor IOMMU Performance
```bash
# Check IOMMU page faults (should be minimal)
cat /proc/interrupts | grep iommu

# Monitor memory usage
cat /proc/meminfo | grep -E "(CmaTotal|CmaFree)"
```

## Performance Optimization

### 1. CMA (Contiguous Memory Allocator) Tuning
```bash
# In device tree or kernel command line:
cma=256M    # Adjust based on video resolution and concurrent streams

# For 4K video processing, consider:
cma=512M

# For multiple 4K streams:
cma=1024M
```

### 2. IOMMU Page Table Optimization
```bash
# Kernel command line options:
iommu.strict=0          # Use lazy unmapping for better performance
iommu.passthrough=0     # Ensure IOMMU is active (default)
```

### 3. Memory Bandwidth Optimization
```bash
# Ensure proper memory frequency in device tree
memory {
    device_type = "memory";
    reg = <0x0 0x00200000 0x0 0x3fe00000>,  // Adjust for your memory layout
        <0x0 0x40000000 0x3 0xc0000000>;
};

// Set appropriate memory controller frequencies
&dmc {
    center-supply = <&vdd_ddr_s0>;
    status = "okay";
};
```

## Troubleshooting IOMMU Issues

### 1. Common Problems and Solutions

**Problem: IOMMU page faults**
```bash
# Check dmesg for:
dmesg | grep "iommu fault"

# Solution: Increase CMA size or check device tree IOMMU bindings
```

**Problem: Poor video performance**
```bash
# Check if IOMMU is actually being used:
cat /sys/kernel/debug/iommu/rockchip-iommu/fdb60480.iommu/regs

# Verify memory allocation:
cat /proc/vmallocinfo | grep rkvdec
```

**Problem: Memory allocation failures**
```bash
# Increase CMA size in kernel command line:
cma=512M

# Or in device tree:
reserved-memory {
    cma_reserved: cma {
        compatible = "shared-dma-pool";
        reusable;
        size = <0x0 0x20000000>; // 512MB
        linux,cma-default;
    };
};
```

### 2. Debug Commands
```bash
# Enable IOMMU debugging
echo 1 > /sys/kernel/debug/iommu/rockchip-iommu/fdb60480.iommu/enable

# Check page table entries
cat /sys/kernel/debug/iommu/rockchip-iommu/fdb60480.iommu/pagetable

# Monitor DMA allocations
cat /proc/dma_heap/system
```

## SoC-Specific IOMMU Configuration

### RK3588/RK3588S
- Uses ARM SMMU v3 + Rockchip IOMMU
- Requires both CONFIG_ARM_SMMU=y and CONFIG_ROCKCHIP_IOMMU=y
- Multiple IOMMU domains for different codec engines

### RK3568/RK3566
- Uses Rockchip IOMMU v2
- Single IOMMU domain shared between codecs
- Simpler configuration than RK3588

### RK3399
- Uses Rockchip IOMMU v1
- Basic IOMMU support
- May require larger CMA allocation due to less efficient memory management

## Performance Impact

**With Proper IOMMU Configuration:**
- Zero-copy DMA transfers
- Efficient memory utilization
- Support for large video buffers
- Better multi-stream performance

**Without IOMMU or Misconfigured:**
- Memory copy overhead
- Fragmented memory allocation
- Potential system instability with large buffers
- Reduced concurrent stream capacity

## Verification Checklist

- [ ] IOMMU kernel configs enabled
- [ ] Device tree IOMMU nodes present
- [ ] MPP devices linked to IOMMU (`iommus = <&mmu_xxx>`)
- [ ] CMA size appropriate for workload
- [ ] No IOMMU page faults in dmesg
- [ ] IOMMU groups visible in sysfs
- [ ] Video encoding/decoding working without memory errors
