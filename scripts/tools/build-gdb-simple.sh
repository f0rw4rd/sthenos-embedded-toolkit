#\!/bin/bash
# Simplified GDB build script based on gdb-static approach
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

GDB_VERSION="${GDB_VERSION:-15.2}"
GDB_URL="https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz"

build_gdb_simple() {
    local arch=$1
    local build_dir="/tmp/gdb-build-${arch}-simple-$$"
    local TOOL_NAME="gdb-simple"
    
    echo "[gdb] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Download and extract GDB
    download_source "gdb" "$GDB_VERSION" "$GDB_URL" || return 1
    tar xf /build/sources/gdb-${GDB_VERSION}.tar.xz
    cd gdb-${GDB_VERSION}
    
    # Use centralized build flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local cxxflags=$(get_cxx_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export CXXFLAGS="$cxxflags"
    export LDFLAGS="$ldflags"
    
    # Configure with static options
    ./configure \
        --host=$HOST \
        --disable-shared \
        --enable-static \
        --with-static-standard-libraries \
        --disable-gdbserver \
        --disable-tui \
        --disable-nls \
        --without-python \
        --without-guile \
        --without-lzma \
        --disable-source-highlight \
        --disable-werror || {
        echo "[gdb] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build
    make -j$(nproc) || {
        echo "[gdb] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Install the binary
    if [ -f "gdb/gdb" ]; then
        $STRIP gdb/gdb
        mkdir -p "/build/output/$arch"
        cp gdb/gdb "/build/output/$arch/gdb-simple"
        echo "[gdb] Built successfully for $arch"
        
        # Cleanup
        cd /
        rm -rf "$build_dir"
        return 0
    else
        echo "[gdb] Failed to build gdb for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    fi
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_gdb_simple "$arch"
