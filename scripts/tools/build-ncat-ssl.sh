#!/bin/bash
# Build script for ncat with SSL support
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/dependencies.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

NMAP_VERSION="${NMAP_VERSION:-7.94}"
NMAP_URL="https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"

build_ncat_ssl() {
    local arch=$1
    local build_dir="/tmp/ncat-ssl-build-${arch}-$$"
    local TOOL_NAME="ncat-ssl"
    
    # Check if binary already exists
    if check_binary_exists "$arch" "ncat-ssl"; then
        return 0
    fi
    
    echo "[ncat-ssl] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Get OpenSSL from cache (build if needed)
    local ssl_dir=$(build_openssl_cached "$arch") || {
        echo "[ncat-ssl] Failed to build/get OpenSSL for $arch"
        return 1
    }
    
    # Download source
    download_source "nmap" "$NMAP_VERSION" "$NMAP_URL" || return 1
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Extract source
    tar xf /build/sources/nmap-${NMAP_VERSION}.tar.bz2
    cd nmap-${NMAP_VERSION}
    
    # Build minimal libpcap first
    cd libpcap
    ./configure --host=$HOST --disable-shared --enable-static --without-libnl
    make -j$(nproc)
    cd ..
    
    # Configure nmap/ncat with SSL support using centralized build flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    # Add OpenSSL paths
    cflags="$cflags -I$ssl_dir/include"
    ldflags="$ldflags -L$ssl_dir/lib"
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    ./configure \
        --host=$HOST \
        --with-openssl=$ssl_dir \
        --without-zenmap \
        --without-ndiff \
        --without-nmap-update \
        --without-libssh2 \
        --without-libz \
        --with-libpcap=included \
        --enable-static || {
        echo "[ncat-ssl] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # We only need ncat, not the full nmap
    cd ncat
    make -j$(nproc) || {
        echo "[ncat-ssl] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Strip and copy binary
    $STRIP ncat
    cp ncat "/build/output/$arch/ncat-ssl"
    
    # Verify it was built with SSL support
    if ! strings "/build/output/$arch/ncat-ssl" | grep -q "OpenSSL"; then
        echo "[ncat-ssl] Warning: Binary may not have SSL support"
    fi
    
    # Clean up
    cd /
    rm -rf "$build_dir"
    
    # Report size
    local size=$(ls -lh "/build/output/$arch/ncat-ssl" | awk '{print $5}')
    echo "[ncat-ssl] Built successfully for $arch ($size)"
    
    return 0
}

# If sourced, export the function
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f build_ncat_ssl
else
    # If executed directly, run the build
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <architecture>"
        echo "Example: $0 x86_64"
        exit 1
    fi
    
    build_ncat_ssl "$1"
fi