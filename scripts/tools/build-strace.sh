#!/bin/bash
# Build script for strace
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

STRACE_VERSION="${STRACE_VERSION:-6.6}"
STRACE_URL="https://github.com/strace/strace/releases/download/v${STRACE_VERSION}/strace-${STRACE_VERSION}.tar.xz"

build_strace() {
    local arch=$1
    local build_dir="/tmp/strace-build-${arch}-$$"
    local TOOL_NAME="strace"
    
    # Check if binary already exists
    if check_binary_exists "$arch" "strace"; then
        return 0
    fi
    
    echo "[strace] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "strace" "$STRACE_VERSION" "$STRACE_URL" || return 1
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Extract source
    tar xf /build/sources/strace-${STRACE_VERSION}.tar.xz
    cd strace-${STRACE_VERSION}
    
    # Configure with centralized build flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    # Export as environment variables to avoid potential "Argument list too long" error
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    ./configure \
        --host=$HOST \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-nls \
        --disable-mpers || {
        echo "[strace] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build
    make -j$(nproc) || {
        echo "[strace] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Strip and copy binary
    $STRIP src/strace
    cp src/strace "/build/output/$arch/strace"
    
    # Get size
    local size=$(ls -lh "/build/output/$arch/strace" | awk '{print $5}')
    echo "[strace] Built successfully for $arch ($size)"
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    return 0
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    echo "Architectures: arm32v5le arm32v5lehf arm32v7le arm32v7lehf mips32v2le mips32v2be ppc32be ix86le x86_64 aarch64 mips64le ppc64le"
    exit 1
fi

arch=$1
build_strace "$arch"