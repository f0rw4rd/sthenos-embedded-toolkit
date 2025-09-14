#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

NMAP_VERSION="${NMAP_VERSION:-7.94}"
NMAP_URL="https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"

build_ncat_ssl() {
    local arch=$1
    local build_dir=$(create_build_dir "ncat-ssl" "$arch")
    local TOOL_NAME="ncat-ssl"
    
    if check_binary_exists "$arch" "ncat-ssl"; then
        return 0
    fi
    
    
    setup_toolchain_for_arch "$arch" || return 1
    
    local ssl_dir=$(build_openssl_cached "$arch") || {
        log_tool_error "ncat-ssl" "Failed to build/get OpenSSL for $arch"
        return 1
    }
    
    download_source "nmap" "$NMAP_VERSION" "$NMAP_URL" || return 1
    
    cd "$build_dir"
    
    tar xf /build/sources/nmap-${NMAP_VERSION}.tar.bz2
    cd nmap-${NMAP_VERSION}
    
    cd libpcap
    ./configure --host=$HOST --disable-shared --enable-static --without-libnl
    make -j$(nproc)
    cd ..
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
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
        log_tool_error "ncat-ssl" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    cd ncat
    make -j$(nproc) || {
        log_tool_error "ncat-ssl" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP ncat
    cp ncat "/build/output/$arch/ncat-ssl"
    
    if ! strings "/build/output/$arch/ncat-ssl" | grep -q "OpenSSL"; then
        log_tool_warn "ncat-ssl" "Warning: Binary may not have SSL support"
    fi
    
    cleanup_build_dir "$build_dir"
    
    local size=$(ls -lh "/build/output/$arch/ncat-ssl" | awk '{print $5}')
    log_tool "ncat-ssl" "Built successfully for $arch ($size)"
    
    return 0
}

if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f build_ncat_ssl
else
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <architecture>"
        echo "Example: $0 x86_64"
        exit 1
    fi
    
    build_ncat_ssl "$1"
fi