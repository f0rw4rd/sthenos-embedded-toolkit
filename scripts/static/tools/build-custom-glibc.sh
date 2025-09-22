#!/bin/bash


set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/core/arch_helper.sh"

TOOL_NAME="custom-glibc"
CUSTOM_VERSION="${CUSTOM_VERSION:-1.0.0}"


CUSTOM_LOCAL_SOURCE="/build/example-custom-tool"

main() {
    local arch="${1:-x86_64}"
    
    log "Building $TOOL_NAME for $arch"
    
    if [ "${SKIP_IF_EXISTS:-true}" = "true" ] && [ -f "/build/output/$arch/$TOOL_NAME" ]; then
        local size=$(ls -lh "/build/output/$arch/$TOOL_NAME" | awk '{print $5}')
        log "$TOOL_NAME already built for $arch ($size), skipping..."
        return 0
    fi
    
    BUILD_DIR="/tmp/build-${TOOL_NAME}-${arch}-$$"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    trap "rm -rf '$BUILD_DIR'" EXIT
    
    if [ -n "${CUSTOM_LOCAL_SOURCE:-}" ]; then
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
    
    local toolchain_name=$(get_glibc_toolchain "$arch")
    if [ -z "$toolchain_name" ]; then
        log_error "No glibc toolchain configured for architecture: $arch"
        return 1
    fi
    
    local toolchain_dir="/build/toolchains-glibc/${toolchain_name}"
    if [ ! -d "$toolchain_dir" ]; then
        local bootlin_arch=$(get_bootlin_arch "$arch")
        if [ -n "$bootlin_arch" ]; then
            toolchain_dir=$(find /build/toolchains-glibc -maxdepth 1 -type d -name "${bootlin_arch}--glibc--stable-*" | head -1)
        fi
        
        if [ -z "$toolchain_dir" ] || [ ! -d "$toolchain_dir" ]; then
            log_error "Toolchain not found for $arch"
            return 1
        fi
    fi
    
    export PATH="${toolchain_dir}/bin:$PATH"
    export CC="${toolchain_name}-gcc"
    export CXX="${toolchain_name}-g++"
    export AR="${toolchain_name}-ar"
    export STRIP="${toolchain_name}-strip"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    log "Using compiler: $CC"
    
    
    log "Building with make..."
    make clean || true
    make -j$(nproc) CC="$CC" CFLAGS="$cflags" LDFLAGS="$ldflags" || {
        log_error "Build failed"
        return 1
    }
    
    
    if [ ! -f "custom" ]; then
        log_error "Binary 'custom' not found after build"
        return 1
    fi
    
    ${STRIP:-strip} custom || {
        log_error "Failed to strip binary"
        return 1
    }
    
    mkdir -p "/build/output/$arch"
    cp custom "/build/output/$arch/$TOOL_NAME" || {
        log_error "Failed to install binary"
        return 1
    }
    
    local size=$(ls -lh "/build/output/$arch/$TOOL_NAME" | awk '{print $5}')
    log "$TOOL_NAME built successfully for $arch ($size)"
    
    trap - EXIT
    rm -rf "$BUILD_DIR"
    
    return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

