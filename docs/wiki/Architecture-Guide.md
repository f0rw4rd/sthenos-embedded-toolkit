# Architecture Guide

Sthenos supports 40+ architectures for cross-compilation of static debugging tools.

## Supported Architectures

### ARM Architectures
- **aarch64** - ARM 64-bit (ARMv8-A)
- **aarch64_be** - ARM 64-bit big-endian
- **arm32v5le** - ARMv5 little-endian, soft-float
- **arm32v5lehf** - ARMv5 little-endian, hard-float  
- **arm32v7le** - ARMv7 little-endian, soft-float
- **arm32v7lehf** - ARMv7 little-endian, hard-float
- **armeb** - ARM big-endian, soft-float
- **armebhf** - ARM big-endian, hard-float
- **armel** - ARM EABI little-endian, soft-float
- **armelhf** - ARM EABI little-endian, hard-float  
- **armv5l** - ARMv5 little-endian (legacy naming)
- **armv5lhf** - ARMv5 little-endian, hard-float (legacy naming)
- **armv6** - ARMv6 (Raspberry Pi 1, Pi Zero)
- **armv6sf** - ARMv6 soft-float
- **armv7m** - ARMv7-M (Cortex-M)
- **armv7r** - ARMv7-R (Real-time)

### x86 Architectures
- **x86_64** - 64-bit x86 (AMD64, Intel 64)
- **i486** - 32-bit x86, i486 compatible
- **ix86le** - 32-bit x86 little-endian

### MIPS Architectures
- **mips32be** - MIPS32 big-endian, hard-float
- **mips32le** - MIPS32 little-endian, hard-float
- **mips32besf** - MIPS32 big-endian, soft-float
- **mips32lesf** - MIPS32 little-endian, soft-float
- **mips64** - MIPS64 big-endian
- **mips64le** - MIPS64 little-endian
- **mips64n32** - MIPS64 N32 ABI big-endian
- **mips64n32el** - MIPS64 N32 ABI little-endian
- **mipsn32** - MIPS N32 ABI big-endian
- **mipsn32el** - MIPS N32 ABI little-endian

### PowerPC Architectures  
- **ppc32be** - PowerPC 32-bit big-endian, hard-float
- **ppc32besf** - PowerPC 32-bit big-endian, soft-float
- **ppc64le** - PowerPC 64-bit little-endian
- **powerpc64** - PowerPC 64-bit big-endian
- **powerpcle** - PowerPC little-endian, hard-float
- **powerpclesf** - PowerPC little-endian, soft-float

### RISC-V Architectures
- **riscv32** - RISC-V 32-bit
- **riscv64** - RISC-V 64-bit

### Other Architectures
- **m68k** - Motorola 68000 series
- **microblaze** - Xilinx MicroBlaze big-endian
- **microblazeel** - Xilinx MicroBlaze little-endian  
- **or1k** - OpenRISC 1000
- **s390x** - IBM System/390 64-bit
- **sh2** - SuperH SH-2
- **sh2eb** - SuperH SH-2 big-endian
- **sh4** - SuperH SH-4
- **sh4eb** - SuperH SH-4 big-endian
- **sparc64** - SPARC 64-bit

## Architecture Selection Guide

### Common Embedded Systems

| Device/Platform | Recommended Architecture | Notes |
|-----------------|-------------------------|-------|
| Raspberry Pi 1, Zero | armv6 | ARMv6 CPU |
| Raspberry Pi 2/3/4 | arm32v7lehf or aarch64 | Pi 2/3: ARMv7, Pi 4: ARMv8 |
| BeagleBone | arm32v7lehf | Cortex-A8 |
| OpenWRT routers (ARM) | arm32v5le or arm32v7le | Check if hard/soft float |
| OpenWRT routers (MIPS) | mips32be/le or mips32besf/lesf | Big/little endian, check FPU |
| x86 embedded | i486 or x86_64 | i486 for maximum compatibility |
| IoT microcontrollers | armv7m | Cortex-M series |

### Floating-Point Considerations

**Hard-float (HF)** architectures require hardware FPU:
- Faster floating-point operations
- Smaller code size for FP-heavy applications
- Only works on systems with FPU hardware

**Soft-float (SF)** architectures emulate floating-point:
- Works on systems without FPU
- Larger code size, slower FP operations  
- Maximum compatibility

**When in doubt, use soft-float variants** for embedded systems.

## Build Support Matrix

| Tool | ARM | x86 | MIPS | PowerPC | RISC-V | Other |
|------|-----|-----|------|---------|---------|--------|
| strace | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| busybox | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| bash | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| socat | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ply | ✅* | ✅ | ✅* | ✅* | ✅ | ❌ |
| ltrace | ✅ | ✅ | ✅ | ✅ | ❓ | ❓ |

*✅ = Fully supported, ✅* = Little-endian only, ❌ = Not supported, ❓ = Untested*

## Legacy Architecture Names

Some architectures have legacy names that map to canonical names:

| Legacy Name | Canonical Name | Notes |
|-------------|----------------|-------|
| armv5 | arm32v5le | Old naming |
| mips32 | mips32be | MIPS big-endian |
| mips32el | mips32le | MIPS little-endian |
| ppc32 | ppc32be | PowerPC big-endian |
| openrisc | or1k | OpenRISC |
| aarch64be | aarch64_be | ARM64 big-endian |