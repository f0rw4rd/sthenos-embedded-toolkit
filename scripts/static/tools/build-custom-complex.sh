#!/bin/bash


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"        # Core functions: setup_arch, download_source, etc.
source "$LIB_DIR/core/compile_flags.sh"   # Architecture-specific compiler flags
source "$LIB_DIR/build_helpers.sh"  # Build utilities: standard_configure, install_binary, etc.

TOOL_NAME="custom"                                                    # Internal name (used for logging/output)
CUSTOM_VERSION="${CUSTOM_VERSION:-1.0.0}"                            # Version (can be overridden via env var)



CUSTOM_LOCAL_SOURCE="/build/example-custom-tool"



configure_custom() {
    local arch=$1
    
    
    return 0
}

build_custom_impl() {
    local arch=$1
    
    make clean || true
    
    make -j$(nproc 2>/dev/null || echo 4) || make  
}

install_custom() {
    local arch=$1
    local binary_name="custom"  # Name of the output binary
    
    install_binary "./$binary_name" "$arch" "$binary_name" "$TOOL_NAME"
}

build_custom() {
    local arch=$1
    
    if check_binary_exists "$arch" "$TOOL_NAME"; then
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Unknown architecture: $arch"
        return 1
    }
    
    download_toolchain "$arch" || return 1
    
    local build_dir
    build_dir=$(create_build_dir "$TOOL_NAME" "$arch")
    
    trap "cleanup_build_dir '$build_dir'" EXIT
    
    cd "$build_dir"
    
    if [ -n "${CUSTOM_LOCAL_SOURCE:-}" ]; then
        log_tool "$TOOL_NAME" "Using local source from $CUSTOM_LOCAL_SOURCE"
        
        if [ ! -d "$CUSTOM_LOCAL_SOURCE" ]; then
            log_tool_error "$TOOL_NAME" "Local source directory not found: $CUSTOM_LOCAL_SOURCE"
            return 1
        fi
        
        cp -r "$CUSTOM_LOCAL_SOURCE"/* "$build_dir/" || {
            log_tool_error "$TOOL_NAME" "Failed to copy local source"
            return 1
        }
    else
        download_source "$TOOL_NAME" "$CUSTOM_VERSION" "$CUSTOM_URL" || {
            log_tool_error "$TOOL_NAME" "Failed to download source"
            return 1
        }
        
        tar xf "/build/sources/$(basename "$CUSTOM_URL")"
        
        cd "custom-tool-${CUSTOM_VERSION}" || cd "custom-${CUSTOM_VERSION}" || cd custom* || {
            log_tool_error "$TOOL_NAME" "Failed to enter source directory"
            return 1
        }
    fi
    
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export_cross_compiler "$CROSS_COMPILE"
    
    
    
    
    configure_custom "$arch" || {
        log_tool_error "$TOOL_NAME" "Configure failed for $arch"
        return 1
    }
    
    build_custom_impl "$arch" || {
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    }
    
    install_custom "$arch" || {
        log_tool_error "$TOOL_NAME" "Installation failed for $arch"
        return 1
    }
    
    
    trap - EXIT
    cleanup_build_dir "$build_dir"
    
    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>\nBuild $TOOL_NAME for specified architecture" "$@"
    
    local arch=$1
    
    mkdir -p "/build/output/$arch"
    
    build_custom "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

