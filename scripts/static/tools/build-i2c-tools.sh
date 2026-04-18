#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

I2C_TOOLS_VERSION="${I2C_TOOLS_VERSION:-4.4}"
I2C_TOOLS_URL="https://mirrors.edge.kernel.org/pub/software/utils/i2c-tools/i2c-tools-${I2C_TOOLS_VERSION}.tar.xz"
I2C_TOOLS_SHA512="4f621de0a33730e19ad4080fc52be7231572efe15f77fd69996a077c8ea42339231311a9c4b7d04ec4ab59f350495d21d561513213f7122a2d3826f5059822f3"

build_i2c_tools() {
    local arch=$1
    local build_dir=$(create_build_dir "i2c-tools" "$arch")
    local TOOL_NAME="i2c-tools"
    local SUPPORTED_OS="linux,android"
    local i2c_dir=$(get_output_dir "$arch" "i2c-tools")

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then return 1; fi

    if [ -d "$i2c_dir" ] && [ "$(ls -A "$i2c_dir" 2>/dev/null)" ]; then
        local tool_count=$(ls -1 "$i2c_dir" | wc -l)
        log_tool "i2c-tools" "Already built for $arch ($tool_count tools in ${i2c_dir##*/})"
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1

    cd "$build_dir"

    log_tool "i2c-tools" "Building i2c-tools for $arch..."

    if ! download_and_extract "$I2C_TOOLS_URL" "$build_dir" 0 "$I2C_TOOLS_SHA512"; then
        log_tool_error "i2c-tools" "Failed to download and extract source"
        cleanup_build_dir "$build_dir"
        return 1
    fi

    cd "$build_dir/i2c-tools-${I2C_TOOLS_VERSION}"

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    # Build static library first, then tools linked against it
    # USE_STATIC_LIB=1 links tools against the static libi2c.a
    # BUILD_DYNAMIC_LIB=0 skips shared library (not needed)
    make -j$(nproc) \
        CC="$CC" \
        AR="$AR" \
        STRIP="$STRIP" \
        CFLAGS="$cflags" \
        LDFLAGS="$ldflags" \
        USE_STATIC_LIB=1 \
        BUILD_DYNAMIC_LIB=0 \
        BUILD_STATIC_LIB=1 || {
        log_tool_error "i2c-tools" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }

    mkdir -p "$i2c_dir"

    local tools="i2cdetect i2cdump i2cset i2cget i2ctransfer"
    local installed_count=0
    for tool in $tools; do
        if [ -f "tools/$tool" ]; then
            $STRIP "tools/$tool" 2>/dev/null || true
            cp "tools/$tool" "$i2c_dir/"
            installed_count=$((installed_count + 1))
        else
            log_tool_error "i2c-tools" "Expected binary not found: tools/$tool"
        fi
    done

    if [ $installed_count -eq 0 ]; then
        log_tool_error "i2c-tools" "No binaries were built for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi

    log_tool "i2c-tools" "Built successfully for $arch ($installed_count tools installed in i2c-tools/)"

    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_i2c_tools "$arch"
