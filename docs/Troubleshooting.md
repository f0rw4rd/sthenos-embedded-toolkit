# Troubleshooting

Common issues and solutions when building or using Sthenos tools.

## "Illegal Instruction" Errors

### Quick Diagnosis

If a binary crashes with "Illegal instruction" on your target system:

```bash
# Always test with the custom tool first - it's the smallest and simplest
./output/<arch>/custom

# If custom displays ASCII art banner → architecture is correct, other tools should work
# If custom crashes with "Illegal instruction" → architecture/flags mismatch
```

The `custom` tool is specifically designed as a compatibility test - it's a minimal C program that will reveal architecture issues immediately without the complexity of larger tools.

### Architecture Detection on Target

```bash
# Show current architecture
uname -m

# Detect floating-point ABI
strings /bin/busybox | grep -E "ld-musl|ld-linux" | head -1

# Examples:
# /lib/ld-musl-mipsel-sf.so.1  → mips32le (soft-float)
# /lib/ld-linux-armhf.so.3     → arm32v7lehf (hard-float)  
# /lib/ld-musl-aarch64.so.1    → aarch64
```

### Common Architecture Mismatches

| Error Symptom | Likely Cause | Solution |
|---------------|--------------|----------|
| "Illegal instruction" on ARM | Hard/soft float mismatch | Try arm32v5le (soft) vs arm32v7lehf (hard) |
| "Illegal instruction" on MIPS | Endianness or float mismatch | Check mips32be vs mips32le, try soft-float |
| "Illegal instruction" on old x86 | CPU too old for i686 code | Use i486 architecture |
| Crashes on PowerPC | Float ABI mismatch | Try ppc32besf (soft-float) |

**Pro tip**: Build and test the `custom` tool for multiple architecture variants to find the right one:

```bash
./build custom --arch mips32be
./build custom --arch mips32le  
./build custom --arch mips32besf
./build custom --arch mips32lesf

# Test each one until you find the working variant
```

### MIPS Specific Issues

MIPS systems are particularly sensitive to ABI mismatches:

```bash
# For maximum MIPS compatibility, try soft-float variants:
./build strace --arch mips32besf   # Big-endian, soft-float  
./build strace --arch mips32lesf   # Little-endian, soft-float
```

### ARM Floating-Point Guide

| Architecture | Float ABI | Use Cases |
|-------------|-----------|-----------|
| arm32v5le | Soft | Old ARM9, ARM11, no VFP |
| arm32v5lehf | Hard | ARM with VFPv2+ |
| arm32v7le | Soft | Cortex-A without NEON |
| arm32v7lehf | Hard | Cortex-A with VFPv3/NEON |
| armv6 | Hard | Raspberry Pi 1, Zero |

## Build Issues

### Docker Container Problems

```bash
# Rebuild containers if you see toolchain errors
docker build --no-cache -t sthenos-musl-builder -f Dockerfile.musl .
docker build --no-cache -t sthenos-glibc-builder -f Dockerfile.glibc .
```

### Missing Toolchains

```bash
# If you see "Toolchain not found" errors:
docker build --no-cache -t sthenos-musl-builder -f Dockerfile.musl .

# Check toolchain download
docker run --rm sthenos-musl-builder ls /toolchains/
```

### Build Fails for Specific Architecture

```bash
# Enable debug mode to see detailed output
./build -d strace --arch problematic_arch

# Check build logs
ls logs/build_*_problematic_arch.log
tail -50 logs/build_strace_problematic_arch.log
```

### Out of Space Errors

```bash
# Clean up old builds
docker system prune -f
docker volume prune -f

# Check space usage
df -h
docker system df
```

## Runtime Issues

### Binary Won't Execute

```bash
# Check if binary exists and is executable
ls -la output/arch/tool
file output/arch/tool

# Should show "statically linked" for musl tools
# Should show "dynamically linked" for glibc tools
```

### "No such file or directory" for Static Binary

This usually means architecture mismatch, not missing files:

```bash
# Verify architecture
file output/arch/tool

# Test with qemu if cross-architecture  
qemu-arm-static output/arm32v7le/strace --version
```

### glibc Tools Not Working

```bash
# glibc tools need glibc runtime environment
# Check if target has glibc
ldd --version

# For musl systems, use musl static tools instead
./build strace --arch target_arch  # Use this instead of ltrace
```

## Tool-Specific Issues

### ply Not Building

ply only supports little-endian architectures:

```bash
# Supported: x86_64, aarch64, arm32v7le, mips32le, riscv64, ppc64le
# Not supported: Big-endian architectures, sh4, m68k, etc.

# Use strace instead for unsupported architectures
./build strace --arch mips32be
```

### ncat-ssl vs ncat

```bash
# If ncat-ssl fails to build, use regular ncat
./build ncat --arch target_arch

# ncat-ssl requires OpenSSL, which may not build on all architectures
```

### can-utils Build Issues

```bash
# can-utils requires kernel headers
# Some architectures may not have complete kernel header support
# Check build log for specific errors:
tail -50 logs/build_can-utils_arch.log
```

## Network Issues

### libdesock Not Intercepting

```bash
# Ensure correct libc variant
LD_PRELOAD=./output-preload/glibc/x86_64/libdesock.so ./app  # For glibc
LD_PRELOAD=./output-preload/musl/x86_64/libdesock.so ./app   # For musl

# Enable debug
DESOCK_DEBUG=1 LD_PRELOAD=./libdesock.so ./app
```

### tls-noverify Not Working

```bash
# Enable debug output
TLS_NOVERIFY_DEBUG=1 LD_PRELOAD=./libtlsnoverify.so curl https://expired.badssl.com/

# Make sure you're using the right libc variant
```

## Getting Help

### Gather Debug Information

```bash
# System information
uname -a
docker --version

# Architecture detection
arch=$(uname -m)
libc=$(ldd --version 2>&1|grep -qi musl && echo musl || echo glibc)
echo "System: $arch/$libc"

# Test basic functionality
file output/x86_64/custom
./output/x86_64/custom
```

### Create Issue Report

Include this information when reporting issues:

1. **Host system**: OS, architecture, Docker version
2. **Target architecture**: What you're building for  
3. **Command used**: Exact build command
4. **Error message**: Full error output
5. **Build log**: Relevant portions of build log
6. **Test results**: Output of `./output/arch/custom`

### Common Solutions Summary

| Problem | Quick Fix |
|---------|-----------|
| "Illegal instruction" | Try soft-float variant of architecture |
| Tool won't build | Check build log, try different architecture |
| Docker errors | Rebuild containers with `--no-cache` |
| Out of space | Run `docker system prune -f` |
| Binary not found | Check `ls output/arch/tool` |
| LD_PRELOAD not working | Verify glibc vs musl variant |