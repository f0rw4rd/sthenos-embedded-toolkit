#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"
BUSYBOX_URL="https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2"

build_busybox() {
    local arch=$1
    local variant="${2:-standard}"
    local build_dir=$(create_build_dir "busybox" "${arch}-${variant}")
    local TOOL_NAME="busybox"
    local output_name="busybox"
    
    if [ "$variant" = "nodrop" ]; then
        output_name="busybox_nodrop"
    fi
    
    if check_binary_exists "$arch" "$output_name"; then
        return 0
    fi
    
    log_tool "busybox" "Building $variant variant for $arch..."
    
    setup_toolchain_for_arch "$arch" || return 1
    
    download_source "busybox" "$BUSYBOX_VERSION" "$BUSYBOX_URL" || return 1
    
    cd "$build_dir"
    
    tar xf /build/sources/busybox-${BUSYBOX_VERSION}.tar.bz2
    cd busybox-${BUSYBOX_VERSION}
    
    make defconfig
    
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    sed -i 's/CONFIG_BUILD_LIBBUSYBOX=y/# CONFIG_BUILD_LIBBUSYBOX is not set/' .config
    sed -i 's/CONFIG_FEATURE_SHARED_BUSYBOX=y/# CONFIG_FEATURE_SHARED_BUSYBOX is not set/' .config
    
    if [ "$variant" = "nodrop" ]; then
        log_tool "busybox" "Applying nodrop modifications..."
        grep -e "applet:.*BB_SUID_DROP" -rl . | xargs sed -i 's/\(applet:.*\)BB_SUID_DROP/\1BB_SUID_MAYBE/g' || true
    fi
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CROSS_COMPILE="$CROSS_COMPILE"
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    # Export CC for glibc cross-compilation
    if [ "$LIBC_TYPE" = "glibc" ]; then
        export_cross_compiler "$CROSS_COMPILE"
    fi
    
    # BusyBox builds some host tools, so we need to set HOSTCFLAGS without arch-specific flags
    # Remove -mcpu, -march, -mtune flags that are architecture-specific
    export HOSTCFLAGS="$(echo "$cflags" | sed -E 's/-m(cpu|arch|tune)=[^ ]*//g')"
    
    # Debug output
    debug_compiler_info "$arch" "busybox"
    
    make ARCH="$CONFIG_ARCH" -j$(nproc) || {
        log_tool_error "busybox" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP busybox
    cp busybox "/build/output/$arch/$output_name"
    
    local size=$(get_binary_size "/build/output/$arch/$output_name")
    log_tool "busybox" "Built $variant variant successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

validate_args 1 "Usage: $0 <architecture> [variant]\nVariants: standard (default), nodrop, both" "$@"

arch=$1
variant="${2:-standard}"

if [ "$variant" = "both" ]; then
    log_tool "busybox" "Building both standard and nodrop variants for $arch..."
    build_busybox "$arch" "standard" || exit 1
    build_busybox "$arch" "nodrop" || exit 1
else
    build_busybox "$arch" "$variant" || exit 1
fi