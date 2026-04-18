#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/source_versions.sh"

SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd"  # macOS: Zig Darwin shim lacks net/bpf.h; Windows needs Npcap

build_ncat() {
    local arch=$1
    local build_dir=$(create_build_dir "ncat" "$arch")
    local TOOL_NAME="ncat"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "ncat"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1
    
    local pcap_dir
    pcap_dir=$(build_libpcap_cached "$arch") || {
        log_tool_error "ncat" "Failed to build/get libpcap for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    if ! download_and_extract "$NMAP_URL" "$build_dir" 0 "$NMAP_SHA512"; then
        log_tool_error "ncat" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/nmap-${NMAP_VERSION}"

    update_config_scripts

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    cflags="$cflags -I$pcap_dir/include"
    ldflags="$ldflags -L$pcap_dir/lib"
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export LIBS="-lm"

    ./configure \
        --host=$HOST \
        --without-openssl \
        --without-zenmap \
        --without-ndiff \
        --without-nmap-update \
        --without-libssh2 \
        --without-libz \
        --without-liblua \
        --with-libpcap="$pcap_dir" \
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
    local output_path=$(get_output_path "$arch" "ncat")
    mkdir -p "$(dirname "$output_path")"
    cp ncat "$output_path"
    
    local size=$(get_binary_size "$output_path")
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
