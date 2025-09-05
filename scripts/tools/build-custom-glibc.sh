#!/bin/bash

####################################################################################################
# CUSTOM TOOL BUILD TEMPLATE - GLIBC VERSION
# 
# This is a placeholder/template script for building custom tools with glibc toolchains.
# This version uses glibc instead of musl for better compatibility with some libraries.
#
# USAGE:
#   1. Replace CUSTOM_* variables with your tool's information
#   2. Implement the build steps
#   3. The tool will be available via: ./build custom-glibc --arch <architecture>
#
####################################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source glibc build system libraries
source "$SCRIPT_DIR/../lib/logging.sh"

# ==================== CUSTOMIZE: Tool Configuration ====================
TOOL_NAME="custom-glibc"
CUSTOM_VERSION="${CUSTOM_VERSION:-1.0.0}"

# Option 1: Download from URL (comment out if using local source)
# CUSTOM_URL="https://example.com/custom-tool-${CUSTOM_VERSION}.tar.gz"

# Option 2: Use local source code (DEFAULT - uses example)
CUSTOM_LOCAL_SOURCE="/build/example-custom-tool"

# ==================== Main Build Function ====================
main() {
    local arch="${1:-x86_64}"
    
    log "Building $TOOL_NAME for $arch"
    
    # Check if binary already exists
    if [ "${SKIP_IF_EXISTS:-true}" = "true" ] && [ -f "/build/output/$arch/$TOOL_NAME" ]; then
        local size=$(ls -lh "/build/output/$arch/$TOOL_NAME" | awk '{print $5}')
        log "$TOOL_NAME already built for $arch ($size), skipping..."
        return 0
    fi
    
    # Setup build directory
    BUILD_DIR="/tmp/build-${TOOL_NAME}-${arch}-$$"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Cleanup on exit
    trap "rm -rf '$BUILD_DIR'" EXIT
    
    # ==================== CUSTOMIZE: Source Code Handling ====================
    if [ -n "${CUSTOM_LOCAL_SOURCE:-}" ]; then
        # Copy local source
        log "Using local source from $CUSTOM_LOCAL_SOURCE"
        
        if [ ! -d "$CUSTOM_LOCAL_SOURCE" ]; then
            log_error "Local source directory not found: $CUSTOM_LOCAL_SOURCE"
            return 1
        fi
        
        cp -r "$CUSTOM_LOCAL_SOURCE"/* "$BUILD_DIR/" || {
            log_error "Failed to copy local source"
            return 1
        }
    else
        # Download and extract source
        if [ -z "${CUSTOM_URL:-}" ]; then
            log_error "No source specified. Set either CUSTOM_URL or CUSTOM_LOCAL_SOURCE"
            return 1
        fi
        
        log "Downloading source from $CUSTOM_URL"
        wget -q "$CUSTOM_URL" -O source.tar.gz || {
            log_error "Failed to download source"
            return 1
        }
        
        tar xzf source.tar.gz
        cd custom-tool-${CUSTOM_VERSION} || cd custom-${CUSTOM_VERSION} || cd custom*
    fi
    
    # ==================== Setup Toolchain ====================
    # The glibc build system sets up the toolchain differently
    # These are typically already set by the glibc build system:
    # - CC, CXX, AR, RANLIB, STRIP, etc.
    # - CFLAGS, LDFLAGS with proper paths
    
    if [ -z "${CC:-}" ]; then
        log_error "Compiler not set. This script should be called from the glibc build system"
        return 1
    fi
    
    log "Using compiler: $CC"
    
    # ==================== CUSTOMIZE: Build Steps ====================
    
    # For simple Makefile projects
    log "Building with make..."
    make clean || true
    make -j$(nproc) CC="$CC" CFLAGS="${CFLAGS:-} -static" LDFLAGS="${LDFLAGS:-} -static" || {
        log_error "Build failed"
        return 1
    }
    
    # For autoconf projects, uncomment:
    # ./configure --host="$HOST" --enable-static --disable-shared
    # make -j$(nproc)
    
    # ==================== Install ====================
    if [ ! -f "custom" ]; then
        log_error "Binary 'custom' not found after build"
        return 1
    fi
    
    # Strip the binary
    ${STRIP:-strip} custom || {
        log_error "Failed to strip binary"
        return 1
    }
    
    # Install with glibc suffix
    mkdir -p "/build/output/$arch"
    cp custom "/build/output/$arch/$TOOL_NAME" || {
        log_error "Failed to install binary"
        return 1
    }
    
    local size=$(ls -lh "/build/output/$arch/$TOOL_NAME" | awk '{print $5}')
    log "$TOOL_NAME built successfully for $arch ($size)"
    
    # Cleanup
    trap - EXIT
    rm -rf "$BUILD_DIR"
    
    return 0
}

# Entry point
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

####################################################################################################
# NOTES:
#
# 1. This script is designed to be called by the glibc build system
# 2. The output binary will be named 'custom-glibc' to differentiate from musl version
# 3. Glibc binaries may be larger but can have better compatibility with some libraries
# 4. The toolchain environment variables should be set by the calling build system
# 5. For complex builds, refer to scripts/tools/build-ltrace.sh as an example
#
####################################################################################################