#!/bin/bash
# Build script for gdbserver
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

GDB_VERSION="${GDB_VERSION:-11.2}"
GDB_URL="https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz"

build_gdbserver() {
    local arch=$1
    local build_dir="/tmp/gdbserver-build-${arch}-$$"
    local TOOL_NAME="gdbserver"
    
    # Check if binary already exists
    if check_binary_exists "$arch" "gdbserver"; then
        return 0
    fi
    
    echo "[gdbserver] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "gdb" "$GDB_VERSION" "$GDB_URL" || return 1
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Extract source
    tar xf /build/sources/gdb-${GDB_VERSION}.tar.xz
    cd gdb-${GDB_VERSION}
    
    # Configure with centralized build flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    ./configure \
        --host=$HOST \
        --target=$HOST \
        --prefix=/usr \
        --disable-gdb \
        --enable-gdbserver \
        --disable-gdbtk \
        --disable-tui \
        --disable-werror \
        --without-x \
        --disable-sim \
        --without-lzma \
        --without-python \
        --without-guile \
        --without-gmp \
        --without-mpfr \
        --disable-inprocess-agent \
        --disable-nls \
        --without-expat \
        --disable-source-highlight || {
        echo "[gdbserver] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build only gdbserver
    make -j$(nproc) all-gdbserver MAKEINFO=true || {
        echo "[gdbserver] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Strip and copy binary
    $STRIP gdbserver/gdbserver
    cp gdbserver/gdbserver "/build/output/$arch/gdbserver"
    
    # Get size
    local size=$(ls -lh "/build/output/$arch/gdbserver" | awk '{print $5}')
    echo "[gdbserver] Built successfully for $arch ($size)"
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    return 0
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    echo "Architectures: arm32v5le arm32v5lehf arm32v7le arm32v7lehf mips32v2le mips32v2be ppc32be ix86le x86_64 aarch64 mips64le ppc64le"
    exit 1
fi

arch=$1
build_gdbserver "$arch"