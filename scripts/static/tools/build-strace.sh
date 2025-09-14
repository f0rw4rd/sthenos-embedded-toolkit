#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/tools.sh"

TOOL_NAME="strace"
STRACE_VERSION="${STRACE_VERSION:-6.6}"
STRACE_URL="https://github.com/strace/strace/releases/download/v${STRACE_VERSION}/strace-${STRACE_VERSION}.tar.xz"

configure_strace() {
    local arch=$1
    
    standard_configure "$arch" "$TOOL_NAME" \
        --disable-mpers
}

build_strace_impl() {
    local arch=$1
    
    parallel_make
}

install_strace() {
    local arch=$1
    
    install_binary "src/strace" "$arch" "strace" "$TOOL_NAME"
}

build_strace() {
    local arch=$1
    
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
    
    download_source "$TOOL_NAME" "$STRACE_VERSION" "$STRACE_URL" || {
        log_tool_error "$TOOL_NAME" "Failed to download source"
        return 1
    }
    
    cd "$build_dir"
    tar xf "/build/sources/${TOOL_NAME}-${STRACE_VERSION}.tar.xz"
    cd "${TOOL_NAME}-${STRACE_VERSION}"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export_cross_compiler "$CROSS_COMPILE"
    
    configure_strace "$arch" || {
        log_tool_error "$TOOL_NAME" "Configure failed for $arch"
        return 1
    }
    
    build_strace_impl "$arch" || {
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    }
    
    install_strace "$arch" || {
        log_tool_error "$TOOL_NAME" "Installation failed for $arch"
        return 1
    }
    
    trap - EXIT
    cleanup_build_dir "$build_dir"
    
    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>\nBuild strace for specified architecture" "$@"
    
    local arch=$1
    
    mkdir -p "/build/output/$arch"
    
    build_strace "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi