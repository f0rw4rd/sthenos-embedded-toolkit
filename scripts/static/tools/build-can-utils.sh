#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"        # Core functions: setup_arch, download_source, etc.
source "$LIB_DIR/core/compile_flags.sh"   # Architecture-specific compiler flags
source "$LIB_DIR/build_helpers.sh"  # Build utilities: standard_configure, install_binary, etc.

CAN_UTILS_VERSION="${CAN_UTILS_VERSION:-2025.01}"
CAN_UTILS_URL="https://github.com/linux-can/can-utils/archive/refs/tags/v${CAN_UTILS_VERSION}.tar.gz"
CAN_UTILS_SHA512="bc5639c5d93af51cfb5920bc13efec2a660064d1809cb2cee9b234079d5288bc9db2bedf85fe841b8493f5554fbfbbe9f4bf5a88d8957f4a8ccdc3a1abf74153"

build_can_utils() {
    local arch=$1
    local build_dir=$(create_build_dir "can-utils" "$arch")
    local TOOL_NAME="can-utils"
    local can_dir=$(get_output_dir "$arch" "can-utils")
    
    if [ -d "$can_dir" ] && [ "$(ls -A "$can_dir" 2>/dev/null)" ]; then
        local tool_count=$(ls -1 "$can_dir" | wc -l)
        log_tool "can-utils" "Already built for $arch ($tool_count tools in ${can_dir##*/})"
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    cd "$build_dir"
    
    log_tool "can-utils" "Building can-utils for $arch..."
    
    if ! download_and_extract "$CAN_UTILS_URL" "$build_dir" 0 "$CAN_UTILS_SHA512"; then
        log_tool_error "can-utils" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/can-utils-${CAN_UTILS_VERSION}"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    make clean || true
    
    CC="${CC}" \
    CFLAGS="${CFLAGS:-} $cflags -I./include" \
    LDFLAGS="${LDFLAGS:-} $ldflags" \
    make -k -j$(nproc) || {
        if [ ! -f "candump" ] || [ ! -f "cansend" ]; then
            log_tool_error "can-utils" "Core utilities failed to build for $arch"
            cleanup_build_dir "$build_dir"
            return 1
        fi
        log_tool "can-utils" "Some optional components failed, but core utilities built successfully"
    }
    
    # can_dir already defined at the top of the function
    mkdir -p "$can_dir"
    
    local tools="candump cansend canplayer cangen canbusload canfdtest isotpdump isotprecv isotpsend"
    local installed_count=0
    for tool in $tools; do
        if [ -f "$tool" ]; then
            $STRIP "$tool"
            cp "$tool" "$can_dir/"
            installed_count=$((installed_count + 1))
        fi
    done
    
    local extra_tools="canlogserver bcmserver slcan_attach slcand can-calc-bit-timing mcp251xfd-dump"
    for tool in $extra_tools; do
        if [ -f "$tool" ]; then
            $STRIP "$tool" 2>/dev/null || true
            cp "$tool" "$can_dir/"
            installed_count=$((installed_count + 1))
        fi
    done
    
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
