#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/tools.sh"

TOOL_NAME="tinyproxy"
SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd,macos"
TINYPROXY_VERSION="${TINYPROXY_VERSION:-1.11.3}"
TINYPROXY_URL="https://github.com/tinyproxy/tinyproxy/releases/download/${TINYPROXY_VERSION}/tinyproxy-${TINYPROXY_VERSION}.tar.gz"
TINYPROXY_SHA512="e721dbcf1aa6171c30f8acc81ac4ee7705ff64cfa2e48051599ce985205236c6ef4c221376f850ec66c363b15200a892b622d40b3b423bb901d02c8839759600"

configure_tinyproxy() {
    local arch=$1

    standard_configure "$arch" "$TOOL_NAME" \
        --disable-manpage_support \
        --enable-filter \
        --enable-upstream \
        --enable-reverse \
        --enable-transparent
}

build_tinyproxy_impl() {
    local arch=$1

    parallel_make
}

install_tinyproxy() {
    local arch=$1

    install_binary "src/tinyproxy" "$arch" "tinyproxy" "$TOOL_NAME"
}

build_tinyproxy() {
    local arch=$1

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "$TOOL_NAME"; then
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

    if ! download_and_extract "$TINYPROXY_URL" "$build_dir" 0 "$TINYPROXY_SHA512"; then
        log_tool_error "$TOOL_NAME" "Failed to download and extract source"
        return 1
    fi

    cd "$build_dir/${TOOL_NAME}-${TINYPROXY_VERSION}"

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    if [ "${USE_ZIG:-0}" != "1" ]; then
        export_cross_compiler "$CROSS_COMPILE"
    fi

    configure_tinyproxy "$arch" || {
        log_tool_error "$TOOL_NAME" "Configure failed for $arch"
        return 1
    }

    build_tinyproxy_impl "$arch" || {
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    }

    install_tinyproxy "$arch" || {
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

    build_tinyproxy "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
