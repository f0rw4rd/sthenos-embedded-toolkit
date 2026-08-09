#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/shared_lib_helpers.sh"

TOOL_NAME="tls-noverify"
# Pin to an immutable commit archive, not refs/heads/main.tar.gz: GitHub
# regenerates the branch tarball whenever main moves (and can re-tar it), which
# breaks the pinned SHA512. A per-commit archive is stable, and its <sha>.tar.gz
# filename also avoids the main.tar.gz name collision across github tools.
TLS_PRELOADER_COMMIT="44579e80c6c9f9fd831765fa87f34703d942e4d5"
TLS_PRELOADER_URL="https://github.com/f0rw4rd/tls-preloader/archive/${TLS_PRELOADER_COMMIT}.tar.gz"
TLS_PRELOADER_SHA512="eacb6208a48456e43513f1be9ec2a071d128709ea45b4814277aecc9b9d1568c71d4071ed6f4a6972fb6d9d438dc90da94df36d3a0c3f3b906abeca210a2fbec"

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
    if check_shared_library_exists "$arch" "libtlsnoverify"; then
        return 0
    fi
    
    log "Building tls-noverify for $arch..."
    
    local output_dir="${STATIC_OUTPUT_DIR:-/build/output}/$arch/shared/${LIBC_TYPE:-musl}"
    local output_file="$output_dir/libtlsnoverify.so"
    mkdir -p "$output_dir"
    
    # Setup toolchain
    if ! setup_shared_toolchain "$arch"; then
        return 1
    fi
    
    local src_dir="/tmp/tls-preloader-src-$$"
    log "Downloading and extracting tls-preloader source..."
    
    mkdir -p "$src_dir"
    
    if ! download_and_extract "$TLS_PRELOADER_URL" "$src_dir" 1 "$TLS_PRELOADER_SHA512"; then
        log_error "Failed to download and extract tls-preloader source"
        cleanup_build_dir "$src_dir"
        return 1
    fi
    
    cd "$src_dir"
    log "Using tls-preloader pinned at ${TLS_PRELOADER_COMMIT:0:12}"
    
    local orig_dir="$(pwd)"
    
    make clean >/dev/null 2>&1 || true
    
    log "Building libtlsnoverify.so using Makefile..."
    
    if ! make; then
        log_error "Make failed"
        make clean >/dev/null 2>&1 || true
        cleanup_build_dir "$src_dir"
        return 1
    fi
    
    if [ ! -f "libtlsnoverify.so" ]; then
        log_error "libtlsnoverify.so not found after build"
        make clean >/dev/null 2>&1 || true
        cleanup_build_dir "$src_dir"
        return 1
    fi
    
    log "Stripping libtlsnoverify.so..."
    $STRIP libtlsnoverify.so 2>/dev/null || true
    
    log "Copying to output directory..."
    cp libtlsnoverify.so "$output_file"
    
    make clean >/dev/null 2>&1 || true
    cleanup_build_dir "$src_dir"
    
    local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
    log "Successfully built: $output_file ($size)"
    
    return 0
}

# Execute main function with all arguments
main "$@"