#!/bin/bash

ARCH_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ARCH_HELPER_DIR/architectures.sh"


get_musl_cross() {
    get_arch_field "$1" "musl_cross"
}

get_bootlin_arch() {
    get_arch_field "$1" "bootlin_arch"
}

get_arch_cflags() {
    get_arch_field "$1" "cflags"
}

get_config_arch() {
    get_arch_field "$1" "config_arch"
}

is_valid_arch() {
    local arch="$1"
    for valid_arch in "${ALL_ARCHITECTURES[@]}"; do
        if [ "$arch" = "$valid_arch" ]; then
            return 0
        fi
    done
    return 1
}

get_all_architectures() {
    echo "${ALL_ARCHITECTURES[@]}"
}


is_glibc_only_arch() {
    local arch="$1"
    local glibc_name=$(get_glibc_toolchain "$arch")
    local musl_name=$(get_musl_toolchain "$arch")
    
    [ -n "$glibc_name" ] && [ -z "$musl_name" ]
}

get_glibc_supported_archs() {
    local glibc_archs=()
    for arch in "${ALL_ARCHITECTURES[@]}"; do
        if arch_supports_glibc "$arch"; then
            glibc_archs+=("$arch")
        fi
    done
    echo "${glibc_archs[@]}"
}

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

source "$ARCH_HELPER_DIR/../arch_map.sh"

get_musl_toolchain_dir() {
    local arch="$1"
    local musl_cross=$(get_musl_cross "$arch")
    echo "/build/toolchains-musl/${musl_cross}-cross"
}

get_glibc_toolchain_dir() {
    local arch="$1"
    local glibc_name=$(get_glibc_toolchain "$arch")
    echo "/build/toolchains-glibc/${glibc_name}"
}

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
