#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

LIBPCAP_VERSION="${LIBPCAP_VERSION:-1.10.4}"
LIBPCAP_URL="https://www.tcpdump.org/release/libpcap-${LIBPCAP_VERSION}.tar.gz"
TCPDUMP_VERSION="${TCPDUMP_VERSION:-4.99.4}"
TCPDUMP_URL="https://www.tcpdump.org/release/tcpdump-${TCPDUMP_VERSION}.tar.gz"
TCPDUMP_SHA512="cb51e19574707d07c0de90dd4c301955897f2c9f2a69beb7162c08f59189f55625346d1602c8d66ab2b4c626ea4b0df1f08ed8734d2d7f536d0a7840c2d6d8df"

build_tcpdump() {
    local arch=$1
    local build_dir=$(create_build_dir "tcpdump" "$arch")
    local TOOL_NAME="tcpdump"
    
    if check_binary_exists "$arch" "tcpdump"; then
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    cd "$build_dir"
    
    local pcap_dir=$(build_libpcap_cached "$arch") || {
        log_tool_error "tcpdump" "Failed to build/get libpcap for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    log_tool "tcpdump" "Building tcpdump for $arch..."
    cd "$build_dir"
    if ! download_and_extract "$TCPDUMP_URL" "$build_dir" 0 "$TCPDUMP_SHA512"; then
        log_tool_error "tcpdump" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/tcpdump-${TCPDUMP_VERSION}"
    
    sed -i '1i#include <fcntl.h>' tcpdump.c
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    CFLAGS="${CFLAGS:-} $cflags -I$pcap_dir/include" \
    LDFLAGS="${LDFLAGS:-} $ldflags -L$pcap_dir/lib" \
    ./configure \
        --host=$HOST \
        --enable-static \
        --disable-shared \
        --without-crypto \
        --without-smi \
        --without-cap-ng || {
        log_tool_error "tcpdump" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    make -j$(nproc) || {
        log_tool_error "tcpdump" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP tcpdump
    cp tcpdump "/build/output/$arch/tcpdump"
    
    local size=$(ls -lh "/build/output/$arch/tcpdump" | awk '{print $5}')
    log_tool "tcpdump" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_tcpdump "$arch"
