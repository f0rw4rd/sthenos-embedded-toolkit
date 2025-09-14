#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"        # Core functions: setup_arch, download_source, etc.
source "$LIB_DIR/core/compile_flags.sh"   # Architecture-specific compiler flags
source "$LIB_DIR/build_helpers.sh"  # Build utilities: standard_configure, install_binary, etc.

CAN_UTILS_VERSION="${CAN_UTILS_VERSION:-2025.01}"
CAN_UTILS_URL="https://github.com/linux-can/can-utils/archive/refs/tags/v${CAN_UTILS_VERSION}.tar.gz"

build_can_utils() {
    local arch=$1
    local build_dir=$(create_build_dir "can-utils" "$arch")
    local TOOL_NAME="can-utils"
    
    # Check if can-utils directory exists and has tools
    if [ -d "/build/output/$arch/can-utils" ] && [ "$(ls -A /build/output/$arch/can-utils 2>/dev/null)" ]; then
        local tool_count=$(ls -1 /build/output/$arch/can-utils | wc -l)
        log_tool "can-utils" "Already built for $arch ($tool_count tools in can-utils/)"
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    cd "$build_dir"
    
    log_tool "can-utils" "Building can-utils for $arch..."
    
    # GitHub archive URLs have different filename pattern
    local source_file="/build/sources/v${CAN_UTILS_VERSION}.tar.gz"
    local expected_file="/build/sources/can-utils-${CAN_UTILS_VERSION}.tar.gz"
    
    download_source "can-utils" "$CAN_UTILS_VERSION" "$CAN_UTILS_URL" || return 1
    
    # Rename the file if needed
    if [ -f "$source_file" ] && [ ! -f "$expected_file" ]; then
        mv "$source_file" "$expected_file"
    fi
    
    tar xf "$expected_file"
    cd can-utils-${CAN_UTILS_VERSION}
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    # can-utils uses a simple Makefile, not autotools
    # We need to override CC and flags directly
    make clean || true
    
    # Build with -k to continue even if some targets fail
    # This is needed because some optional components may not build with musl
    CC="${CC}" \
    CFLAGS="${CFLAGS:-} $cflags -I./include" \
    LDFLAGS="${LDFLAGS:-} $ldflags" \
    make -k -j$(nproc) || {
        # Check if at least the core utilities were built
        if [ ! -f "candump" ] || [ ! -f "cansend" ]; then
            log_tool_error "can-utils" "Core utilities failed to build for $arch"
            cleanup_build_dir "$build_dir"
            return 1
        fi
        log_tool "can-utils" "Some optional components failed, but core utilities built successfully"
    }
    
    # Create dedicated directory for CAN utilities
    local can_dir="/build/output/$arch/can-utils"
    mkdir -p "$can_dir"
    
    # Strip and install the main utilities
    local tools="candump cansend canplayer cangen canbusload canfdtest isotpdump isotprecv isotpsend"
    local installed_count=0
    for tool in $tools; do
        if [ -f "$tool" ]; then
            $STRIP "$tool"
            cp "$tool" "$can_dir/"
            installed_count=$((installed_count + 1))
        fi
    done
    
    # Also copy some additional useful utilities if they exist
    local extra_tools="canlogserver bcmserver slcan_attach slcand can-calc-bit-timing mcp251xfd-dump"
    for tool in $extra_tools; do
        if [ -f "$tool" ]; then
            $STRIP "$tool" 2>/dev/null || true
            cp "$tool" "$can_dir/"
            installed_count=$((installed_count + 1))
        fi
    done
    
    # Copy J1939 utilities if they exist
    local j1939_tools="j1939spy j1939cat j1939acd j1939sr testj1939"
    for tool in $j1939_tools; do
        if [ -f "$tool" ]; then
            $STRIP "$tool" 2>/dev/null || true
            cp "$tool" "$can_dir/"
            installed_count=$((installed_count + 1))
        fi
    done
    
    log_tool "can-utils" "Built successfully for $arch ($installed_count tools installed in can-utils/)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_can_utils "$arch"