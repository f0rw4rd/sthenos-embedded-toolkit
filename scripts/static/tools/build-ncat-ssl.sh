#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

NMAP_VERSION="${NMAP_VERSION:-7.98}"
NMAP_URL="https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"
NMAP_SHA512="14e13689d1276f70efc8c905e8eb0a15970f4312c2ef86d8d97e9df11319735e7f7cd73f728f69cf43d27a078ef5ac1e0f39cd119d8cb9262060c42606c6cab3"

build_ncat_ssl() {
    local arch=$1
    local build_dir=$(create_build_dir "ncat-ssl" "$arch")
    local TOOL_NAME="ncat-ssl"
    
    local output_path=$(get_output_path "$arch" "ncat-ssl")
    if [ -f "$output_path" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(get_binary_size "$output_path")
        log "[$arch] Already built: $output_path ($size)"
        return 0
    fi    
    
    setup_toolchain_for_arch "$arch" || return 1
    
    local ssl_dir=$(build_openssl_cached "$arch") || {
        log_tool_error "ncat-ssl" "Failed to build/get OpenSSL for $arch"
        return 1
    }
    
    local pcap_dir=$(build_libpcap_cached "$arch") || {
        log_tool_error "ncat-ssl" "Failed to build/get libpcap for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    if ! download_and_extract "$NMAP_URL" "$build_dir" 0 "$NMAP_SHA512"; then
        log_tool_error "ncat-ssl" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/nmap-${NMAP_VERSION}"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    cflags="$cflags -I$ssl_dir/include -I$pcap_dir/include"
    ldflags="$ldflags -L$ssl_dir/lib -L$pcap_dir/lib"
    
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
        --with-libpcap="$pcap_dir" \
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
    local output_path=$(get_output_path "$arch" "ncat-ssl")
    mkdir -p "$(dirname "$output_path")"
    cp ncat "$output_path"
    
    if ! strings "$output_path" | grep -q "OpenSSL"; then
        log_tool_warn "ncat-ssl" "Warning: Binary may not have SSL support"
    fi
    
    cleanup_build_dir "$build_dir"
    
    local size=$(get_binary_size "$output_path")
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
