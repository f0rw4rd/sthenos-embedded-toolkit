# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sthenos Embedded Toolkit is a cross-compilation framework for building static binaries and shared libraries (LD_PRELOAD) targeting 50+ CPU architectures. It supports musl, glibc, and Zig CC toolchains, with Docker-containerized builds.

## Key Commands

```bash
# Build everything (always use -d for debug output)
./build -d

# Single tool, single arch
./build -d strace --arch arm32v7le

# All tools for one arch
./build -d --arch x86_64

# Force libc type
./build -d --libc musl
./build -d --libc glibc

# Force rebuild (ignore cache)
./build -d -f strace --arch x86_64

# Parallel build mode
./build -d --mode parallel

# Interactive shell in build container
./build -d -i

# Run command inside container
./build -d --shell "ls /build/toolchains-musl/"

# Shared libraries (LD_PRELOAD)
./build -d libshells --arch x86_64

# Skip shared library builds
./build -d --no-shared

# Verify build completeness against x86_64 reference
./build -d --check-missing arm32v7le

# Cross-platform via Zig CC
./build -d busybox --arch x86_64_windows --os windows
./build -d microsocks --arch aarch64_macos --os macos
```

## Architecture

### Build Pipeline

```
./build (host)
  └─ Docker container (Ubuntu 22.04 + Zig 0.16.0)
       ├─ scripts/static/build-static.sh  → scripts/static/tools/build-<tool>.sh
       └─ scripts/shared/build-shared.sh  → scripts/shared/tools/build-<lib>.sh
```

### Source Loading Chain

Every build script sources a chain of helpers. Understanding this chain is critical:

```
build-<tool>.sh
  └─ scripts/lib/common.sh          ← TOOL_SCRIPTS + SHARED_LIB_SCRIPTS registries, setup_arch()
       ├─ scripts/lib/logging.sh
       ├─ scripts/lib/core/compile_flags.sh  ← get_compile_flags(), get_link_flags()
       │    └─ scripts/lib/core/arch_helper.sh
       ├─ scripts/lib/build_helpers.sh       ← standard_configure(), install_binary(), download_source()
       └─ scripts/lib/core/architectures.sh  ← 50+ arch definitions with toolchain names, SHA512s
```

`common.sh` is the central registry — it defines `TOOL_SCRIPTS` (20 tools) and `SHARED_LIB_SCRIPTS` (4 libs), plus `setup_arch()` which detects Zig vs GCC mode and exports `CC`, `CXX`, `AR`, `STRIP`, `HOST`, `CROSS_COMPILE`.

### Toolchain Strategy

| Toolchain | When Used | Volume | Env Vars Set |
|-----------|-----------|--------|--------------|
| **Musl** | Default for Linux targets | `toolchain-musl` | `CROSS_COMPILE`, `HOST`, `CC`, etc. |
| **glibc** | Fallback when musl unavailable, or `--libc glibc` | `toolchain-glibc` | Same vars, from Bootlin/Buildroot |
| **Zig CC** (0.16.0) | Non-Linux targets (Windows, macOS, BSDs) | N/A (pre-installed) | `USE_ZIG=1`, `ZIG_TARGET`, `CC="zig cc -target ..."` |

**Zig target detection**: underscore in arch name AND not `x86_64`/`x86_64_x32`/`aarch64_be` → Zig mode. Example: `x86_64_windows` → `USE_ZIG=1, CC="zig cc -target x86_64-windows-gnu"`.

### Architecture Naming

Arch names are strict — defined in `scripts/lib/core/architectures.sh`. Do NOT invent new names.

- **Linux targets**: `x86_64`, `arm32v7le`, `aarch64`, `riscv64`, `mips32be`, `s390x`, etc.
- **Cross-platform**: underscore-separated: `x86_64_windows`, `aarch64_macos`, `riscv64_freebsd`
- **Exceptions**: `x86_64`, `x86_64_x32`, `aarch64_be` contain underscores but are NOT Zig targets

Mappings between naming conventions: `scripts/lib/arch_map.sh`

### Tool Build Script Pattern

Every tool in `scripts/static/tools/` follows this structure:

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/tools.sh"

TOOL_NAME="<name>"
SUPPORTED_OS="linux,android"           # Comma-separated OS list for Zig compat check
<NAME>_VERSION="${<NAME>_VERSION:-X.Y}"
<NAME>_URL="https://..."
<NAME>_SHA512="..."                     # MANDATORY — builds fail without valid SHA512

configure_<tool>() { standard_configure "$1" "$TOOL_NAME" --extra-flags; }
build_<tool>_impl() { parallel_make; }
install_<tool>() { install_binary "path/to/<binary>" "$1" "<name>" "$TOOL_NAME"; }

build_<tool>() {
    check_tool_support "$SUPPORTED_OS" "$TOOL_NAME" || return 1
    check_binary_exists "$arch" "$TOOL_NAME" && return 0
    setup_toolchain_for_arch "$arch" || return 1
    download_toolchain "$arch" || return 1
    # download, extract, configure, build, install
}
```

**Key helpers** (from `build_helpers.sh`):
- `standard_configure` — runs `./configure --host=$HOST --enable-static --disable-shared ...`
- `parallel_make` — `make -j$(nproc)`
- `install_binary` — strips and copies to `/build/output/$arch/$name.$libc`
- `download_and_extract` — downloads with SHA512 verification and caching
- `create_build_dir` / `cleanup_build_dir` — temp dir lifecycle in `/tmp/`
- `get_compile_flags` / `get_link_flags` — architecture + mode-aware flag generation

### Compile Flags

**Static**: `-static -Os -D_GNU_SOURCE -fno-strict-aliasing -ffunction-sections -fdata-sections -fvisibility=hidden -fno-stack-protector -fomit-frame-pointer` + arch-specific
**Shared**: `-Os -fPIC -D_GNU_SOURCE -fvisibility=hidden -Wall`
**Link (static)**: `-static -Wl,--gc-sections -Wl,--strip-all -Wl,--as-needed`

**Platform exceptions**: macOS and BSDs strip `-static` from both CFLAGS and LDFLAGS (they don't support static linking). This is handled automatically in `get_compile_flags()` and `get_link_flags()` when `USE_ZIG=1` and target contains `macos`/`darwin`/`bsd`/`dragonfly`.

### OS Target System

`scripts/lib/core/os_targets.sh` defines supported OS targets with families:

| Family | OS Targets |
|--------|------------|
| unix | linux, android, illumos, solaris, aix |
| bsd | freebsd, openbsd, netbsd, dragonfly |
| darwin | macos, ios, tvos, watchos, visionos |
| windows | windows |
| wasm | wasi |

Tools declare `SUPPORTED_OS="linux,android"` — `check_tool_support()` validates Zig targets against this list. Tools that work everywhere use `SUPPORTED_OS="any"`.

### Output Layout

```
output/<arch>/<tool>.<libc>     # e.g. output/x86_64/strace.musl
output/<arch>/shell/            # Shell utilities subdirectory
output/<arch>/<lib>.so          # Shared libraries
```

Binary output path is computed by `get_output_path()` in `build_helpers.sh`. The libc suffix is auto-detected: `.musl` or `.glibc` for GCC toolchains (from `LIBC_TYPE` or `CROSS_COMPILE`), and `.zig` for all Zig CC targets (Darwin/BSD/Windows/WASI/Linux) regardless of `LIBC_TYPE`, because Zig uses its bundled libc layer, not musl/glibc.

## Known Hazards

- **SHA512 is mandatory**: All downloads require a valid 128-char hex SHA512. `validate_sha512()` will reject missing or malformed checksums. When adding a new tool, you MUST provide the correct SHA512.
- **Zig target underscore ambiguity**: `x86_64`, `x86_64_x32`, and `aarch64_be` contain underscores but are traditional GCC targets, not Zig targets. The detection logic in `setup_arch()` has explicit exceptions for these.
- **macOS/BSD no static linking**: The compile flags system automatically strips `-static` for these platforms. Do NOT hardcode `-static` in individual tool build scripts — use `get_link_flags()` instead.
- **Toolchain download in container**: Toolchains are downloaded inside Docker on first run and cached in named volumes. If a build fails with "toolchain not found", the image may need rebuilding or the volume may be stale.
- **Git LFS for output/**: All binaries in `output/` are tracked via Git LFS. Run `git lfs pull` after cloning if binaries appear as pointer files.

## Git Conventions

- Keep commit messages minimal — do NOT add AI co-author trailers
- Output binaries tracked via Git LFS (see `.gitattributes`)
- Release workflow: `.github/workflows/release.yml` creates per-arch tar.xz archives with SHA256/SHA512 checksums
