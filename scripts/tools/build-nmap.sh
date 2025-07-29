#!/bin/bash
# Build script for nmap
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/dependencies.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

NMAP_VERSION="${NMAP_VERSION:-7.95}"
NMAP_URL="https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"

build_nmap() {
    local arch=$1
    local build_dir="/tmp/nmap-build-${arch}-$$"
    local TOOL_NAME="nmap"
    
    # Check if binary already exists
    if check_binary_exists "$arch" "nmap"; then
        return 0
    fi
    
    echo "[nmap] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Get dependencies from cache
    local ssl_dir=$(build_openssl_cached "$arch") || {
        echo "[nmap] Failed to build/get OpenSSL for $arch"
        return 1
    }
    
    local pcap_dir=$(build_libpcap_cached "$arch") || {
        echo "[nmap] Failed to build/get libpcap for $arch"
        return 1
    }
    
    local zlib_dir=$(build_zlib_cached "$arch") || {
        echo "[nmap] Failed to build/get zlib for $arch"
        return 1
    }
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Download source if needed
    download_source "nmap" "$NMAP_VERSION" "$NMAP_URL" || return 1
    
    # Extract nmap into architecture-specific build directory
    tar xf /build/sources/nmap-${NMAP_VERSION}.tar.bz2
    cd nmap-${NMAP_VERSION}
    
    # Configure nmap with centralized flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local cxxflags=$(get_cxx_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    # Add include and lib paths for dependencies
    cflags="$cflags -I$pcap_dir/include -I$ssl_dir/include -I$zlib_dir/include"
    cxxflags="$cxxflags -I$pcap_dir/include -I$ssl_dir/include -I$zlib_dir/include"
    ldflags="$ldflags -L$pcap_dir/lib -L$ssl_dir/lib -L$zlib_dir/lib"
    
    # Export as environment variables to avoid "Argument list too long" error
    export CC="$CC"
    export CXX="$CXX"
    export CFLAGS="$cflags"
    export CXXFLAGS="$cxxflags"
    export LDFLAGS="$ldflags"
    export LIBS="-lpcap -lssl -lcrypto -lz -ldl"
    
    # Create subdirectories that libpcre configure might need
    mkdir -p libpcre/sub
    
    # Work around libpcre configure issues with cross-compilation
    export ac_cv_func_strerror=yes
    export ac_cv_prog_cc_g=yes
    
    # Prevent autotools from regenerating files during cross-compilation
    touch libpcre/aclocal.m4 libpcre/Makefile.in libpcre/configure
    find libpcre -name "*.in" -exec touch {} \;
    
    ./configure \
        --host=$HOST \
        --without-ndiff \
        --without-zenmap \
        --without-nmap-update \
        --without-ncat \
        --without-nping \
        --with-libpcap="$pcap_dir" \
        --with-openssl="$ssl_dir" \
        --with-libz="$zlib_dir" || {
        echo "[nmap] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Fix libpcre Makefile to prevent reconfigure during build
    if [ -f libpcre/Makefile ]; then
        sed -i 's/^Makefile:.*/Makefile:/' libpcre/Makefile
        sed -i 's/^config.status:.*/config.status:/' libpcre/Makefile
    fi
    
    # Clean any previous build artifacts (shouldn't be needed with isolated builds)
    # make clean || true
    
    # Build nmap with verbose output
    make V=1 -j$(nproc) || {
        echo "[nmap] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Install the binary
    if [ -f "nmap" ]; then
        $STRIP nmap
        cp nmap "/build/output/$arch/nmap"
        local size=$(ls -lh "/build/output/$arch/nmap" | awk '{print $5}')
        echo "[nmap] Built successfully for $arch ($size)"
        
        # Cleanup
        cd /
        rm -rf "$build_dir"
        return 0
    else
        echo "[nmap] Failed to build nmap for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    fi
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    echo "Architectures: arm32v5le arm32v5lehf arm32v7le arm32v7lehf mips32v2le mips32v2be ppc32be ix86le x86_64 aarch64 mips64le ppc64le"
    exit 1
fi

arch=$1
build_nmap "$arch"