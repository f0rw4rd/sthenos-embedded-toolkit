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

build_ncat() {
    local arch=$1
    local build_dir=$(create_build_dir "ncat" "$arch")
    local TOOL_NAME="ncat"
    
    if check_binary_exists "$arch" "ncat"; then
        return 0
    fi
    
    
    setup_toolchain_for_arch "$arch" || return 1
    
    download_source "nmap" "$NMAP_VERSION" "$NMAP_URL" || return 1
    
    cd "$build_dir"
    
    tar xf /build/sources/nmap-${NMAP_VERSION}.tar.bz2
    cd nmap-${NMAP_VERSION}
    
    cd libpcap
    ./configure --host=$HOST --disable-shared
    make -j$(nproc)
    cd ..
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
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
        log_tool_error "ncat" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    cd ncat
    make -j$(nproc) || {
        log_tool_error "ncat" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP ncat
    cp ncat "/build/output/$arch/ncat"
    
    local size=$(ls -lh "/build/output/$arch/ncat" | awk '{print $5}')
    log_tool "ncat" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_ncat "$arch"