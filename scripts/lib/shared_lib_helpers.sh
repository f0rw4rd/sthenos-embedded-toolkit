#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/build_helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/core/arch_helper.sh"

setup_shared_toolchain() {
    local arch="$1"
    local libc_type="${LIBC_TYPE:-musl}"
    
    if [ "$libc_type" = "glibc" ]; then
        local toolchain_name=$(get_glibc_toolchain "$arch")
        if [ -z "$toolchain_name" ]; then
            log_error "No glibc toolchain for $arch"
            return 1
        fi
        
        local toolchain_dir="${GLIBC_TOOLCHAINS_DIR:-/build/toolchains-glibc}/$toolchain_name"
        if [ ! -d "$toolchain_dir" ]; then
            log_error "Toolchain not found at $toolchain_dir"
            return 1
        fi
        
        export PATH="$toolchain_dir/bin:$PATH"
        export CC="${toolchain_name}-gcc"
        export CXX="${toolchain_name}-g++"
        export AR="${toolchain_name}-ar"
        export RANLIB="${toolchain_name}-ranlib"
        export STRIP="${toolchain_name}-strip"
        export NM="${toolchain_name}-nm"
        export LD="${toolchain_name}-ld"
        export OBJCOPY="${toolchain_name}-objcopy"
        export OBJDUMP="${toolchain_name}-objdump"
        export HOST="${toolchain_name}"
        export CROSS_COMPILE="${toolchain_name}-"
    else
        if ! setup_arch "$arch"; then
            log_error "Failed to setup musl toolchain for $arch"
            return 1
        fi
    fi
    
    return 0
}

check_toolchain_availability() {
    local arch="$1"
    local libc_type="${LIBC_TYPE:-musl}"
    
    if [ "$libc_type" = "musl" ]; then
        local musl_name=$(get_musl_toolchain "$arch")
        if [ -z "$musl_name" ]; then
            log_debug "Skipping $arch - no musl toolchain available"
            return 1
        fi
    else
        local glibc_name=$(get_glibc_toolchain "$arch")
        if [ -z "$glibc_name" ]; then
            log_debug "Skipping $arch - no glibc toolchain available"
            return 1
        fi
    fi
    
    return 0
}

check_shared_library_exists() {
    local arch="$1"
    local lib_name="$2"
    local libc_type="${LIBC_TYPE:-musl}"
    
    local output_dir="${STATIC_OUTPUT_DIR:-/build/output}/$arch/shared/$libc_type"
    local output_file="$output_dir/${lib_name}.so"
    
    if [ -f "$output_file" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
        log "${lib_name}.so already built for $arch ($size)"
        return 0
    fi
    
    return 1
}

build_shared_library() {
    local arch="$1"
    local lib_name="$2"
    local source_file="$3"
    local cflags="$4"
    local ldflags="$5"
    local extra_defines="${6:-}"
    
    local libc_type="${LIBC_TYPE:-musl}"
    local output_dir="${STATIC_OUTPUT_DIR:-/build/output}/$arch/shared/$libc_type"
    local output_file="$output_dir/${lib_name}.so"
    
    mkdir -p "$output_dir"
    
    local build_dir="/tmp/build-${lib_name}-${arch}-${libc_type}-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    if [ -n "$extra_defines" ]; then
        cflags="$cflags $extra_defines"
    fi
    
    log_debug "Building $lib_name for $arch"
    log_debug "CC=$CC"
    log_debug "CFLAGS=$cflags"
    log_debug "LDFLAGS=$ldflags"
    
    if ! $CC $cflags -c "$source_file" -o "${lib_name}.o" 2>&1; then
        log_error "Compilation failed for $lib_name/$arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    if ! $CC $ldflags -o "${lib_name}.so" "${lib_name}.o" 2>&1; then
        log_error "Linking failed for $lib_name/$arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    $STRIP "${lib_name}.so" 2>/dev/null || true
    
    cp "${lib_name}.so" "$output_file"
    
    cleanup_build_dir "$build_dir"
    
    local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
    log "Successfully built: $output_file ($size)"
    
    return 0
}

export -f setup_shared_toolchain
export -f check_toolchain_availability
export -f check_shared_library_exists
export -f build_shared_library