#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

NMAP_VERSION="${NMAP_VERSION:-7.95}"
NMAP_URL="https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"

build_nmap() {
    local arch=$1
    local build_dir=$(create_build_dir "nmap" "$arch")
    local TOOL_NAME="nmap"
    
    if check_binary_exists "$arch" "nmap"; then
        return 0
    fi
    
    
    setup_toolchain_for_arch "$arch" || return 1
    
    local ssl_dir=$(build_openssl_cached "$arch") || {
        log_tool_error "nmap" "Failed to build/get OpenSSL for $arch"
        return 1
    }
    
    local pcap_dir=$(build_libpcap_cached "$arch") || {
        log_tool_error "nmap" "Failed to build/get libpcap for $arch"
        return 1
    }
    
    local zlib_dir=$(build_zlib_cached "$arch") || {
        log_tool_error "nmap" "Failed to build/get zlib for $arch"
        return 1
    }
    
    cd "$build_dir"
    
    download_source "nmap" "$NMAP_VERSION" "$NMAP_URL" || return 1
    
    tar xf /build/sources/nmap-${NMAP_VERSION}.tar.bz2
    cd nmap-${NMAP_VERSION}
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local cxxflags=$(get_cxx_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    cflags="$cflags -I$pcap_dir/include -I$ssl_dir/include -I$zlib_dir/include"
    cxxflags="$cxxflags -I$pcap_dir/include -I$ssl_dir/include -I$zlib_dir/include"
    ldflags="$ldflags -L$pcap_dir/lib -L$ssl_dir/lib -L$zlib_dir/lib"
    
    export CC="$CC"
    export CXX="$CXX"
    export CFLAGS="$cflags"
    export CXXFLAGS="$cxxflags"
    export LDFLAGS="$ldflags"
    export LIBS="-lpcap -lssl -lcrypto -lz -ldl"
    
    mkdir -p libpcre/sub
    
    export ac_cv_func_strerror=yes
    export ac_cv_prog_cc_g=yes
    
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
        log_tool_error "nmap" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    if [ -f libpcre/Makefile ]; then
        sed -i 's/^Makefile:.*/Makefile:/' libpcre/Makefile
        sed -i 's/^config.status:.*/config.status:/' libpcre/Makefile
    fi
    
    
    make V=1 -j$(nproc) || {
        log_tool_error "nmap" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    if [ -f "nmap" ]; then
        $STRIP nmap
        cp nmap "/build/output/$arch/nmap"
        local size=$(ls -lh "/build/output/$arch/nmap" | awk '{print $5}')
        log_tool "nmap" "Built successfully for $arch ($size)"
        cleanup_build_dir "$build_dir"
        return 0
    else
        log_tool_error "nmap" "Failed to build nmap for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_nmap "$arch"