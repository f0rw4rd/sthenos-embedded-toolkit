#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/shared_lib_helpers.sh"

TOOL_NAME="custom-lib"
SOURCE_DIR="${BUILD_DIR:-/build}/example-custom-lib"

# Main execution when called as script
main() {
    local arch="${1:-}"
    
    if [ -z "$arch" ]; then
        echo "Usage: $0 <arch>"
        exit 1
    fi
    
    arch=$(map_arch_name "$arch")
    
    # Check if toolchain is available
    if ! check_toolchain_availability "$arch"; then
        return 2
    fi
    
    # Check if already built
    if check_shared_library_exists "$arch" "$TOOL_NAME"; then
        return 0
    fi
    
    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Source directory not found: $SOURCE_DIR"
        return 1
    fi
    
    log "Building custom-lib for $arch..."
    
    local output_dir="${STATIC_OUTPUT_DIR:-/build/output}/$arch/shared/${LIBC_TYPE:-musl}"
    local output_file="$output_dir/${TOOL_NAME}.so"
    mkdir -p "$output_dir"
    
    # Setup toolchain
    if ! setup_shared_toolchain "$arch"; then
        return 1
    fi
    
    local cflags=$(get_compile_flags "$arch" "shared" "")
    cflags="$cflags -D_GNU_SOURCE"
    
    local ldflags=$(get_link_flags "$arch" "shared")
    ldflags="$ldflags -ldl"
    
    local build_dir="/tmp/build-${TOOL_NAME}-${arch}-${LIBC_TYPE:-musl}-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    cp -r "$SOURCE_DIR"/* "$build_dir/"
    
    log_debug "CC=$CC"
    log_debug "CFLAGS=$cflags"
    log_debug "LDFLAGS=$ldflags"
    
    # Use the Makefile to build
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    if ! make clean 2>&1; then
        log_debug "Clean failed (may be expected on first run)"
    fi
    
    if ! make all 2>&1; then
        log_error "Make failed for $TOOL_NAME/$arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    if [ ! -f "${TOOL_NAME}.so" ]; then
        log_error "${TOOL_NAME}.so not found after build"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    $STRIP "${TOOL_NAME}.so" 2>/dev/null || true
    
    cp "${TOOL_NAME}.so" "$output_file"
    
    cleanup_build_dir "$build_dir"
    
    local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
    log "Successfully built: $output_file ($size)"
    
    return 0
}

# Execute main function with all arguments
main "$@"