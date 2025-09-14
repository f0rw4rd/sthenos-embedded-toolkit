#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

build_custom_lib() {
    local arch="$1"
    local libc_type="${2:-glibc}"
    local build_dir="/build/tmp/custom-lib-${arch}-${libc_type}"
    local output_dir="/build/output/${arch}/shared/${libc_type}"
    local output_file="${output_dir}/custom-lib.so"
    
    log_info "Building custom-lib for ${arch} with ${libc_type}"
    
    if [ -f "$output_file" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        log_success "custom-lib already built for ${arch} (${libc_type})"
        return 0
    fi
    
    setup_arch "$arch" || return 2
    setup_toolchain "$arch" "$libc_type" || return 2
    
    rm -rf "$build_dir"
    mkdir -p "$build_dir" "$output_dir"
    
    cp -r /build/example-custom-lib/* "$build_dir/"
    cd "$build_dir"
    
    local cflags="${CFLAGS} ${SHARED_CFLAGS}"
    local ldflags="${LDFLAGS} ${SHARED_LDFLAGS}"
    
    log_info "Compiling custom-lib.c"
    ${CC} ${cflags} -c custom-lib.c -o custom-lib.o || {
        log_error "Failed to compile custom-lib.c"
        return 1
    }
    
    log_info "Linking custom-lib.so"
    ${CC} ${cflags} ${ldflags} -o custom-lib.so custom-lib.o || {
        log_error "Failed to link custom-lib.so"
        return 1
    }
    
    cp custom-lib.so "$output_file"
    
    if [ -f "$output_file" ]; then
        log_success "Successfully built custom-lib for ${arch} (${libc_type})"
        log_info "Output: $output_file"
        return 0
    else
        log_error "Build completed but output file not found"
        return 1
    fi
}

main() {
    local arch="${1:-}"
    local libc_type="${2:-glibc}"
    
    if [ -z "$arch" ]; then
        log_error "Architecture not specified"
        return 1
    fi
    
    build_custom_lib "$arch" "$libc_type"
}