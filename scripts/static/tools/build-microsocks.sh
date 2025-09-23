#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

MICROSOCKS_VERSION="${MICROSOCKS_VERSION:-1.0.5}"
MICROSOCKS_URL="http://ftp.barfooze.de/pub/sabotage/tarballs/microsocks-${MICROSOCKS_VERSION}.tar.xz"
MICROSOCKS_SHA512="16b99f1b94dd857f6ee303f2fb3ef85acd5d8cad2a7635bca7d78c3106bd9beb846a4363286d2d1f395a9bcc115890736c883835590f22234e7955fab6066a66"

build_microsocks() {
    local arch=$1
    local build_dir=$(create_build_dir "microsocks" "$arch")
    local TOOL_NAME="microsocks"
    
    local output_path=$(get_output_path "$arch" "microsocks")
    if [ -f "$output_path" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(get_binary_size "$output_path")
        log "[$arch] Already built: $output_path ($size)"
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    if ! download_and_extract "$MICROSOCKS_URL" "$build_dir" 0 "$MICROSOCKS_SHA512"; then
        log_tool_error "microsocks" "Failed to download and extract source"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    cd "$build_dir/microsocks-${MICROSOCKS_VERSION}"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    log_tool "microsocks" "Building microsocks for $arch..."
    
    make -j$(nproc) CFLAGS="$cflags" LDFLAGS="-static $ldflags -lpthread" || {
        log_tool_error "microsocks" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP microsocks
    mkdir -p "$(dirname "$output_path")"
    cp microsocks "$output_path"
    
    local size=$(get_binary_size "$output_path")
    log_tool "microsocks" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_microsocks "$arch"