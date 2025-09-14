#!/bin/bash
# On-demand toolchain management for Sthenos Embedded Toolkit
# Downloads toolchains only when needed and caches them in Docker volumes

# Source required libraries
source /build/scripts/lib/config.sh
source /build/scripts/lib/logging.sh
source /build/scripts/lib/core/architectures.sh
source /build/scripts/lib/core/arch_helper.sh

MUSL_TOOLCHAIN_DIR="$MUSL_TOOLCHAINS_DIR"
GLIBC_TOOLCHAIN_DIR="$GLIBC_TOOLCHAINS_DIR"
BASE_URL_BOOTLIN="$BOOTLIN_BASE_URL"

# Ensure toolchain directories exist
ensure_build_dirs

# Check if musl toolchain exists and is valid
musl_toolchain_exists() {
    local arch="$1"
    local musl_name=$(get_musl_toolchain "$arch" 2>/dev/null)
    
    if [ -z "$musl_name" ]; then
        return 1
    fi
    
    local toolchain_dir="$MUSL_TOOLCHAIN_DIR/${musl_name}-cross"
    
    # Check if directory exists and has a working compiler
    if [ -d "$toolchain_dir/bin" ] && [ -n "$(ls "$toolchain_dir/bin/"*-gcc 2>/dev/null)" ]; then
        return 0
    fi
    
    return 1
}

# Check if glibc toolchain exists and is valid
glibc_toolchain_exists() {
    local arch="$1"
    local glibc_name=$(get_glibc_toolchain "$arch" 2>/dev/null)
    
    if [ -z "$glibc_name" ]; then
        return 1
    fi
    
    local toolchain_dir="$GLIBC_TOOLCHAIN_DIR/$glibc_name"
    
    # Check if directory exists and has a working compiler
    if [ -d "$toolchain_dir/bin" ] && [ -n "$(ls "$toolchain_dir/bin/"*-gcc 2>/dev/null)" ]; then
        return 0
    fi
    
    return 1
}

# Download single musl toolchain
download_musl_toolchain_single() {
    local arch="$1"
    local musl_name=$(get_musl_toolchain "$arch" 2>/dev/null)
    
    if [ -z "$musl_name" ]; then
        log_error "No musl toolchain defined for architecture: $arch"
        return 1
    fi
    
    # Check for custom URL (e.g., LoongArch)
    local custom_url=$(get_custom_musl_url "$arch" 2>/dev/null)
    local url
    local filename
    
    if [ -n "$custom_url" ]; then
        url="$custom_url"
        filename=$(basename "$custom_url")
    else
        url="https://musl.cc/${musl_name}-cross.tgz"
        filename="${musl_name}-cross.tgz"
    fi
    
    local target_dir="$MUSL_TOOLCHAIN_DIR/${musl_name}-cross"
    
    log "Downloading musl toolchain for $arch..."
    log "  URL: $url"
    log "  Target: $target_dir"
    
    # Create temp directory for download
    local temp_dir="/tmp/musl-download-${arch}-$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Cleanup function
    cleanup_musl() {
        cd /
        rm -rf "$temp_dir"
    }
    trap cleanup_musl EXIT
    
    source "$(dirname "${BASH_SOURCE[0]}")/build_helpers.sh"
    if ! download_source "musl-toolchain" "$arch" "$url"; then
        cleanup_musl
        return 1
    fi
    
    log "  Extracting $filename..."
    local source_file="/build/sources/$filename"
    
    case "$filename" in
        *.tar.xz)
            if ! tar xf "$source_file" -C .; then
                log_error "Failed to extract musl toolchain for $arch"
                return 1
            fi
            ;;
        *.tgz|*.tar.gz)
            if ! tar xzf "$source_file" -C .; then
                log_error "Failed to extract musl toolchain for $arch"
                return 1
            fi
            ;;
        *)
            log_error "Unknown archive format for $filename"
            return 1
            ;;
    esac
    
    # Move to final location
    mkdir -p "$(dirname "$target_dir")"
    
    # Handle different directory structures
    if [ -n "$custom_url" ]; then
        # For custom toolchains, find the extracted directory
        local extracted_dir=$(find . -maxdepth 1 -type d -name "*" | grep -v "^\.$" | head -1)
        
        if [ -n "$extracted_dir" ] && [ -d "$extracted_dir" ]; then
            # Check if this directory has a bin/ subdirectory with gcc
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
        # Standard musl.cc toolchains
        mv "${musl_name}-cross" "$target_dir"
    fi
    
    # Verify
    if [ ! -d "$target_dir/bin" ] || [ -z "$(ls "$target_dir/bin/"*-gcc 2>/dev/null)" ]; then
        log_error "Invalid musl toolchain structure for $arch"
        rm -rf "$target_dir"
        return 1
    fi
    
    log "✓ Successfully downloaded musl toolchain for $arch"
    
    # Special case: if we just downloaded arm32v7le, also copy to arm32v7lehf
    if [ "$musl_name" = "armv7l-linux-musleabihf" ] && [ "$arch" = "arm32v7le" ]; then
        local arm32v7lehf_dir="$MUSL_TOOLCHAIN_DIR/armv7l-linux-musleabihf-cross-hf"
        if [ ! -d "$arm32v7lehf_dir" ]; then
            cp -a "$target_dir" "$arm32v7lehf_dir"
            log "✓ Also created arm32v7lehf toolchain (copied from arm32v7le)"
        fi
    fi
    
    return 0
}

# Download single glibc toolchain
download_glibc_toolchain_single() {
    local arch="$1"
    
    # Check for custom URL first (e.g., LoongArch)
    local custom_url=$(get_custom_glibc_url "$arch" 2>/dev/null)
    local url
    local filename
    
    if [ -n "$custom_url" ]; then
        url="$custom_url"
        filename=$(basename "$custom_url")
        log "Using custom glibc URL for $arch"
    else
        # Get bootlin URL directly from architecture config
        local bootlin_url=$(get_bootlin_url "$arch" 2>/dev/null)
        if [ -z "$bootlin_url" ]; then
            log_error "No bootlin URL defined for architecture: $arch"
            return 1
        fi
        url="$BASE_URL_BOOTLIN/$bootlin_url"
        filename=$(basename "$bootlin_url")
    fi
    
    # Get glibc name for target directory
    local glibc_name=$(get_glibc_toolchain "$arch" 2>/dev/null)
    if [ -z "$glibc_name" ]; then
        log_error "No glibc toolchain name for $arch"
        return 1
    fi
    
    local target_dir="$GLIBC_TOOLCHAIN_DIR/$glibc_name"
    
    log "Downloading glibc toolchain for $arch..."
    log "  URL: $url"
    log "  Target: $target_dir"
    
    # Create temp directory
    local temp_dir="/tmp/glibc-download-${arch}-$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Cleanup function
    cleanup_glibc() {
        cd /
        rm -rf "$temp_dir"
    }
    trap cleanup_glibc EXIT
    if ! download_source "glibc-toolchain" "$arch" "$url"; then
        cleanup_glibc
        return 1
    fi
    
    log "  Extracting $filename..."
    local source_file="/build/sources/$filename"
    if ! tar xf "$source_file" -C .; then
        log_error "Failed to extract glibc toolchain for $arch"
        return 1
    fi
    
    # Find extracted directory
    local extracted_dir=$(find . -maxdepth 1 -type d -name "*" | grep -v "^\.$" | head -1)
    if [ -z "$extracted_dir" ]; then
        log_error "No directory found after extraction for $arch"
        return 1
    fi
    
    # Move to final location
    mkdir -p "$(dirname "$target_dir")"
    mv "$extracted_dir" "$target_dir"
    
    # Verify
    if [ ! -d "$target_dir/bin" ] || [ -z "$(ls "$target_dir/bin/"*-gcc 2>/dev/null)" ]; then
        log_error "Invalid glibc toolchain structure for $arch"
        rm -rf "$target_dir"
        return 1
    fi
    
    log "✓ Successfully downloaded glibc toolchain for $arch"
    return 0
}

ensure_toolchain() {
    local arch="$1"
    
    log "Checking toolchain availability for architecture: $arch"
    
    # Check if architecture supports musl
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
    
    # Check if architecture supports glibc
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
    
    # Verify at least one toolchain is available
    if ! arch_supports_musl "$arch" && ! arch_supports_glibc "$arch"; then
        log_error "Architecture $arch is not supported (no musl or glibc toolchain available)"
        return 1
    fi
    
    return 0
}

# Batch ensure toolchains for multiple architectures
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