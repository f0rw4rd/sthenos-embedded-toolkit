#!/bin/bash
set -euo pipefail

# Tool information
TOOL_NAME="ply"
TOOL_VERSION="2.4.0"

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/core/compile_flags.sh"

# Set up directories
SOURCES_DIR="${SOURCES_DIR:-/build/sources}"
OUTPUT_DIR="${OUTPUT_DIR:-/build/output}"

get_source_url() {
    echo "https://github.com/wkz/ply/releases/download/${TOOL_VERSION}/ply-${TOOL_VERSION}.tar.gz"
}

get_version() {
    echo "${TOOL_VERSION}"
}

build_ply() {
    local arch="$1"
    
    # Set up architecture environment
    setup_toolchain_for_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Failed to setup architecture: $arch"
        return 1
    }
    
    local build_name="${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local build_dir="/tmp/build"
    local arch_build_dir="${build_dir}/${build_name}"
    
    log_tool "$arch" "Building ${TOOL_NAME} ${TOOL_VERSION}..."
    
    # Set up build directory
    rm -rf "$arch_build_dir"
    mkdir -p "$arch_build_dir"
    
    # Set up error handling
    trap "cleanup_build_dir '$arch_build_dir'" EXIT
    
    download_ply_source "$arch" || return 1
    
    if ! build_tool "$arch" "$arch_build_dir"; then
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    fi
    
    if ! install_tool "$arch" "$arch_build_dir" "/build/output/$arch"; then
        log_tool_error "$TOOL_NAME" "Installation failed for $arch"
        return 1
    fi
    
    trap - EXIT
    cleanup_build_dir "$arch_build_dir"
    
    return 0
}

download_ply_source() {
    local arch="$1"
    local url=$(get_source_url)
    local filename="${TOOL_NAME}-${TOOL_VERSION}.tar.gz"
    
    download_source "$TOOL_NAME" "$TOOL_VERSION" "$url" || {
        log_tool "$arch" "ERROR: Failed to download source" >&2
        return 1
    }
    
    return 0
}

build_tool() {
    local arch="$1"
    local build_dir="$2"
    
    cd "${build_dir}"
    
    # Get proper flags from centralized configuration
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    # We'll copy it to the build directory for the musl toolchain to use
    
    # Extract source
    log_tool "$arch" "Extracting ${TOOL_NAME} source..."
    tar xzf "${SOURCES_DIR}/${TOOL_NAME}-${TOOL_VERSION}.tar.gz" || {
        log_tool "$arch" "ERROR: Failed to extract source" >&2
        return 1
    }
    
    cd "${TOOL_NAME}-${TOOL_VERSION}"
    
    # Ubuntu has BSD queue.h in /usr/include/sys/queue.h by default
    # Copy to local include for musl toolchain
    log_tool "$arch" "Setting up BSD queue.h for ply..."
    mkdir -p include/sys
    
    if [ -f /usr/include/sys/queue.h ]; then
        log_tool "$arch" "Using Ubuntu's BSD queue.h from /usr/include/sys/"
        cp /usr/include/sys/queue.h include/sys/queue.h
    else
        # Fallback: download standalone version if not found
        log_tool "$arch" "WARNING: System queue.h not found, downloading standalone version..."
        wget -q -O include/sys/queue.h \
            "https://raw.githubusercontent.com/freebsd/freebsd-src/main/sys/sys/queue.h" || {
            log_tool "$arch" "ERROR: Failed to download queue.h"
            return 1
        }
    fi
    
    # Create a minimal cdefs.h for queue.h compatibility
    # Ubuntu's queue.h may need some cdefs.h macros
    cat > include/sys/cdefs.h << 'EOF'
#ifndef _SYS_CDEFS_H_
#define _SYS_CDEFS_H_

/* Minimal cdefs.h for BSD queue.h compatibility */
#ifndef __BEGIN_DECLS
#ifdef __cplusplus
#define __BEGIN_DECLS extern "C" {
#define __END_DECLS }
#else
#define __BEGIN_DECLS
#define __END_DECLS
#endif
#endif

#ifndef __unused
#define __unused __attribute__((__unused__))
#endif

#ifndef __dead2
#define __dead2 __attribute__((__noreturn__))
#endif

#ifndef __pure2
#define __pure2 __attribute__((__pure__))
#endif

#ifndef __restrict
#define __restrict restrict
#endif

#endif /* _SYS_CDEFS_H_ */
EOF
    
    # Add local include directory
    cflags="$cflags -I$(pwd)/include"
    
    # Generate configure script
    log_tool "$arch" "Running autogen.sh..."
    # Run in a clean environment to avoid git warnings
    env -i PATH="/usr/bin:/bin" ./autogen.sh || {
        log_tool "$arch" "ERROR: autogen.sh failed" >&2
        return 1
    }
    
    # Configure
    log_tool "$arch" "Configuring ${TOOL_NAME}..."
    
    # Set up cross-compilation environment
    local host_triplet=""
    case "$arch" in
        x86_64)      host_triplet="x86_64-linux-musl" ;;
        i486)        host_triplet="i486-linux-musl" ;;
        ix86le)      host_triplet="i686-linux-musl" ;;
        aarch64)     host_triplet="aarch64-linux-musl" ;;
        aarch64_be)  host_triplet="aarch64_be-linux-musl" ;;
        arm32v5le)   host_triplet="arm-linux-musleabi" ;;
        arm32v5lehf) host_triplet="arm-linux-musleabihf" ;;
        arm32v7le)   host_triplet="armv7-linux-musleabi" ;;
        arm32v7lehf) host_triplet="armv7-linux-musleabihf" ;;
        armeb)       host_triplet="armeb-linux-musleabi" ;;
        armv6)       host_triplet="armv6-linux-musleabi" ;;
        armv7m)      host_triplet="armv7m-linux-musleabi" ;;
        armv7r)      host_triplet="armv7r-linux-musleabi" ;;
        mips32le)  host_triplet="mipsel-linux-musl" ;;
        mips32be)  host_triplet="mips-linux-musl" ;;
        mips64)      host_triplet="mips64-linux-musl" ;;
        mips64le)    host_triplet="mips64el-linux-musl" ;;
        ppc32be)     host_triplet="powerpc-linux-musl" ;;
        ppc32le)     host_triplet="powerpcle-linux-musl" ;;
        ppc64be)     host_triplet="powerpc64-linux-musl" ;;
        ppc64le)     host_triplet="powerpc64le-linux-musl" ;;
        riscv32)     host_triplet="riscv32-linux-musl" ;;
        riscv64)     host_triplet="riscv64-linux-musl" ;;
        *)
            log_tool "$arch" "WARNING: Unknown architecture, using generic host"
            host_triplet="${arch}-linux-musl"
            ;;
    esac
    
    # Configure with static linking
    # Don't mix system headers with musl toolchain
    CFLAGS="$cflags" \
    LDFLAGS="$ldflags" \
    ./configure \
        --host="${host_triplet}" \
        --prefix=/usr \
        --enable-static \
        --disable-shared \
        || {
        log_tool "$arch" "ERROR: Configure failed" >&2
        return 1
    }
    
    # Build
    log_tool "$arch" "Building ${TOOL_NAME}..."
    make -j$(nproc) LDFLAGS="$ldflags" AM_LDFLAGS="-all-static" || {
        log_tool "$arch" "ERROR: Build failed" >&2
        return 1
    }
    
    return 0
}

install_tool() {
    local arch="$1" 
    local build_dir="$2"
    local install_dir="$3"
    
    cd "${build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    log_tool "$arch" "Installing ${TOOL_NAME} to ${install_dir}..."
    
    # Find and install the binary
    local ply_binary=""
    if [ -f "src/ply/ply" ]; then
        ply_binary="src/ply/ply"
    elif [ -f "src/.libs/ply" ]; then
        ply_binary="src/.libs/ply"
    elif [ -f "ply" ]; then
        ply_binary="ply"
    else
        # Search for the binary
        ply_binary=$(find . -name "ply" -type f -executable | grep -v "\.sh$" | head -1)
    fi
    
    if [ -z "$ply_binary" ] || [ ! -f "$ply_binary" ]; then
        log_tool "$arch" "ERROR: Could not find ply binary" >&2
        find . -name "ply*" -type f | head -20
        return 1
    fi
    
    install -D -m 755 "$ply_binary" "${install_dir}/ply" || {
        log_tool "$arch" "ERROR: Failed to install ply binary from $ply_binary" >&2
        return 1
    }
    
    # Verify it's statically linked
    if ! file "${install_dir}/ply" | grep -qE "(statically linked|static-pie linked)"; then
        log_tool "$arch" "ERROR: Binary is not statically linked!" >&2
        ldd "${install_dir}/ply" || true
        return 1
    fi
    
    # Strip the binary
    log_tool "$arch" "Stripping ${TOOL_NAME} binary..."
    "${STRIP}" "${install_dir}/ply" || {
        log_tool "$arch" "WARNING: Failed to strip binary" >&2
    }
    
    # Show final size
    local final_size=$(ls -lh "${install_dir}/ply" | awk '{print $5}')
    log_tool "$arch" "Final binary size: $final_size"
    
    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>\nBuild ply for specified architecture" "$@"
    
    local arch=$1
    
    # Check if architecture is supported by ply
    # Based on actual implementation and known working architectures
    case "$arch" in
        x86_64)
            # x86_64.c - little endian only
            ;;
        aarch64)
            # aarch64.c - little endian only (aarch64_be not supported per GitHub issue #36)
            ;;
        arm32v5le|arm32v5lehf|arm32v7le|arm32v7lehf|armv6)
            # arm.c - little endian ARM 32-bit variants
            ;;
        mips32le|mips64le)
            # mips.c - little endian MIPS variants (safer to assume LE only)
            ;;
        riscv32)
            # riscv32.c - little endian
            ;;
        riscv64)
            # riscv64.c - little endian
            ;;
        ppc64le)
            # powerpc.c - little endian PowerPC 64
            ;;
        *)
            log_tool "$arch" "ERROR: Architecture is not supported by ply" >&2
            log_tool "$arch" "Supported: x86_64, aarch64 (LE), arm32 (LE), mips (LE), riscv32/64, ppc64le" >&2
            log_tool "$arch" "Note: Big-endian variants are not confirmed to work" >&2
            return 1
            ;;
    esac
    
    mkdir -p "/build/output/$arch"
    
    build_ply "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi