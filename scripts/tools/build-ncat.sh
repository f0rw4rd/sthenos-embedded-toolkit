#!/bin/bash
# Build script for ncat
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/dependencies.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

NMAP_VERSION="${NMAP_VERSION:-7.94}"
NMAP_URL="https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"

build_ncat() {
    local arch=$1
    local build_dir="/tmp/ncat-build-${arch}-$$"
    local TOOL_NAME="ncat"
    
    # Check if binary already exists
    if check_binary_exists "$arch" "ncat"; then
        return 0
    fi
    
    echo "[ncat] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "nmap" "$NMAP_VERSION" "$NMAP_URL" || return 1
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Extract source
    tar xf /build/sources/nmap-${NMAP_VERSION}.tar.bz2
    cd nmap-${NMAP_VERSION}
    
    # First build bundled libpcap
    cd libpcap
    ./configure --host=$HOST --disable-shared
    make -j$(nproc)
    cd ..
    
    # Configure nmap/ncat with centralized build flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    ./configure \
        --host=$HOST \
        --without-openssl \
        --without-zenmap \
        --without-ndiff \
        --without-nmap-update \
        --without-libssh2 \
        --without-libz \
        --with-libpcap=included \
        --enable-static || {
        echo "[ncat] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build only ncat
    cd ncat
    make -j$(nproc) || {
        echo "[ncat] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Strip and copy binary
    $STRIP ncat
    cp ncat "/build/output/$arch/ncat"
    
    # Get size
    local size=$(ls -lh "/build/output/$arch/ncat" | awk '{print $5}')
    echo "[ncat] Built successfully for $arch ($size)"
    
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
build_ncat "$arch"