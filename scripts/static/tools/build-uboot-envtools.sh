#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/tools.sh"

TOOL_NAME="uboot-envtools"
SUPPORTED_OS="linux,android"
UBOOT_ENVTOOLS_VERSION="${UBOOT_ENVTOOLS_VERSION:-2026.04}"
UBOOT_ENVTOOLS_URL="https://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_ENVTOOLS_VERSION}.tar.bz2"
UBOOT_ENVTOOLS_SHA512="c5fca2abc533759985dfcc6d071d154007535787b0bbd569b61bda1fe2f3a31fba08481c8caf18cf5f2bc79609f50dee504977a8b65e8c4cc21f277268232e03"

build_uboot_envtools_impl() {
    local arch=$1

    # U-Boot's envtools target requires:
    # 1. A defconfig to generate .config and header files (uses host compiler)
    # 2. make envtools with CROSS_COMPILE to build the actual fw_printenv binary
    #
    # The tools/env/Makefile does "override HOSTCC = $(CC)" so CC is used for
    # the actual envtools compilation, while scripts_basic uses the host compiler.

    # Generate .config and headers using sandbox_defconfig (minimal, no real board needed)
    # HOSTCC must point to the actual host compiler for fixdep and other build scripts
    make sandbox_defconfig HOSTCC=gcc HOSTLD=ld 2>&1 | tail -5 || return 1

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    # Build only the envtools target.
    # The env tools Makefile does "override HOSTCC = $(CC)" so HOSTCC becomes
    # the cross compiler. However the Kbuild host program build uses
    # KBUILD_HOSTCFLAGS and KBUILD_HOSTLDFLAGS for compilation and linking,
    # so we inject our static flags there.
    # The top-level scripts_basic target still needs the real host gcc, which
    # we provide via the initial sandbox_defconfig step above.
    make envtools \
        CC="$CC" \
        CROSS_COMPILE="${CROSS_COMPILE}" \
        KBUILD_HOSTCFLAGS="$cflags" \
        KBUILD_HOSTLDFLAGS="$ldflags" \
        -j$(nproc) || return 1
}

install_uboot_envtools() {
    local arch=$1

    install_binary "tools/env/fw_printenv" "$arch" "fw_printenv" "$TOOL_NAME" || return 1

    # fw_setenv is conventionally a symlink to fw_printenv — the binary checks
    # argv[0] to decide whether to print or set environment variables.
    local output_dir="/build/output/$arch"
    local suffix=$(get_libc_suffix)
    ln -sf "fw_printenv.${suffix}" "${output_dir}/fw_setenv.${suffix}"
    log_tool "$TOOL_NAME" "Created fw_setenv symlink for $arch"
}

build_uboot_envtools() {
    local arch=$1

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "fw_printenv"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Unknown architecture: $arch"
        return 1
    }

    download_toolchain "$arch" || return 1

    local build_dir
    build_dir=$(create_build_dir "$TOOL_NAME" "$arch")

    trap "cleanup_build_dir '$build_dir'" EXIT

    if ! download_and_extract "$UBOOT_ENVTOOLS_URL" "$build_dir" 0 "$UBOOT_ENVTOOLS_SHA512"; then
        log_tool_error "$TOOL_NAME" "Failed to download and extract source"
        return 1
    fi

    cd "$build_dir/u-boot-${UBOOT_ENVTOOLS_VERSION}"

    if [ "${USE_ZIG:-0}" != "1" ]; then
        export_cross_compiler "$CROSS_COMPILE"
    fi

    build_uboot_envtools_impl "$arch" || {
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    }

    install_uboot_envtools "$arch" || {
        log_tool_error "$TOOL_NAME" "Installation failed for $arch"
        return 1
    }

    trap - EXIT
    cleanup_build_dir "$build_dir"

    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>" "$@"

    local arch=$1
    mkdir -p "/build/output/$arch"

    build_uboot_envtools "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
