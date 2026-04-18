#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/shared_lib_helpers.sh"

SHELL_LIBS=(shell-bind shell-reverse shell-env shell-fifo shell-helper)
SOURCE_DIR="${BUILD_DIR:-/build}/shared-libs"

# Main execution when called as script
main() {
    local arch="${1:-}"
    
    if [ -z "$arch" ]; then
        echo "Usage: $0 <arch>"
        echo "Builds all shell libraries: ${SHELL_LIBS[@]}"
        exit 1
    fi
    
    arch=$(map_arch_name "$arch")
    
    # Check if toolchain is available
    if ! check_toolchain_availability "$arch"; then
        return 2
    fi
    
    # Setup toolchain
    if ! setup_shared_toolchain "$arch"; then
        return 1
    fi
    
    local output_dir="${STATIC_OUTPUT_DIR:-/build/output}/$arch/shared/${LIBC_TYPE:-musl}"
    local failed=0
    local success=0
    
    log "Building shell libraries for $arch with ${LIBC_TYPE:-musl}"
    log "Libraries to build: ${SHELL_LIBS[@]}"
    
    mkdir -p "$output_dir"
    
    for lib_name in "${SHELL_LIBS[@]}"; do
        local source_file="$SOURCE_DIR/${lib_name}.c"
        local output_file="$output_dir/${lib_name}.so"
        
        if [ -f "$output_file" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
            local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
            log "Already built: $output_file ($size)"
            success=$((success + 1))
            continue
        fi
        
        if [ ! -f "$source_file" ]; then
            log_error "Source file not found: $source_file"
            failed=$((failed + 1))
            continue
        fi
        
        log "Building $lib_name..."
        
        local cflags=$(get_compile_flags "$arch" "shared" "")
        cflags="$cflags -D_GNU_SOURCE"
        
        # Add library-specific defines
        case "$lib_name" in
            shell-bind)
                cflags="$cflags -DSHELL_PORT=4444"
                ;;
            shell-reverse)
                cflags="$cflags -DDEFAULT_HOST=\"127.0.0.1\" -DDEFAULT_PORT=4444"
                ;;
        esac
        
        local ldflags=$(get_link_flags "$arch" "shared")
        ldflags="$ldflags -ldl"
        
        local build_dir="/tmp/build-${lib_name}-${arch}-${LIBC_TYPE:-musl}-$$"
        mkdir -p "$build_dir"
        cd "$build_dir"
        
        if ! $CC $cflags -c "$source_file" -o "${lib_name}.o" 2>&1; then
            log_error "Compilation failed for $lib_name/$arch"
            cleanup_build_dir "$build_dir"
            failed=$((failed + 1))
            continue
        fi
        
        if ! $CC $ldflags -o "${lib_name}.so" "${lib_name}.o" 2>&1; then
            log_error "Linking failed for $lib_name/$arch"
            cleanup_build_dir "$build_dir"
            failed=$((failed + 1))
            continue
        fi
        
        $STRIP "${lib_name}.so" 2>/dev/null || true
        
        cp "${lib_name}.so" "$output_file"
        
        cleanup_build_dir "$build_dir"
        
        local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
        log "Successfully built: $output_file ($size)"
        success=$((success + 1))
    done
    
    log "Shell libraries build complete: $success succeeded, $failed failed"
    
    if [ $failed -gt 0 ]; then
        return 1
    fi
    return 0
}

# Execute main function with all arguments
main "$@"