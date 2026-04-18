#!/bin/bash
set -euo pipefail

TOOL_NAME="ply"
TOOL_VERSION="2.4.0"
PLY_SHA512="3f4afe8d88d889fdd74f772a349e27b23fcdda194dc0af1482e75406fd0cd886cd663d673104fad8a501b92241be4f2d2f373f467313d5736aa18dc3033b9279"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/core/compile_flags.sh"

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
    
    setup_toolchain_for_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Failed to setup architecture: $arch"
        return 1
    }
    
    local build_name="${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local build_dir="/tmp/build"
    local arch_build_dir="${build_dir}/${build_name}"
    
    log_tool "$arch" "Building ${TOOL_NAME} ${TOOL_VERSION}..."
    
    rm -rf "$arch_build_dir"
    mkdir -p "$arch_build_dir"
    
    trap "cleanup_build_dir '$arch_build_dir'" EXIT
    
    download_ply_source "$arch" "$arch_build_dir" || return 1
    
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
    local build_dir="$2"
    local url=$(get_source_url)
    
    if ! download_and_extract "$url" "$build_dir" 1 "$PLY_SHA512"; then
        log_tool "$arch" "ERROR: Failed to download and extract source" >&2
        return 1
    fi
    
    return 0
}

build_tool() {
    local arch="$1"
    local build_dir="$2"
    
    cd "${build_dir}"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    # Already in the extracted directory from download_and_extract with strip_components=1
    
    log_tool "$arch" "Setting up BSD queue.h for ply..."
    mkdir -p include/sys
    
    if [ -f /usr/include/sys/queue.h ]; then
        log_tool "$arch" "Using Ubuntu's BSD queue.h from /usr/include/sys/"
        cp /usr/include/sys/queue.h include/sys/queue.h
    else
        log_tool "$arch" "WARNING: System queue.h not found, downloading standalone version..."
        local queue_url="https://raw.githubusercontent.com/freebsd/freebsd-src/main/sys/sys/queue.h"
        local queue_sha512="cc94b138de601c9e1804384496e691ad400ef1351c0b81f8d24d77449d7f17b11c5fefe0fb1c302e927e824f9e5c89895f7594336f2bf81aed7c40740d3e9ae6"
        
        if wget -q -O include/sys/queue.h.tmp "$queue_url"; then
            local actual_sha512=$(sha512sum include/sys/queue.h.tmp | cut -d' ' -f1)
            if [ "$actual_sha512" = "$queue_sha512" ]; then
                mv include/sys/queue.h.tmp include/sys/queue.h
                log_tool "$arch" "queue.h downloaded and verified"
            else
                log_tool "$arch" "ERROR: queue.h checksum verification failed"
                rm -f include/sys/queue.h.tmp
                return 1
            fi
        else
            log_tool "$arch" "ERROR: Failed to download queue.h"
            return 1
        fi
    fi
    
    cat > include/sys/cdefs.h << 'EOF'

/* Minimal cdefs.h for BSD queue.h compatibility */





EOF
    
    cflags="$cflags -I$(pwd)/include"
    
    # Check if we need to run autogen.sh or if configure already exists
    if [ -f configure ]; then
        log_tool "$arch" "Using pre-generated configure script..."
    elif [ -f autogen.sh ]; then
        log_tool "$arch" "Running autogen.sh..."
        chmod +x autogen.sh
        ./autogen.sh || {
            log_tool "$arch" "ERROR: autogen.sh failed" >&2
            return 1
        }
    else
        log_tool "$arch" "ERROR: Neither configure nor autogen.sh found" >&2
        return 1
    fi
    
    log_tool "$arch" "Configuring ${TOOL_NAME}..."
    
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
    
    local ply_binary=""
    if [ -f "src/ply/ply" ]; then
        ply_binary="src/ply/ply"
    elif [ -f "src/.libs/ply" ]; then
        ply_binary="src/.libs/ply"
    elif [ -f "ply" ]; then
        ply_binary="ply"
    else
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
    
    if ! file "${install_dir}/ply" | grep -qE "(statically linked|static-pie linked)"; then
        log_tool "$arch" "ERROR: Binary is not statically linked!" >&2
        ldd "${install_dir}/ply" || true
        return 1
    fi
    
    log_tool "$arch" "Stripping ${TOOL_NAME} binary..."
    "${STRIP}" "${install_dir}/ply" || {
        log_tool "$arch" "WARNING: Failed to strip binary" >&2
    }
    
    local final_size=$(ls -lh "${install_dir}/ply" | awk '{print $5}')
    log_tool "$arch" "Final binary size: $final_size"
    
    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>\nBuild ply for specified architecture" "$@"
    
    local arch=$1
    
    case "$arch" in
        x86_64)
            ;;
        aarch64)
            ;;
        arm32v5le|arm32v5lehf|arm32v7le|arm32v7lehf|armv6)
            ;;
        mips32le|mips64le)
            ;;
        riscv32)
            ;;
        riscv64)
            ;;
        ppc64le)
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
