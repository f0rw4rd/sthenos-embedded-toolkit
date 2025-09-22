#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

validate_sha512() {
    local description="$1"
    local expected_sha512="$2"
    local url="${3:-}"    
    
    if [ -z "$expected_sha512" ]; then        
        log_error "SHA512 checksum is required but missing for $description"
        [ -n "$url" ] && log_error "URL: $url"        
        return 1        
    fi
    
    if [ ${#expected_sha512} -ne 128 ]; then
        log_error "Invalid SHA512 length for $description"
        log_error "Expected 128 characters, got ${#expected_sha512}"
        log_error "SHA512: $expected_sha512"
        return 1
    fi
    
    if ! echo "$expected_sha512" | grep -qE '^[a-fA-F0-9]{128}$'; then
        log_error "Invalid SHA512 format for $description"
        log_error "SHA512 must contain only hexadecimal characters (0-9, a-f, A-F)"
        log_error "SHA512: $expected_sha512"
        return 1
    fi
    
    return 0
}

verify_sha512() {
    local file_path="$1"
    local expected_sha512="$2"
    local description="$3"
    
    if [ -z "$expected_sha512" ]; then
        log "Skipping SHA512 verification for $description (no checksum provided)"
        return 0
    fi
    
    expected_sha512=$(echo "$expected_sha512" | tr '[:upper:]' '[:lower:]')
    
    log "Verifying SHA512 checksum for $description..."
    local actual_sha512=$(sha512sum "$file_path" | cut -d' ' -f1)
    
    if [ "$actual_sha512" != "$expected_sha512" ]; then
        log_error "SHA512 checksum verification failed for $description"
        log_error "Expected: $expected_sha512"
        log_error "Actual:   $actual_sha512"
        log_error "File may be corrupted or tampered with!"
        return 1
    else
        log "SHA512 checksum verified successfully for $description"
        return 0
    fi
}

check_cached_file() {
    local file_path="$1"
    local expected_sha512="$2"
    local description="$3"
    
    if [ ! -f "$file_path" ]; then
        return 1  # File doesn't exist
    fi
    
    if [ -z "$expected_sha512" ]; then
        log "SHA512 was not set! for $filepath"
        return 1
    fi    
    
    expected_sha512=$(echo "$expected_sha512" | tr '[:upper:]' '[:lower:]')
    
    local actual_sha512=$(sha512sum "$file_path" | cut -d' ' -f1)
    if [ "$actual_sha512" = "$expected_sha512" ]; then
        log "Using cached $description (checksum verified)"
        return 0
    else
        log_error "SECURITY WARNING: Checksum mismatch for cached $description"
        log_error "Expected: $expected_sha512"
        log_error "Actual:   $actual_sha512"
        log_error "File may be corrupted or tampered with. Deleting and re-downloading..."
        rm -f "$file_path"
        return 1
    fi
}

debug_compiler_info() {
    if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
        log "[DEBUG] Build Configuration:"
        log "  Architecture: ${1:-$arch}"
        log "  Tool: ${2:-$TOOL_NAME}"
        log "  CROSS_COMPILE: ${CROSS_COMPILE:-not set}"
        log "  CC: ${CC:-not set}"
        log "  CFLAGS: ${CFLAGS:-not set}"
        log "  LDFLAGS: ${LDFLAGS:-not set}"
        log "  HOST: ${HOST:-not set}"
        log "  CONFIG_ARCH: ${CONFIG_ARCH:-not set}"
        if [ -n "${CROSS_COMPILE}" ]; then
            which "${CROSS_COMPILE}gcc" 2>/dev/null && log "  Compiler Path: $(which ${CROSS_COMPILE}gcc)"
        fi
    fi
}

check_binary_exists() {
    local arch=$1
    local tool_name=$2
    local binary_path="/build/output/$arch/$tool_name"
    
    if [ -f "$binary_path" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(ls -lh "$binary_path" | awk '{print $5}')
        log "[$arch] Already built: $binary_path ($size)"
        return 0
    fi
    return 1
}

download_source() {
    local tool_name=$1
    local version=$2
    local url=$3
    local expected_sha512=$4
    local extract_name=${5:-"${tool_name}-${version}"}
    
    local source_dir="/build/sources"
    mkdir -p "$source_dir"
    
    local filename=$(basename "$url")
    local source_file="$source_dir/$filename"
    local description="$tool_name-$version"
    
    if ! validate_sha512 "$description" "$expected_sha512" "$url"; then
        return 1
    fi
    
    if check_cached_file "$source_file" "$expected_sha512" "$tool_name source"; then
        return 0
    fi
    
    if [ ! -f "$source_file" ]; then
        log "Downloading $tool_name source..."
        
        local retry_count=0
        local max_retries=3
        local download_success=false
        
        while [ $retry_count -lt $max_retries ]; do
            if wget -q --tries=2 "$url" -O "$source_file"; then
                download_success=true
                break
            else
                retry_count=$((retry_count + 1))
                log "Download attempt $retry_count failed, retrying..."
                rm -f "$source_file"
                sleep 2
            fi
        done
        
        if [ "$download_success" = false ]; then
            log_error "Failed to download $tool_name source after $max_retries attempts"
            rm -f "$source_file"
            return 1
        fi
        
        if ! verify_sha512 "$source_file" "$expected_sha512" "$description"; then
            rm -f "$source_file"
            return 1
        fi
    fi
    
    return 0
}

download_with_progress() {
    local description=$1
    local url=$2
    local output_file=$3
    local expected_sha512=$4
    local max_retries=${5:-3}    
    
    if ! validate_sha512 "$description" "$expected_sha512" "$url"; then
        return 1
    fi
    
    if check_cached_file "$output_file" "$expected_sha512" "$description"; then
        return 0
    fi
    
    local retry_count=0
    local download_success=false
    
    while [ $retry_count -lt $max_retries ]; do
        if wget --progress=bar:force:noscroll --tries=2 "$url" -O "$output_file"; then
            download_success=true
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log "  Retry $retry_count/$max_retries for $description..."
                sleep $((retry_count * 2))
            fi
            rm -f "$output_file"
        fi
    done
    
    if [ "$download_success" = false ]; then
        log_error "Failed to download $description after $max_retries attempts"
        rm -f "$output_file"
        return 1
    fi
    
    if ! verify_sha512 "$output_file" "$expected_sha512" "$description"; then
        rm -f "$output_file"
        return 1
    fi
    
    return 0
}


standard_configure() {
    local arch=$1
    local tool_name=$2
    shift 2
    local extra_args=("$@")
    
    local common_args=(
        "--host=$HOST"
        "--enable-static"
        "--disable-shared"
        "--disable-nls"
        "--disable-dependency-tracking"
        "--without-x"
        "--disable-werror"
    )
    
    log_tool "$tool_name" "Configuring for $arch"
    
    CFLAGS="${CFLAGS:-}" LDFLAGS="${LDFLAGS:-}" \
    ./configure "${common_args[@]}" "${extra_args[@]}"
}

create_build_dir() {
    local tool_name=$1
    local arch=$2
    local build_dir="/tmp/${tool_name}-build-${arch}-$$"
    
    mkdir -p "$build_dir"
    echo "$build_dir"
}

cleanup_build_dir() {
    local build_dir=$1
    local preserve_on_error=${2:-false}
    
    if [ -d "$build_dir" ]; then
        if [ "$preserve_on_error" = "true" ] && [ $? -ne 0 ]; then
            log_warn "Build failed, preserving build directory: $build_dir"
        else
            cd /
            rm -rf "$build_dir"
        fi
    fi
}

install_binary() {
    local source_file=$1
    local arch=$2
    local dest_name=$3
    local tool_name=$4
    
    if [ ! -f "$source_file" ]; then
        log_tool_error "$tool_name" "Binary not found: $source_file"
        return 1
    fi
    
    $STRIP "$source_file" || {
        log_tool_error "$tool_name" "Failed to strip binary for $arch"
        return 1
    }
    
    mkdir -p "/build/output/$arch"
    
    cp "$source_file" "/build/output/$arch/$dest_name" || {
        log_tool_error "$tool_name" "Failed to copy binary for $arch"
        return 1
    }
    
    local size=$(get_binary_size "/build/output/$arch/$dest_name")
    log_tool "$tool_name" "Built successfully for $arch ($size)"
    
    return 0
}

verify_static_binary() {
    local binary_path=$1
    local tool_name=$2
    
    if command -v ldd >/dev/null 2>&1; then
        if ldd "$binary_path" 2>&1 | grep -q "not a dynamic executable"; then
            log_tool "$tool_name" "Binary is statically linked"
            return 0
        elif ldd "$binary_path" 2>&1 | grep -q "statically linked"; then
            log_tool "$tool_name" "Binary is statically linked"
            return 0
        else
            log_tool_error "$tool_name" "Binary appears to be dynamically linked!"
            ldd "$binary_path" 2>&1 | head -5
            return 1
        fi
    fi
    return 0
}


create_cross_cache() {
    local arch=$1
    local cache_file=$2
    
    cat > "$cache_file" << EOF
ac_cv_func_malloc_0_nonnull=yes
ac_cv_func_realloc_0_nonnull=yes
ac_cv_func_mmap_fixed_mapped=yes
ac_cv_func_getaddrinfo=yes
ac_cv_working_alloca_h=yes
ac_cv_func_alloca_works=yes
ac_cv_c_bigendian=$([ "${arch#*be}" != "$arch" ] && echo "yes" || echo "no")
ac_cv_c_littleendian=$([ "${arch#*be}" = "$arch" ] && echo "yes" || echo "no")
ac_cv_func_setpgrp_void=yes
ac_cv_func_setgrent_void=yes
ac_cv_func_getpgrp_void=yes
ac_cv_func_getgrent_void=yes
ac_cv_sizeof_int=4
ac_cv_sizeof_long=$([ "${arch#*64}" != "$arch" ] && echo "8" || echo "4")
ac_cv_sizeof_long_long=8
ac_cv_sizeof_void_p=$([ "${arch#*64}" != "$arch" ] && echo "8" || echo "4")
ac_cv_sizeof_size_t=$([ "${arch#*64}" != "$arch" ] && echo "8" || echo "4")
ac_cv_sizeof_pid_t=4
ac_cv_sizeof_uid_t=4
ac_cv_sizeof_gid_t=4
EOF
}

get_binary_size() {
    local file_path=$1
    ls -lh "$file_path" 2>/dev/null | awk '{print $5}'
}

validate_args() {
    local min_args=$1
    local usage=$2
    shift 2
    
    if [ $# -lt $min_args ]; then
        echo "$usage"
        exit 1
    fi
}

export_cross_compiler() {
    local cross_prefix=$1
    export CC="${cross_prefix}gcc"
    export CXX="${cross_prefix}g++"
    export AR="${cross_prefix}ar"
    export RANLIB="${cross_prefix}ranlib"
    export STRIP="${cross_prefix}strip"
    export NM="${cross_prefix}nm"
    export LD="${cross_prefix}ld"
}

export -f validate_sha512
export -f verify_sha512
export -f check_cached_file
export -f debug_compiler_info
export -f check_binary_exists
export -f download_source
export -f download_with_progress
export -f standard_configure
export -f create_build_dir
export -f cleanup_build_dir
export -f install_binary
export -f verify_static_binary
export -f create_cross_cache
export -f get_binary_size
export -f validate_args
export -f export_cross_compiler

