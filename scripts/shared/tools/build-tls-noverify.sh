#!/bin/bash
# Build script for tls-noverify shared library
# Simplified to reuse central toolchain infrastructure

# Build tls-noverify for an architecture
build_tls_noverify() {
    local arch="$1"
    local log_enabled="${2:-true}"
    local debug="${3:-0}"
    
    # Map architecture name
    arch=$(map_arch_name "$arch")
    
    # Check if this architecture supports the current libc type
    if [ "$LIBC_TYPE" = "musl" ]; then
        local musl_name=$(get_musl_toolchain "$arch")
        if [ -z "$musl_name" ]; then
            log_debug "Skipping tls-noverify for $arch - no musl toolchain available"
            return 2  # Special return code for skipped
        fi
    else
        local glibc_name=$(get_glibc_toolchain "$arch")
        if [ -z "$glibc_name" ]; then
            log_debug "Skipping tls-noverify for $arch - no glibc toolchain available"
            return 2  # Special return code for skipped
        fi
    fi
    
    # Set output directory using new structure
    local output_dir="$STATIC_OUTPUT_DIR/$arch/shared/$LIBC_TYPE"
    local output_file="$output_dir/libtlsnoverify.so"
    
    # Check if already built
    if [ -f "$output_file" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
        log "libtlsnoverify.so already built for $arch ($size)"
        return 0
    fi
    
    log "Building tls-noverify for $arch..."
    
    # Download repository as tarball from master/main branch
    local src_dir="/tmp/tls-preloader-src-$$"
    log "Downloading tls-preloader source..."
    
    mkdir -p "$src_dir"
    cd "$src_dir"
    
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/build_helpers.sh"
    if ! download_source "tls-preloader" "main" "https://github.com/f0rw4rd/tls-preloader/archive/refs/heads/main.tar.gz"; then
        log_error "Failed to download tls-preloader source"
        rm -rf "$src_dir"
        return 1
    fi
    
    tar xzf "/build/sources/main.tar.gz"
    cd tls-preloader-main
    log "Using tls-preloader from main branch"
    
    # Ensure output directory exists
    mkdir -p "$output_dir"
    
    if [ "$LIBC_TYPE" = "glibc" ]; then
        # For glibc, add toolchain to PATH
        local toolchain_name=$(get_glibc_toolchain "$arch")
        if [ -z "$toolchain_name" ]; then
            log_error "No glibc toolchain for $arch (this shouldn't happen)"
            rm -rf "$src_dir"
            return 1
        fi
        
        local toolchain_dir="$GLIBC_TOOLCHAINS_DIR/$toolchain_name"
        if [ ! -d "$toolchain_dir" ]; then
            log_error "Toolchain not found at $toolchain_dir"
            rm -rf "$src_dir"
            return 1
        fi
        
        export PATH="$toolchain_dir/bin:$PATH"
        export CC="${toolchain_name}-gcc"
        export STRIP="${toolchain_name}-strip"
    else
        # For musl, setup standard environment
        if ! setup_arch "$arch"; then
            log_error "Failed to setup musl toolchain for $arch"
            rm -rf "$src_dir"
            return 1
        fi
    fi
    
    # Save current directory
    local orig_dir="$(pwd)"
    
    
    # Clean any previous build artifacts
    make clean >/dev/null 2>&1 || true
    
    log "Building libtlsnoverify.so using Makefile..."
    
    if ! make; then
        log_error "Make failed"
        make clean >/dev/null 2>&1 || true
        cd "$orig_dir"
        rm -rf "$src_dir"
        return 1
    fi
    
    # Check if the library was built
    if [ ! -f "libtlsnoverify.so" ]; then
        log_error "libtlsnoverify.so was not created"
        make clean >/dev/null 2>&1 || true
        cd "$orig_dir"
        rm -rf "$src_dir"
        return 1
    fi
    
    # Copy to output directory
    cp libtlsnoverify.so "$output_file"
    
    local size=$(ls -lh "$output_file" | awk '{print $5}')
    log "Successfully built libtlsnoverify.so for $arch ($size)"
    
    # Cleanup
    cd "$orig_dir"
    rm -rf "$src_dir"
    
    return 0
}