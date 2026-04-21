#!/bin/bash

source /build/scripts/lib/config.sh
source /build/scripts/lib/logging.sh
source /build/scripts/lib/core/architectures.sh
source /build/scripts/lib/core/arch_helper.sh
source /build/scripts/lib/build_helpers.sh

MUSL_TOOLCHAIN_DIR="$MUSL_TOOLCHAINS_DIR"
GLIBC_TOOLCHAIN_DIR="$GLIBC_TOOLCHAINS_DIR"
UCLIBC_TOOLCHAIN_DIR="$UCLIBC_TOOLCHAINS_DIR"
BASE_URL_BOOTLIN="$BOOTLIN_BASE_URL"

ensure_build_dirs

musl_toolchain_exists() {
    local arch="$1"
    local musl_name=$(get_musl_toolchain "$arch" 2>/dev/null)
    
    if [ -z "$musl_name" ]; then
        return 1
    fi
    
    local toolchain_dir="$MUSL_TOOLCHAIN_DIR/${musl_name}-cross"
    
    if [ -d "$toolchain_dir/bin" ] && [ -n "$(ls "$toolchain_dir/bin/"*-gcc 2>/dev/null)" ]; then
        return 0
    fi
    
    return 1
}

glibc_toolchain_exists() {
    local arch="$1"
    local glibc_name=$(get_glibc_toolchain "$arch" 2>/dev/null)
    
    if [ -z "$glibc_name" ]; then
        return 1
    fi
    
    local toolchain_dir="$GLIBC_TOOLCHAIN_DIR/$glibc_name"
    
    if [ -d "$toolchain_dir/bin" ] && [ -n "$(ls "$toolchain_dir/bin/"*-gcc 2>/dev/null)" ]; then
        return 0
    fi
    
    return 1
}

download_musl_toolchain_single() {
    local arch="$1"
    local musl_name=$(get_musl_toolchain "$arch" 2>/dev/null)
    
    if [ -z "$musl_name" ]; then
        log_error "No musl toolchain defined for architecture: $arch"
        return 1
    fi
    
    local custom_url=$(get_custom_musl_url "$arch" 2>/dev/null)
    local url
    local filename
    
    if [ -n "$custom_url" ]; then
        url="$custom_url"
        filename=$(basename "$custom_url")
        expected_sha512=$(get_custom_musl_sha512 "$arch")
    else
        url="https://musl.cc/${musl_name}-cross.tgz"
        filename="${musl_name}-cross.tgz"
        expected_sha512=$(get_musl_sha512 "$arch")
    fi
    
    local target_dir="$MUSL_TOOLCHAIN_DIR/${musl_name}-cross"
    
    log "Downloading musl toolchain for $arch..."
    log "  URL: $url"
    log "  Target: $target_dir"
    
    local temp_dir="/tmp/musl-download-${arch}-$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    trap "cleanup_build_dir '$temp_dir'" EXIT
    
    if ! download_and_extract "$url" "$temp_dir" 0 "$expected_sha512"; then
        log_error "Failed to download and extract musl toolchain for $arch"
        cleanup_build_dir "$temp_dir"
        return 1
    fi
    
    mkdir -p "$(dirname "$target_dir")"
    
    if [ -n "$custom_url" ]; then
        local extracted_dir=$(find . -maxdepth 1 -type d -name "*" | grep -v "^\.$" | head -1)
        
        if [ -n "$extracted_dir" ] && [ -d "$extracted_dir" ]; then
            if [ -d "$extracted_dir/bin" ] && [ -n "$(ls "$extracted_dir/bin/"*gcc 2>/dev/null)" ]; then
                mv "$extracted_dir" "$target_dir"
            else
                log_error "Extracted directory $extracted_dir doesn't contain expected toolchain structure for $arch"
                return 1
            fi
        else
            log_error "Could not find extracted toolchain directory for $arch"
            return 1
        fi
    else
        mv "${musl_name}-cross" "$target_dir"
    fi
    
    if [ ! -d "$target_dir/bin" ] || [ -z "$(ls "$target_dir/bin/"*-gcc 2>/dev/null)" ]; then
        log_error "Invalid musl toolchain structure for $arch"
        rm -rf "$target_dir"
        return 1
    fi
    
    log "✓ Successfully downloaded musl toolchain for $arch"
    
    if [ "$musl_name" = "armv7l-linux-musleabihf" ] && [ "$arch" = "arm32v7le" ]; then
        local arm32v7lehf_dir="$MUSL_TOOLCHAIN_DIR/armv7l-linux-musleabihf-cross-hf"
        if [ ! -d "$arm32v7lehf_dir" ]; then
            cp -a "$target_dir" "$arm32v7lehf_dir"
            log "✓ Also created arm32v7lehf toolchain (copied from arm32v7le)"
        fi
    fi
    
    return 0
}

download_glibc_toolchain_single() {
    local arch="$1"
    
    local custom_url=$(get_custom_glibc_url "$arch" 2>/dev/null)
    local url
    local filename
    
    if [ -n "$custom_url" ]; then
        url="$custom_url"
        filename=$(basename "$custom_url")
        expected_sha512=$(get_custom_glibc_sha512 "$arch")
        log "Using custom glibc URL for $arch"        
    else
        local bootlin_url=$(get_bootlin_url "$arch" 2>/dev/null)
        if [ -z "$bootlin_url" ]; then
            log_error "No bootlin URL defined for architecture: $arch"
            return 1
        fi
        expected_sha512=$(get_bootlin_sha512 "$arch")
        url="$BASE_URL_BOOTLIN/$bootlin_url"
        filename=$(basename "$bootlin_url")
    fi
    
    local glibc_name=$(get_glibc_toolchain "$arch" 2>/dev/null)
    if [ -z "$glibc_name" ]; then
        log_error "No glibc toolchain name for $arch"
        return 1
    fi
    
    local target_dir="$GLIBC_TOOLCHAIN_DIR/$glibc_name"
    
    log "Downloading glibc toolchain for $arch..."
    log "  URL: $url"
    log "  Target: $target_dir"
    
    local temp_dir="/tmp/glibc-download-${arch}-$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    trap "cleanup_build_dir '$temp_dir'" EXIT
    
    if ! download_and_extract "$url" "$temp_dir" 0 "$expected_sha512"; then
        log_error "Failed to download and extract glibc toolchain for $arch"
        cleanup_build_dir "$temp_dir"
        return 1
    fi
    
    local extracted_dir=$(find . -maxdepth 1 -type d -name "*" | grep -v "^\.$" | head -1)
    if [ -z "$extracted_dir" ]; then
        log_error "No directory found after extraction for $arch"
        return 1
    fi
    
    mkdir -p "$(dirname "$target_dir")"
    mv "$extracted_dir" "$target_dir"
    
    if [ ! -d "$target_dir/bin" ] || [ -z "$(ls "$target_dir/bin/"*-gcc 2>/dev/null)" ]; then
        log_error "Invalid glibc toolchain structure for $arch"
        rm -rf "$target_dir"
        return 1
    fi
    
    log "✓ Successfully downloaded glibc toolchain for $arch"
    return 0
}

uclibc_toolchain_exists() {
    local arch="$1"
    local uclibc_name=$(get_uclibc_toolchain "$arch" 2>/dev/null)

    if [ -z "$uclibc_name" ]; then
        return 1
    fi

    local toolchain_dir="$UCLIBC_TOOLCHAIN_DIR/$uclibc_name"

    if [ -d "$toolchain_dir/bin" ] && [ -n "$(ls "$toolchain_dir/bin/"*-gcc 2>/dev/null)" ]; then
        return 0
    fi

    return 1
}

download_uclibc_toolchain_single() {
    local arch="$1"

    local url=$(get_custom_uclibc_url "$arch" 2>/dev/null)
    local expected_sha512=$(get_custom_uclibc_sha512 "$arch" 2>/dev/null)
    local uclibc_name=$(get_uclibc_toolchain "$arch" 2>/dev/null)
    local subdir=$(get_toolchain_extract_subdir "$arch" 2>/dev/null)

    if [ -z "$url" ] || [ -z "$uclibc_name" ]; then
        log_error "No uclibc URL/name defined for architecture: $arch"
        return 1
    fi

    local target_dir="$UCLIBC_TOOLCHAIN_DIR/$uclibc_name"

    log "Downloading uclibc toolchain for $arch..."
    log "  URL: $url"
    log "  Target: $target_dir"

    local temp_dir="/tmp/uclibc-download-${arch}-$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    trap "cleanup_build_dir '$temp_dir'" EXIT

    if ! download_and_extract "$url" "$temp_dir" 0 "$expected_sha512"; then
        log_error "Failed to download and extract uclibc toolchain for $arch"
        cleanup_build_dir "$temp_dir"
        return 1
    fi

    local source_dir
    if [ -n "$subdir" ]; then
        source_dir="$temp_dir/$subdir"
        if [ ! -d "$source_dir" ]; then
            log_error "Expected subdir '$subdir' not present in extracted $arch tarball"
            return 1
        fi
    else
        source_dir=$(find "$temp_dir" -maxdepth 1 -type d ! -path "$temp_dir" | head -1)
        if [ -z "$source_dir" ]; then
            log_error "No directory found after extraction for $arch uclibc"
            return 1
        fi
    fi

    mkdir -p "$(dirname "$target_dir")"
    mv "$source_dir" "$target_dir"

    if [ ! -d "$target_dir/bin" ] || [ -z "$(ls "$target_dir/bin/"*-gcc 2>/dev/null)" ]; then
        log_error "Invalid uclibc toolchain structure for $arch"
        rm -rf "$target_dir"
        return 1
    fi

    log "✓ Successfully downloaded uclibc toolchain for $arch"
    return 0
}

ensure_toolchain() {
    local arch="$1"

    # Skip toolchain check for Zig targets
    if [[ "$arch" == *"_"* ]] && [[ "$arch" != "x86_64" ]] && [[ "$arch" != "x86_64_x32" ]] && [[ "$arch" != "aarch64_be" ]] && [[ "$arch" != "m68k_coldfire" ]] && [[ "$arch" != "arcle_hs38" ]]; then
        log "Zig target detected ($arch), skipping traditional toolchain check"
        return 0
    fi

    log "Checking toolchain availability for architecture: $arch"

    if arch_supports_musl "$arch"; then
        if ! musl_toolchain_exists "$arch"; then
            log "Musl toolchain not found for $arch, downloading..."
            if ! download_musl_toolchain_single "$arch"; then
                log_error "Failed to download musl toolchain for $arch"
                return 1
            fi
        else
            log "✓ Musl toolchain already available for $arch"
        fi
    fi

    if arch_supports_glibc "$arch"; then
        if ! glibc_toolchain_exists "$arch"; then
            log "Glibc toolchain not found for $arch, downloading..."
            if ! download_glibc_toolchain_single "$arch"; then
                log_error "Failed to download glibc toolchain for $arch"
                return 1
            fi
        else
            log "✓ Glibc toolchain already available for $arch"
        fi
    fi

    if arch_supports_uclibc "$arch" && ! arch_supports_musl "$arch" && ! arch_supports_glibc "$arch"; then
        if ! uclibc_toolchain_exists "$arch"; then
            log "Uclibc toolchain not found for $arch, downloading..."
            if ! download_uclibc_toolchain_single "$arch"; then
                log_error "Failed to download uclibc toolchain for $arch"
                return 1
            fi
        else
            log "✓ Uclibc toolchain already available for $arch"
        fi
    fi

    if ! arch_supports_musl "$arch" && ! arch_supports_glibc "$arch" && ! arch_supports_uclibc "$arch"; then
        log_error "Architecture $arch is not supported (no musl, glibc, or uclibc toolchain available)"
        return 1
    fi

    return 0
}

ensure_toolchains() {
    local architectures=("$@")
    local failed_count=0
    
    for arch in "${architectures[@]}"; do
        if ! ensure_toolchain "$arch"; then
            failed_count=$((failed_count + 1))
        fi
    done
    
    if [ $failed_count -gt 0 ]; then
        log_error "$failed_count toolchain(s) failed to download"
        return 1
    fi
    
    log "✓ All required toolchains are available"
    return 0
}
