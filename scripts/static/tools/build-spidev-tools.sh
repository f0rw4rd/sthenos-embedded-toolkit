#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

TOOL_NAME="spidev-tools"
SUPPORTED_OS="linux,android"
SPI_TOOLS_VERSION="${SPI_TOOLS_VERSION:-1.0.2}"
SPI_TOOLS_URL="https://github.com/cpb-/spi-tools/archive/refs/tags/${SPI_TOOLS_VERSION}.tar.gz"
SPI_TOOLS_SHA512="9e4bb3d00d6f9885735e4e444b7422bba96c40309f9f0dbc93c06ae7147e0042a36e1f19157e95535a894efc0c88fd23ecef53247d3a129719681599390e353f"

build_spidev_tools() {
    local arch=$1
    local build_dir=$(create_build_dir "spidev-tools" "$arch")
    local spi_dir=$(get_output_dir "$arch" "spidev-tools")

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then return 1; fi

    if [ -d "$spi_dir" ] && [ "$(ls -A "$spi_dir" 2>/dev/null)" ]; then
        local tool_count=$(ls -1 "$spi_dir" | wc -l)
        log_tool "spidev-tools" "Already built for $arch ($tool_count tools in ${spi_dir##*/})"
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1

    cd "$build_dir"

    log_tool "spidev-tools" "Building spidev-tools for $arch..."

    if ! download_and_extract "$SPI_TOOLS_URL" "$build_dir" 0 "$SPI_TOOLS_SHA512"; then
        log_tool_error "spidev-tools" "Failed to download and extract source"
        cleanup_build_dir "$build_dir"
        return 1
    fi

    cd "$build_dir/spi-tools-${SPI_TOOLS_VERSION}"

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    # spi-tools uses autotools: run autoreconf then configure.
    # Strip toolchain from PATH: Buildroot glibc toolchains ship broken autoreconf
    # wrappers with a hardcoded Perl @INC pointing at /builds/buildroot.org/...
    # which does not exist. Use only system autotools for this step.
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        /usr/bin/autoreconf -i || {
        log_tool_error "spidev-tools" "autoreconf failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }

    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export_cross_compiler "$CROSS_COMPILE"

    ./configure \
        --host="$HOST" \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking || {
        log_tool_error "spidev-tools" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }

    make -j$(nproc) || {
        log_tool_error "spidev-tools" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }

    mkdir -p "$spi_dir"

    local tools="spi-pipe spi-config"
    local installed_count=0
    for tool in $tools; do
        if [ -f "src/$tool" ]; then
            $STRIP "src/$tool" 2>/dev/null || true
            cp "src/$tool" "$spi_dir/"
            installed_count=$((installed_count + 1))
        else
            log_tool_error "spidev-tools" "Expected binary not found: src/$tool"
        fi
    done

    if [ $installed_count -eq 0 ]; then
        log_tool_error "spidev-tools" "No binaries were built for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi

    log_tool "spidev-tools" "Built successfully for $arch ($installed_count tools installed in spidev-tools/)"

    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_spidev_tools "$arch"
