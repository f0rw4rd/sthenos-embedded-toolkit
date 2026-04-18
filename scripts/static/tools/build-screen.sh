#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/tools.sh"

TOOL_NAME="screen"
SUPPORTED_OS="linux,android"  # Not verified on BSD/macOS; re-enable once tested
SCREEN_VERSION="${SCREEN_VERSION:-5.0.1}"
SCREEN_URL="https://ftp.gnu.org/gnu/screen/screen-${SCREEN_VERSION}.tar.gz"
SCREEN_SHA512="9bda35689d73a816515df30f50101531cf3af8906cb47f086d1f97c464cb729f4ee6e3d4aca220acc4c6125d81e923ee3a11fb3a85fe6994002bf1e0f3cc46fb"

configure_screen() {
    local arch=$1
    local ncurses_dir=$2

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    export CFLAGS="$cflags -I$ncurses_dir/include -I$ncurses_dir/include/ncurses"
    export LDFLAGS="$ldflags -L$ncurses_dir/lib"

    ./configure \
        --host=$HOST \
        --enable-static \
        --disable-shared \
        --disable-pam \
        --disable-socket-dir \
        --disable-telnet \
        --disable-use-locale \
        --with-sys-screenrc=/etc/screenrc
}

build_screen_impl() {
    local arch=$1

    parallel_make
}

install_screen() {
    local arch=$1

    install_binary "screen" "$arch" "screen" "$TOOL_NAME"
}

build_screen() {
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

    # Build ncurses dependency (screen requires tgetent from ncurses/termcap)
    local ncurses_dir
    ncurses_dir=$(build_ncurses_cached "$arch") || {
        log_tool_error "$TOOL_NAME" "Failed to build ncurses dependency for $arch"
        return 1
    }

    local build_dir
    build_dir=$(create_build_dir "$TOOL_NAME" "$arch")

    trap "cleanup_build_dir '$build_dir'" EXIT

    if ! download_and_extract "$SCREEN_URL" "$build_dir" 0 "$SCREEN_SHA512"; then
        log_tool_error "$TOOL_NAME" "Failed to download and extract source"
        return 1
    fi

    cd "$build_dir/${TOOL_NAME}-${SCREEN_VERSION}"

    configure_screen "$arch" "$ncurses_dir" || {
        log_tool_error "$TOOL_NAME" "Configure failed for $arch"
        return 1
    }

    build_screen_impl "$arch" || {
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    }

    install_screen "$arch" || {
        log_tool_error "$TOOL_NAME" "Install failed for $arch"
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

    build_screen "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
