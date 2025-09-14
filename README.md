# Sthenos Embedded Toolkit

```
            )           \     /          (
          /|\          ) \___/ (         /|\
        /  |  \       ( /\   /\ )      /  |  \
      /    |    \      \ x | O /     /    |    \
+----/-----|-----O------\  |  /----O------|------\--------+
|                 '^`      V     '^`                      |
|               STHENOS EMBEDDED TOOLKIT                  |
|                                                         |
|            Static Binaries for All Architectures        |
+---------------------------------------------------------+
  l     /\     /         \\             \     /\     l
  l  /     \ /            ))              \ /     \  l
   I/       V            //                V       \I
                         V
```

Fast, reliable pipeline for building static debugging and analysis tools for embedded systems across 40+ architectures.

## Quick Start

```bash
# Build all tools for all architectures
./build

# Build specific tool
./build strace

# Build for specific architecture  
./build --arch arm32v5le

# Build specific tool for specific architecture
./build strace --arch arm32v5le

# See all available options
./build --help
```

### Common Options

- `--arch ARCH` - Build for specific architecture (or `--arch all` for all)
- `-d, --debug` - Debug mode with verbose output
- `-f, --force` - Force rebuild (ignore existing binaries)
- `-i, --interactive` - Launch interactive shell in build container
- `--shell CMD` - Run command in container with build environment
- `--clean` - Clean output and logs directories
- `--download` - Download sources and toolchains only

## Available Tools

**Analysis & Debugging**: strace, ltrace, ply, gdbserver, tcpdump, nmap

**Network Tools**: socat, ncat, dropbear (SSH), can-utils

**System Tools**: bash, busybox, shell utilities

**LD_PRELOAD Libraries**: libdesock, shell tools, tls-noverify

## Supported Architectures

**40+ architectures** including:
- **ARM**: aarch64, arm32v5le, arm32v7le, armeb, armv6, armv7m, armv7r, etc.
- **x86**: x86_64, i486, ix86le  
- **MIPS**: mips32be/le, mips64, mipsn32, with soft-float variants
- **PowerPC**: ppc32be, ppc64le, powerpc64, with soft-float variants
- **RISC-V**: riscv32, riscv64
- **Other**: m68k, microblaze, or1k, s390x, sh2/4, sparc64

## Requirements

- Docker
- 20GB+ free disk space
- Internet connection

## Output

Built binaries are in `output/<architecture>/<tool>` - all statically linked with no dependencies.

```bash
# Check build status
find output -type f | wc -l
ls output/*/strace

# Test architecture compatibility
./output/<arch>/custom  # Should display banner if arch is correct
```

## Documentation

📚 **[Full Documentation in Wiki](../../wiki)**

- [Architecture Guide](../../wiki/Architecture-Guide) - Complete architecture list and compatibility
- [Build System](../../wiki/Build-System) - Detailed build options and troubleshooting  
- [Tools Reference](../../wiki/Tools-Reference) - Complete tool documentation
- [Examples](../../wiki/Examples) - Usage examples and custom tools
- [Troubleshooting](../../wiki/Troubleshooting) - Common issues and solutions

## About

Sthenos provides statically compiled debugging and analysis tools for embedded systems. Useful for system analysis, network debugging, and embedded development across diverse architectures.

Inspired by [CyberDanube's medusa-embedded-toolkit](https://github.com/CyberDanube/medusa-embedded-toolkit) - while they provide binaries, we provide the complete build system.
