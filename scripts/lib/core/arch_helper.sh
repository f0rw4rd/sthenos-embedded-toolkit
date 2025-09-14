#!/bin/bash
# Architecture helper functions

# Source the architecture definitions
ARCH_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ARCH_HELPER_DIR/architectures.sh"

# Get a specific field from architecture configuration
get_arch_field() {
    local arch="$1"
    local field="$2"
    
    if [ -z "${ARCH_CONFIG[$arch]}" ]; then
        echo ""
        return 1
    fi
    
    echo "${ARCH_CONFIG[$arch]}" | grep "^$field=" | cut -d= -f2-
}

# Get musl toolchain name
get_musl_toolchain() {
    get_arch_field "$1" "musl_name"
}

# Get musl cross-compilation prefix
get_musl_cross() {
    get_arch_field "$1" "musl_cross"
}

# Get glibc toolchain name
get_glibc_toolchain() {
    get_arch_field "$1" "glibc_name"
}

# Get Bootlin architecture name
get_bootlin_arch() {
    get_arch_field "$1" "bootlin_arch"
}

# Get Bootlin download URL
get_bootlin_url() {
    get_arch_field "$1" "bootlin_url"
}

# Get architecture-specific CFLAGS
get_arch_cflags() {
    get_arch_field "$1" "cflags"
}

# Get configure architecture name
get_config_arch() {
    get_arch_field "$1" "config_arch"
}

# Get custom musl URL (for special architectures like LoongArch)
get_custom_musl_url() {
    get_arch_field "$1" "custom_musl_url"
}

# Get custom glibc URL (for special architectures like LoongArch)
get_custom_glibc_url() {
    get_arch_field "$1" "custom_glibc_url"
}

# Check if architecture is valid
is_valid_arch() {
    local arch="$1"
    for valid_arch in "${ALL_ARCHITECTURES[@]}"; do
        if [ "$arch" = "$valid_arch" ]; then
            return 0
        fi
    done
    return 1
}

# Get all architectures as space-separated string
get_all_architectures() {
    echo "${ALL_ARCHITECTURES[@]}"
}

# Check if architecture supports musl
arch_supports_musl() {
    local arch="$1"
    local musl_name=$(get_musl_toolchain "$arch")
    [ -n "$musl_name" ]
}

# Check if architecture supports glibc
arch_supports_glibc() {
    local arch="$1"
    local bootlin_url=$(get_bootlin_url "$arch")
    local custom_url=$(get_custom_glibc_url "$arch")
    [ -n "$bootlin_url" ] || [ -n "$custom_url" ]
}

# Check if architecture is glibc-only (has glibc but no musl support)
is_glibc_only_arch() {
    local arch="$1"
    local glibc_name=$(get_glibc_toolchain "$arch")
    local musl_name=$(get_musl_toolchain "$arch")
    
    # Has glibc support but no musl support
    [ -n "$glibc_name" ] && [ -z "$musl_name" ]
}

# Get all architectures that support glibc
get_glibc_supported_archs() {
    local glibc_archs=()
    for arch in "${ALL_ARCHITECTURES[@]}"; do
        if arch_supports_glibc "$arch"; then
            glibc_archs+=("$arch")
        fi
    done
    echo "${glibc_archs[@]}"
}

# Check if architecture is soft-float variant
is_soft_float_arch() {
    local arch="$1"
    case "$arch" in
        *sf|*besf|*lesf)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Map old architecture names to canonical names (for backwards compatibility)
map_arch_name() {
    local arch="$1"
    case "$arch" in
        # Map old glibc names to canonical names
        armv5)       echo "arm32v5le" ;;
        armv6)       echo "armv6" ;;
        ppc32)       echo "ppc32be" ;;
        mips32)      echo "mips32be" ;;
        mips32el)    echo "mips32le" ;;
        openrisc)    echo "or1k" ;;
        aarch64be)   echo "aarch64_be" ;;
        # PowerPC legacy names
        powerpcle)   echo "ppc32le" ;;
        powerpclesf) echo "ppc32lesf" ;;
        powerpc64)   echo "ppc64be" ;;
        powerpc)     echo "ppc32be" ;;
        # Soft-float mappings
        mips32-sf)   echo "mips32besf" ;;
        mips32el-sf) echo "mips32lesf" ;;
        powerpc-sf)  echo "ppc32besf" ;;
        powerpcle-sf) echo "ppc32lesf" ;;
        ppc32-sf)    echo "ppc32besf" ;;
        ppc32le-sf)  echo "ppc32lesf" ;;
        # Default: return as-is
        *)           echo "$arch" ;;
    esac
}

# Get toolchain directory path for musl
get_musl_toolchain_dir() {
    local arch="$1"
    local musl_cross=$(get_musl_cross "$arch")
    echo "/build/toolchains/${musl_cross}"
}

# Get toolchain directory path for glibc
get_glibc_toolchain_dir() {
    local arch="$1"
    local glibc_name=$(get_glibc_toolchain "$arch")
    echo "$GLIBC_TOOLCHAINS_DIR/${glibc_name}"
}

# Export all functions for use in other scripts
export -f get_arch_field
export -f get_musl_toolchain
export -f get_musl_cross
export -f get_glibc_toolchain
export -f get_bootlin_arch
export -f get_bootlin_url
export -f get_arch_cflags
export -f get_config_arch
export -f get_custom_musl_url
export -f get_custom_glibc_url
export -f is_valid_arch
export -f get_all_architectures
export -f arch_supports_musl
export -f arch_supports_glibc
export -f is_glibc_only_arch
export -f get_glibc_supported_archs
export -f is_soft_float_arch
export -f map_arch_name
export -f get_musl_toolchain_dir
export -f get_glibc_toolchain_dir