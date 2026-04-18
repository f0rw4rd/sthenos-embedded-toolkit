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

Fast, reliable pipeline for building static debugging and analysis tools for embedded systems across 50+ architectures. Supports both musl and glibc toolchains, with LD_PRELOAD shared libraries for runtime manipulation.

## Download Pre-built Binaries

**Download binaries directly from GitHub:**
👉 **[output folder](https://github.com/f0rw4rd/sthenos-embedded-toolkit/tree/main/output)**

Select your architecture → Download the tools you need.

## Building from Source

**Important:** If you have cloned this repository with Git LFS enabled, you need to clear the LFS placeholder files before building:

```bash
# Clear LFS files from output directory
rm -rf output/*

# Then build all tools for all architectures
./build

# Or build specific tool for specific architecture
./build strace --arch arm32v5le

# Build all tools for specific architecture  
./build --arch arm32v5le

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

**Network Tools**: socat, ncat, dropbear (SSH), can-utils, curl, microsocks

**System Tools**: bash, busybox, shell utilities

**LD_PRELOAD Libraries**: libdesock, shell tools, tls-noverify

## Supported Architectures

**50+ architectures** including:
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

## Download Pre-built Binaries

**Download binaries directly from GitHub:**
👉 **[output folder](https://github.com/f0rw4rd/sthenos-embedded-toolkit/tree/main/output)**

### Find Your Architecture

Run this command on your target system to detect architecture:
```bash
echo "$(uname -m)-$(uname -m | grep -q '64' && echo 64 || echo 32)-$(echo -n I | hexdump -c 2>/dev/null | grep -q I && echo le || echo be)-$(grep -qE 'FPU.*yes|vfp|neon' /proc/cpuinfo 2>/dev/null && echo hf || echo sf)-$(ldd --version 2>&1 | grep -q musl && echo musl || echo glibc)"
```

Example outputs:
- `mips-32-be-sf-musl` → Use `output/mips32v2besf/`
- `arm-32-le-hf-glibc` → Use `output/arm32v7lehf/`
- `x86_-64-le-hf-glibc` → Use `output/x86_64/`

Then download the tools from the matching directory.

```bash
# Test if binaries work on your target
./custom  # Should display banner if correct
```

## Building from Source

```bash
# Build all tools for all architectures
./build

# Build specific tool for specific architecture
./build strace --arch arm32v5le
```

Built binaries are placed in `output/<architecture>/<tool>` - all statically linked.

## Documentation

[Architecture Guide](docs/Architecture-Guide.md) | [Troubleshooting](docs/Troubleshooting.md)

## About

Sthenos provides statically compiled debugging and analysis tools for embedded systems. Useful for system analysis, network debugging, and embedded development across diverse architectures.

## Contributions and Support

Pull requests are welcome for bug fixes, new tools, and architecture support. Donations are welcome to buy more hardware for testing.

☕ **[Support on Ko-fi](https://ko-fi.com/f0rw4rd)**
