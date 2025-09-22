#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.37.0}"
BUSYBOX_URL="https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2"
BUSYBOX_SHA512="ad8fd06f082699774f990a53d7a73b189ed404fe0a2166aff13eae4d9d8ee5c9239493befe949c98801fe7897520dbff3ed0224faa7205854ce4fa975e18467e"

build_busybox_nodrop() {
    local arch=$1
    local build_dir=$(create_build_dir "busybox" "${arch}-nodrop")
    local TOOL_NAME="busybox_nodrop"
    local output_name="busybox_nodrop"
    
    if check_binary_exists "$arch" "$output_name"; then
        return 0
    fi
    
    log_tool "busybox_nodrop" "Building nodrop variant for $arch..."
    
    setup_toolchain_for_arch "$arch" || return 1
    
    if ! download_and_extract "$BUSYBOX_URL" "$build_dir" 0 "$BUSYBOX_SHA512"; then
        log_tool_error "busybox_nodrop" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/busybox-${BUSYBOX_VERSION}"
    
    make defconfig
    
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    sed -i 's/CONFIG_BUILD_LIBBUSYBOX=y/# CONFIG_BUILD_LIBBUSYBOX is not set/' .config
    sed -i 's/CONFIG_FEATURE_SHARED_BUSYBOX=y/# CONFIG_FEATURE_SHARED_BUSYBOX is not set/' .config

    if [[ "$arch" != "x86_64" && "$arch" != "i486" && "$arch" != "ix86le" ]]; then
        sed -i 's/CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/' .config
        sed -i 's/CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' .config
    fi
    
    log_tool "busybox_nodrop" "Applying nodrop modifications..."
    grep -e "applet:.*BB_SUID_DROP" -rl . | xargs sed -i 's/\(applet:.*\)BB_SUID_DROP/\1BB_SUID_MAYBE/g' || true
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CROSS_COMPILE="$CROSS_COMPILE"
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    if [ "$LIBC_TYPE" = "glibc" ]; then
        export_cross_compiler "$CROSS_COMPILE"
    fi
    
    export HOSTCFLAGS="$(echo "$cflags" | sed -E 's/-m(cpu|arch|tune)=[^ ]*//g')"
    
    debug_compiler_info "$arch" "busybox_nodrop"
    
    make ARCH="$CONFIG_ARCH" -j$(nproc) || {
        log_tool_error "busybox_nodrop" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP busybox
    cp busybox "/build/output/$arch/$output_name"
    
    local size=$(get_binary_size "/build/output/$arch/$output_name")
    log_tool "busybox_nodrop" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

validate_args 1 "Usage: $0 <architecture>" "$@"

arch=$1
build_busybox_nodrop "$arch" || exit 1
