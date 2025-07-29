#!/bin/bash
# Build script for BusyBox
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"
BUSYBOX_URL="https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2"

build_busybox() {
    local arch=$1
    local variant="${2:-standard}"  # standard or nodrop
    local build_dir="/tmp/busybox-build-${arch}-${variant}-$$"
    local TOOL_NAME="busybox"
    local output_name="busybox"
    
    # Set output name for nodrop variant
    if [ "$variant" = "nodrop" ]; then
        output_name="busybox_nodrop"
    fi
    
    # Check if binary already exists
    if check_binary_exists "$arch" "$output_name"; then
        return 0
    fi
    
    echo "[busybox] Building $variant variant for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "busybox" "$BUSYBOX_VERSION" "$BUSYBOX_URL" || return 1
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Extract source
    tar xf /build/sources/busybox-${BUSYBOX_VERSION}.tar.bz2
    cd busybox-${BUSYBOX_VERSION}
    
    # Configure for static build
    make defconfig
    
    # Enable static linking and disable shared libraries
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    sed -i 's/CONFIG_BUILD_LIBBUSYBOX=y/# CONFIG_BUILD_LIBBUSYBOX is not set/' .config
    sed -i 's/CONFIG_FEATURE_SHARED_BUSYBOX=y/# CONFIG_FEATURE_SHARED_BUSYBOX is not set/' .config
    
    # For nodrop variant, disable privilege dropping
    # This technique is inspired by https://github.com/leommxj/prebuilt-multiarch-bin
    if [ "$variant" = "nodrop" ]; then
        echo "[busybox] Applying nodrop modifications..."
        # Replace BB_SUID_DROP with BB_SUID_MAYBE only in applet definitions
        grep -e "applet:.*BB_SUID_DROP" -rl . | xargs sed -i 's/\(applet:.*\)BB_SUID_DROP/\1BB_SUID_MAYBE/g' || true
    fi
    
    # Set cross compiler with centralized flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    # Export environment variables for busybox build
    export CROSS_COMPILE="$CROSS_COMPILE"
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    make ARCH="$CONFIG_ARCH" -j$(nproc) || {
        echo "[busybox] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Strip and copy binary
    $STRIP busybox
    cp busybox "/build/output/$arch/$output_name"
    
    # Get size
    local size=$(ls -lh "/build/output/$arch/$output_name" | awk '{print $5}')
    echo "[busybox] Built $variant variant successfully for $arch ($size)"
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    return 0
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture> [variant]"
    echo "Architectures: arm32v5le arm32v5lehf arm32v7le arm32v7lehf mips32v2le mips32v2be ppc32be ix86le x86_64 aarch64 mips64le ppc64le"
    echo "Variants: standard (default), nodrop, both"
    exit 1
fi

arch=$1
variant="${2:-standard}"

# Handle 'both' variant
if [ "$variant" = "both" ]; then
    echo "[busybox] Building both standard and nodrop variants for $arch..."
    build_busybox "$arch" "standard" || exit 1
    build_busybox "$arch" "nodrop" || exit 1
else
    build_busybox "$arch" "$variant" || exit 1
fi