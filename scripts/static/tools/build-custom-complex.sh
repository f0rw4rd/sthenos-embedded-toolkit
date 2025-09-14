#!/bin/bash

####################################################################################################
# CUSTOM TOOL BUILD TEMPLATE
# 
# This is a placeholder/template script for building custom tools in the Sthenos Embedded Toolkit.
# Users can modify this script to add their own tools without changing the build system.
#
# USAGE:
#   1. Replace CUSTOM_* variables with your tool's information
#   2. Implement the build_custom() function with your tool's build steps
#   3. The tool will automatically be available via: ./build custom --arch <architecture>
#
# IMPORTANT NOTES:
#   - DO NOT modify the sourced libraries or function signatures
#   - DO NOT remove the setup_arch, download_toolchain, or check_binary_exists calls
#   - DO NOT remove the trap/cleanup logic - it ensures proper cleanup on failure
#   - DO NOT change the main() function structure
#
####################################################################################################

# ==================== REQUIRED: Source build system libraries ====================
# These provide essential functions for cross-compilation, logging, and build management
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"        # Core functions: setup_arch, download_source, etc.
source "$LIB_DIR/core/compile_flags.sh"   # Architecture-specific compiler flags
source "$LIB_DIR/build_helpers.sh"  # Build utilities: standard_configure, install_binary, etc.

# ==================== CUSTOMIZE: Tool Configuration ====================
# Replace these with your tool's information
TOOL_NAME="custom"                                                    # Internal name (used for logging/output)
CUSTOM_VERSION="${CUSTOM_VERSION:-1.0.0}"                            # Version (can be overridden via env var)

# Option 1: Download from URL (comment out if using local source)
# CUSTOM_URL="https://example.com/custom-tool-${CUSTOM_VERSION}.tar.gz" # Download URL for source

# Option 2: Use local source code (uncomment and set path)
# CUSTOM_LOCAL_SOURCE="/build/local-sources/my-tool"                 # Path to local source directory
# CUSTOM_LOCAL_SOURCE="../my-tool-src"                               # Or relative to /build

# Example: Use the included example-custom-tool with ASCII art demo (DEFAULT)
CUSTOM_LOCAL_SOURCE="/build/example-custom-tool"

# Optional: Additional URLs for patches or dependencies
# CUSTOM_PATCH_URL="https://example.com/patches/custom-${CUSTOM_VERSION}.patch"

# ==================== OPTIONAL: Helper Functions ====================
# Add any tool-specific helper functions here

configure_custom() {
    local arch=$1
    
    # For simple Makefile projects (like example-custom-tool), skip configure
    # Uncomment below for autoconf-based projects:
    # standard_configure "$arch" "$TOOL_NAME" \
    #     --enable-static \
    #     --disable-shared \
    #     --disable-nls
    
    # For the example tool, just return success
    return 0
}

build_custom_impl() {
    local arch=$1
    
    # Clean previous builds
    make clean || true
    
    # make it in parallel 
    make -j$(nproc 2>/dev/null || echo 4) || make  
}

install_custom() {
    local arch=$1
    local binary_name="custom"  # Name of the output binary
    
    # For example-custom-tool, binary is in current directory
    install_binary "./$binary_name" "$arch" "$binary_name" "$TOOL_NAME"
}

# ==================== REQUIRED: Main Build Function ====================
# This is the core build function called by the build system
build_custom() {
    local arch=$1
    
    # REQUIRED: Check if binary already exists (respects SKIP_IF_EXISTS env var)
    if check_binary_exists "$arch" "$TOOL_NAME"; then
        return 0
    fi
    
    # REQUIRED: Setup architecture-specific variables and toolchain
    # Sets: CROSS_COMPILE, HOST, CC, CXX, AR, STRIP, etc.
    setup_toolchain_for_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Unknown architecture: $arch"
        return 1
    }
    
    # REQUIRED: Ensure toolchain is available
    download_toolchain "$arch" || return 1
    
    # REQUIRED: Create isolated build directory
    local build_dir
    build_dir=$(create_build_dir "$TOOL_NAME" "$arch")
    
    # REQUIRED: Setup cleanup trap for build directory
    trap "cleanup_build_dir '$build_dir'" EXIT
    
    # ==================== CUSTOMIZE: Source Code Handling ====================
    cd "$build_dir"
    
    # Check if using local source or downloading
    if [ -n "${CUSTOM_LOCAL_SOURCE:-}" ]; then
        # Option 2: Copy local source code
        log_tool "$TOOL_NAME" "Using local source from $CUSTOM_LOCAL_SOURCE"
        
        if [ ! -d "$CUSTOM_LOCAL_SOURCE" ]; then
            log_tool_error "$TOOL_NAME" "Local source directory not found: $CUSTOM_LOCAL_SOURCE"
            return 1
        fi
        
        # Copy source to build directory
        cp -r "$CUSTOM_LOCAL_SOURCE"/* "$build_dir/" || {
            log_tool_error "$TOOL_NAME" "Failed to copy local source"
            return 1
        }
    else
        # Option 1: Download and extract source
        download_source "$TOOL_NAME" "$CUSTOM_VERSION" "$CUSTOM_URL" || {
            log_tool_error "$TOOL_NAME" "Failed to download source"
            return 1
        }
        
        # Extract based on compression format
        # Adjust extension (.tar.gz, .tar.xz, .tar.bz2, .zip) as needed
        tar xf "/build/sources/$(basename "$CUSTOM_URL")"
        
        # Enter source directory (adjust name pattern as needed)
        cd "custom-tool-${CUSTOM_VERSION}" || cd "custom-${CUSTOM_VERSION}" || cd custom* || {
            log_tool_error "$TOOL_NAME" "Failed to enter source directory"
            return 1
        }
    fi
    
    # OPTIONAL: Apply patches
    # if [ -n "$CUSTOM_PATCH_URL" ]; then
    #     download_source "${TOOL_NAME}-patch" "$CUSTOM_VERSION" "$CUSTOM_PATCH_URL"
    #     patch -p1 < "/build/sources/$(basename "$CUSTOM_PATCH_URL")"
    # fi
    
    # REQUIRED: Get architecture-specific compiler flags
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    # REQUIRED: Export build environment
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export_cross_compiler "$CROSS_COMPILE"
    
    # OPTIONAL: Additional environment variables your tool might need
    # export PKG_CONFIG_PATH="/dependencies/$arch/lib/pkgconfig"
    # export LIBS="-lm -lz"
    
    # OPTIONAL: Create cross-compilation cache file (for autoconf-based builds)
    # Some tools need hints for cross-compilation
    # create_cross_cache "$arch" "config.cache"
    
    # ==================== CUSTOMIZE: Configure, Build, Install ====================
    
    # Step 1: Configure (skip for simple Makefile projects)
    configure_custom "$arch" || {
        log_tool_error "$TOOL_NAME" "Configure failed for $arch"
        return 1
    }
    
    # Step 2: Build
    build_custom_impl "$arch" || {
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    }
    
    # Step 3: Install
    install_custom "$arch" || {
        log_tool_error "$TOOL_NAME" "Installation failed for $arch"
        return 1
    }
    
    # OPTIONAL: Verify the binary is statically linked
    # verify_static_binary "/build/output/$arch/$TOOL_NAME" "$TOOL_NAME"
    
    # REQUIRED: Clean up trap and build directory
    trap - EXIT
    cleanup_build_dir "$build_dir"
    
    return 0
}

# ==================== REQUIRED: Script Entry Point ====================
# DO NOT MODIFY THIS SECTION
main() {
    # Validate command line arguments
    validate_args 1 "Usage: $0 <architecture>\nBuild $TOOL_NAME for specified architecture" "$@"
    
    local arch=$1
    
    # Ensure output directory exists
    mkdir -p "/build/output/$arch"
    
    # Call the main build function
    build_custom "$arch"
}

# Only run main if script is executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

####################################################################################################
# EXAMPLES AND ADDITIONAL NOTES
#
# 1. SIMPLE TOOL (make-based, no configure):
#    - Skip configure_custom function
#    - In build_custom_impl: just run make with appropriate variables
#    - Example: make CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" static
#
# 2. CMAKE-BASED TOOL:
#    configure_custom() {
#        cmake -DCMAKE_C_COMPILER="$CC" \
#              -DCMAKE_CXX_COMPILER="$CXX" \
#              -DCMAKE_BUILD_TYPE=Release \
#              -DBUILD_SHARED_LIBS=OFF \
#              -DCMAKE_C_FLAGS="$CFLAGS" \
#              -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
#              ..
#    }
#
# 3. TOOL WITH DEPENDENCIES:
#    - Check scripts/lib/dependencies.sh for dependency building functions
#    - Example: libpcap, openssl, zlib are commonly needed
#    - Use: local pcap_dir=$(ensure_libpcap "$arch")
#    - Then add to configure: --with-pcap="$pcap_dir"
#
# 4. ARCHITECTURE-SPECIFIC FIXES:
#    if [[ "$arch" == "mips"* ]]; then
#        # MIPS-specific workaround
#        export CFLAGS="$CFLAGS -D_MIPS_SZLONG=32"
#    fi
#
# 5. MULTIPLE OUTPUT BINARIES:
#    - Simply call install_binary multiple times in install_custom()
#    - Each binary will be copied to /build/output/$arch/
#
# 6. DEBUG SUPPORT:
#    - Use log_debug for debug output (shown when DEBUG=1)
#    - Use log_tool for normal progress messages
#    - Use log_tool_error for errors
#
# 7. USING LOCAL SOURCE CODE:
#    Instead of downloading, you can use local source code:
#    - Set CUSTOM_LOCAL_SOURCE to point to your source directory
#    - The path can be absolute or relative to /build
#    - The source will be copied to a temporary build directory
#    - Example paths:
#      CUSTOM_LOCAL_SOURCE="/build/my-local-tool"     # Inside container
#      CUSTOM_LOCAL_SOURCE="../../../my-project"      # Relative path
#      CUSTOM_LOCAL_SOURCE="$HOME/projects/my-tool"   # User directory (mounted)
#    - Make sure your local source is accessible from within the Docker container!
#      You may need to mount it: docker run -v /path/to/source:/build/local-source ...
#
# 8. TESTING YOUR CUSTOM TOOL:
#    ./build custom --arch x86_64        # Build for single arch
#    ./build custom                       # Build for all architectures
#    DEBUG=1 ./build custom --arch x86_64 -d  # Debug mode with verbose output
#
# 9. EXAMPLE INCLUDED:
#    This repo includes example-custom-tool/ with a working demo:
#    - A C program with ASCII art and system info display
#    - Simple Makefile for building
#    - To use it:
#      1. Uncomment: CUSTOM_LOCAL_SOURCE="/build/example-custom-tool"
#      2. Comment out: CUSTOM_URL=...
#      3. In configure_custom, comment out the configure step (Makefile doesn't need it)
#      4. In build_custom_impl, just use: parallel_make
#      5. In install_custom, use: install_binary "./custom" "$arch" "custom" "$TOOL_NAME"
#      6. Build: ./build custom --arch x86_64
#      7. Test: ./output/x86_64/custom --help
#
####################################################################################################