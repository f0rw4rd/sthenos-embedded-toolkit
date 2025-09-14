#!/bin/bash

# Custom tool build template
# Put your source in example-custom-tool/, ensure you have a Makefile, then build

# Required build system setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

# Tool settings
TOOL_NAME="custom"
SOURCE_PATH="/build/example-custom-tool"    # Your source code directory
BINARY_NAME="custom"                        # Name of final executable

# Main build function
build_custom() {
    local arch=$1
    
    # Skip if already built
    if check_binary_exists "$arch" "$TOOL_NAME"; then
        return 0
    fi
    
    # Setup cross-compilation
    setup_toolchain_for_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Failed to setup toolchain for $arch"
        return 1
    }
    download_toolchain "$arch" || return 1
    
    # Create build directory and copy source
    local build_dir
    build_dir=$(create_build_dir "$TOOL_NAME" "$arch")
    trap "cleanup_build_dir '$build_dir'" EXIT
    
    cp -r "$SOURCE_PATH"/* "$build_dir/"
    cd "$build_dir"
    
    # Get compiler flags
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    # Export build environment
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export_cross_compiler "$CROSS_COMPILE"
    
    # Build and install
    make clean || true
    make -j$(nproc 2>/dev/null || echo 4) || make
    install_binary "./$BINARY_NAME" "$arch" "$BINARY_NAME" "$TOOL_NAME"
    
    # Cleanup
    trap - EXIT
    cleanup_build_dir "$build_dir"
    return 0
}

# Entry point
main() {
    validate_args 1 "Usage: $0 <architecture>" "$@"
    local arch=$1
    mkdir -p "/build/output/$arch"
    build_custom "$arch"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

# Customization:
# - Change SOURCE_PATH to your directory 
# - Change BINARY_NAME for different output name
# - Add dependencies, configure steps, or multiple binaries as needed