#!/bin/bash
# Build script for tcpdump
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/dependencies.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

LIBPCAP_VERSION="${LIBPCAP_VERSION:-1.10.4}"
LIBPCAP_URL="https://www.tcpdump.org/release/libpcap-${LIBPCAP_VERSION}.tar.gz"
TCPDUMP_VERSION="${TCPDUMP_VERSION:-4.99.4}"
TCPDUMP_URL="https://www.tcpdump.org/release/tcpdump-${TCPDUMP_VERSION}.tar.gz"

build_tcpdump() {
    local arch=$1
    local build_dir="/tmp/tcpdump-build-${arch}-$$"
    local TOOL_NAME="tcpdump"
    
    # Check if binary already exists
    if check_binary_exists "$arch" "tcpdump"; then
        return 0
    fi
    
    echo "[tcpdump] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Get libpcap from cache
    local pcap_dir=$(build_libpcap_cached "$arch") || {
        echo "[tcpdump] Failed to build/get libpcap for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build tcpdump
    echo "[tcpdump] Building tcpdump for $arch..."
    cd "$build_dir"
    download_source "tcpdump" "$TCPDUMP_VERSION" "$TCPDUMP_URL" || return 1
    tar xf /build/sources/tcpdump-${TCPDUMP_VERSION}.tar.gz
    cd tcpdump-${TCPDUMP_VERSION}
    
    # Fix missing includes
    sed -i '1i#include <fcntl.h>' tcpdump.c
    
    # Configure with centralized build flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    CFLAGS="$cflags -I$pcap_dir/include" \
    LDFLAGS="$ldflags -L$pcap_dir/lib" \
    ./configure \
        --host=$HOST \
        --enable-static \
        --disable-shared \
        --without-crypto \
        --without-smi \
        --without-cap-ng || {
        echo "[tcpdump] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    make -j$(nproc) || {
        echo "[tcpdump] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Strip and copy binary
    $STRIP tcpdump
    cp tcpdump "/build/output/$arch/tcpdump"
    
    # Get size
    local size=$(ls -lh "/build/output/$arch/tcpdump" | awk '{print $5}')
    echo "[tcpdump] Built successfully for $arch ($size)"
    
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
build_tcpdump "$arch"