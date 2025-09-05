# Sthenos Embedded Toolkit

Fast, reliable pipeline for building static debugging tools for embedded systems.

## About

This project is inspired by [CyberDanube's medusa-embedded-toolkit](https://github.com/CyberDanube/medusa-embedded-toolkit), which provides pre-compiled static binaries for embedded systems. While they focus on publishing the binaries, Sthenos provides the complete build toolchain to create these binaries from source.

The name "Sthenos" is a playful reference - in Greek mythology, Sthenos was one of Medusa's sisters, both being Gorgons. This reflects our relationship: same family of tools, different approach.

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

# Build ltrace (automatically uses glibc build system)
./build ltrace

# Build ltrace for specific architecture
./build ltrace --arch x86_64

# Build CAN utilities (creates can-utils/ subdirectory)
./build can-utils --arch arm32v7le
```

## Docker Build

The build system runs inside Docker automatically when you use the `./build` script. Docker is required for all builds.

## Preload Libraries

Build LD_PRELOAD libraries for all architectures:

```bash
# Build preload libraries
./build-preload
```

Includes:
- **libdesock** - Socket redirection library for fuzzing (from [FKIE-CAD](https://github.com/fkie-cad/libdesock))
- **shell-env** - Execute commands from EXEC_CMD env var
- **shell-helper** - Execute /dev/shm/helper.sh script
- **shell-bind** - Bind shell on port
- **shell-reverse** - Reverse shell
- **shell-fifo** - Named pipe shell
- **tls-noverify** - Disable TLS/SSL certificate verification (from [f0rw4rd](https://github.com/f0rw4rd/tls-preloader))

### libdesock Example

libdesock redirects network socket operations to stdin/stdout, making it ideal for fuzzing network applications:

```bash
# Basic usage - redirect network I/O to stdin/stdout
LD_PRELOAD=./output-preload/glibc/x86_64/libdesock.so ./network_app

# Fuzzing example with AFL++
export AFL_PRELOAD=./output-preload/glibc/x86_64/libdesock.so
export AFL_TMPDIR=/tmp
afl-fuzz -i corpus -o findings -m none -- ./nginx

# Multiple requests with delimiter
(echo "request1"; echo "-=^..^=-"; echo "request2") | \
  LD_PRELOAD=./libdesock.so ./web_server

# Configuration options
DESOCK_CONNECT=1 LD_PRELOAD=./libdesock.so ./client_app  # For connect mode
DESOCK_BIND=1 LD_PRELOAD=./libdesock.so ./server_app     # For bind mode
```

### tls-noverify Example

Bypass TLS/SSL certificate verification for testing:

```bash
# Debug TLS issues
LD_PRELOAD=./libtlsnoverify.so curl https://expired.badssl.com/
TLS_NOVERIFY_DEBUG=1 LD_PRELOAD=./libtlsnoverify.so wget https://self-signed.badssl.com/
```

### Detecting System Architecture

To determine your current architecture and libc type:

```bash
arch=$(uname -m);libc=$(ldd --version 2>&1|grep -qi musl&&echo musl||echo glibc);echo "$arch/$libc"
# Output: x86_64/glibc or aarch64/musl etc.
```

## Build System Structure

```
.
├── build                       # Main build script (musl static)
├── build-preload              # Preload library build script
├── build-glibc-static         # Build script for glibc static tools
├── Dockerfile.musl            # Docker image for musl builds
├── Dockerfile.glibc           # Docker image for glibc preload builds
├── Dockerfile.glibc-static    # Docker image for glibc static builds
├── scripts/
│   ├── build-unified.sh       # Core build system
│   ├── lib/                   # Shared libraries
│   ├── tools/                 # Individual tool build scripts
│   └── preload/               # Preload library build scripts
├── preload-libs/              # Preload library sources
├── output/                    # Built binaries (release directory)
└── configs/                   # Architecture configurations
```

## Available Tools

### Musl Static Tools (default)
- **strace** - System call tracer
- **busybox** - Multi-call binary with Unix utilities
- **busybox_nodrop** - BusyBox variant that maintains SUID privileges when run as SUID root (inspired by [prebuilt-multiarch-bin](https://github.com/leommxj/prebuilt-multiarch-bin))
- **bash** - Bourne Again Shell
- **socat** - Socket relay tool
- **ncat** - Network utility
- **tcpdump** - Network packet analyzer
- **gdbserver** - Remote debugging server
- **nmap** - Network exploration tool
- **ply** - BPF-based dynamic tracer (eBPF/kprobes)
- **dropbear** - Lightweight SSH server/client (includes dbclient, scp, dropbearkey)
- **can-utils** - CAN bus utilities (20 tools including candump, cansend, canplayer, etc.)
- **shell-static** - Static executable versions of shell utilities (shell-bind, shell-env, etc.)

### Glibc Static Tools (new)
- **ltrace** - Library call tracer (traces dynamic library calls and signals)

**Note on glibc static builds**: Due to glibc's design, "static" binaries built with glibc may still require certain runtime libraries for features like hostname resolution (NSS) and locale support. These tools are provided for environments where glibc is the standard C library.

## Supported Architectures

35 architectures are supported (musl static builds):
24 architectures are supported (glibc builds):

**ARM**: `aarch64`, `aarch64_be`, `arm32v5le`, `arm32v5lehf`, `arm32v7le`, `arm32v7lehf`, `armeb`, `armv6`, `armv7m`, `armv7r`

**x86**: `x86_64`, `i486`, `ix86le`

**MIPS**: `mips32v2be`, `mips32v2le`, `mips64`, `mips64le`, `mips64n32`, `mips64n32el`, `mipsn32`, `mipsn32el`

**PowerPC**: `ppc32be`, `ppc64le`, `powerpc64`, `powerpcle`

**RISC-V**: `riscv32`, `riscv64`

**Other**: `m68k`, `microblaze`, `microblazeel`, `or1k`, `s390x`, `sh2`, `sh2eb`, `sh4`, `sh4eb`

### Architecture Compatibility

**Important**: Not all tools can be built for all architectures due to various constraints:

**ply architecture support**: Only supports little-endian architectures including x86_64, aarch64, arm32v7le, mips32v2le, riscv64, riscv32, and ppc64le. Big-endian architectures are not supported.

- **Tool limitations**: Some tools may not support certain architectures upstream
- **Toolchain constraints**: Some architecture/tool combinations may fail during cross-compilation
- **Library dependencies**: Certain architectures may lack required libraries or have incompatible ABIs
- **Build system issues**: Some tools' build systems may not properly handle certain cross-compilation scenarios

If a build fails for a specific architecture, check the build logs in:
- `/build/logs/` - for musl static builds
- `/build/logs-glibc-static/` - for glibc static builds
- `/build/logs-preload/` - for preload libraries

Common issues include:
- Missing architecture support in the tool's source code
- Incompatible assembly code or architecture-specific optimizations
- Build system attempting to run target binaries during compilation
- Missing or incompatible system headers for the target architecture

## Build Options

```bash
./build [TOOL] [OPTIONS]

TOOL:
  all         Build all tools (default)
  strace      System call tracer
  busybox     Multi-call binary
  busybox_nodrop  BusyBox variant that maintains SUID privileges
  bash        Bourne Again Shell
  socat       Socket relay tool
  ncat        Network utility
  tcpdump     Network packet analyzer
  gdbserver   Remote debugging server
  ltrace      Library call tracer (glibc static)
  ply         BPF-based dynamic tracer

OPTIONS:
  --arch ARCH Build for specific architecture
  -j N        Use N parallel jobs (default: 4)
  --help      Show help message
```

## Requirements

- Docker
- 20GB+ free disk space (for toolchains, sources, and build artifacts)
- Internet connection (for downloading sources/toolchains)

## Output

All compiled binaries are stored in the `output/` folder, which serves as the release directory:

- **Binaries**: `output/<architecture>/<tool>` (e.g., `output/arm32v7le/strace`)

The `output/` folder contains all the ready-to-use static binaries organized by architecture. Each subdirectory represents a target architecture and contains the tools compiled for that platform.

All binaries are statically linked with no runtime dependencies.

## Quick Status Check

```bash
# Count total binaries
find output -type f | wc -l

# Check by architecture
ls -la output/*/

# Check specific tool across architectures
ls -la output/*/strace
```

## Custom Tools Examples

### example-custom-tool
Template for adding custom C programs to the build system:

```bash
./build custom              # Build for all architectures
./build custom --arch x86_64    # Specific architecture
./build custom-glibc --arch x86_64  # Use glibc instead of musl
```

See `scripts/tools/build-custom.sh` for the documented template.

### example-custom-lib
Example static library with cross-compilation:

```bash
cd example-custom-lib
make
./test-mylib "Hello World"
```

Both examples demonstrate proper integration with the Sthenos build system.

## Credits

This project builds upon the work of several excellent projects:

- **[musl-cross-make](https://github.com/richfelker/musl-cross-make)** - Provides the cross-compilation toolchains
- **[gdb-static](https://github.com/guyush1/gdb-static)** by guyush1 - Pre-built static GDB binaries for multiple architectures
- **[prebuilt-multiarch-bin](https://github.com/leommxj/prebuilt-multiarch-bin)** by leommxj - Inspiration for the busybox_nodrop variant

### Tool Sources

All tools are built from their official upstream sources:
- BusyBox, Bash, strace, tcpdump, socat, nmap/ncat, ply - Built from source
- GDBserver - Built from GNU GDB source
