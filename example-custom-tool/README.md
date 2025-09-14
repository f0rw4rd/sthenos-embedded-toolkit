# Example Custom Tool for Sthenos Embedded Toolkit

This is a simple example showing how to build your own tools with Sthenos.

## Quick Start

**Just run this command - it works out of the box!**

```bash
./build custom --arch x86_64
```

The build script is already configured to use this example.

## Files

- `custom.c` - Example C program with system info and ASCII art
- `Makefile` - Simple build configuration
- `README.md` - This file

## Test Your Binary

```bash
# Basic run
./output/x86_64/custom

# Show help
./output/x86_64/custom --help

# Show build information (including CFLAGS!)
./output/x86_64/custom --info
```

## Build for Other Architectures

```bash
# ARM
./build custom --arch arm32v7le

# MIPS  
./build custom --arch mips32v2le

# All architectures
./build custom
```

## Making Your Own Tool

1. **Replace the source code**:
   - Put your `.c` files in this directory
   - Update the `Makefile` if needed

2. **Change the binary name** (optional):
   - Edit `scripts/static/tools/build-custom.sh`  
   - Change `BINARY_NAME="your-tool-name"`

3. **Build and test**:
   ```bash
   ./build custom --arch x86_64
   ./output/x86_64/custom  # or your-tool-name
   ```

## Advanced Options

The build script (`scripts/static/tools/build-custom.sh`) includes examples for:
- CMake projects
- Go programs  
- Tools with dependencies (OpenSSL, etc.)
- Multiple output binaries

## Architecture Support

Your tool will automatically work on **57 architectures**:
- **x86**: x86_64, i486, ix86le
- **ARM**: 15 variants (ARMv5/6/7, AArch64, soft/hard float, NEON, Cortex-M/R)
- **MIPS**: 11 variants (32/64-bit, big/little endian, N32/N64 ABIs)
- **PowerPC**: 6 variants (32/64-bit, big/little endian)
- **RISC-V**: 4 variants (32/64-bit, soft/hard float)
- **Others**: LoongArch64, SPARC64, SuperH, m68k, s390x, OpenRISC, MicroBlaze

All binaries are statically linked for maximum compatibility!