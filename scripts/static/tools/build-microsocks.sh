#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

MICROSOCKS_VERSION="${MICROSOCKS_VERSION:-1.0.5}"
MICROSOCKS_URL="http://ftp.barfooze.de/pub/sabotage/tarballs/microsocks-${MICROSOCKS_VERSION}.tar.xz"
MICROSOCKS_SHA512="16b99f1b94dd857f6ee303f2fb3ef85acd5d8cad2a7635bca7d78c3106bd9beb846a4363286d2d1f395a9bcc115890736c883835590f22234e7955fab6066a66"

SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd,macos,windows"  # Windows build uses winsock2 port (see patches/microsocks/windows-port.patch)

build_microsocks() {
    local arch=$1
    local build_dir=$(create_build_dir "microsocks" "$arch")
    local TOOL_NAME="microsocks"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "microsocks"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1

    if ! download_and_extract "$MICROSOCKS_URL" "$build_dir" 0 "$MICROSOCKS_SHA512"; then
        log_tool_error "microsocks" "Failed to download and extract source"
        cleanup_build_dir "$build_dir"
        return 1
    fi

    cd "$build_dir/microsocks-${MICROSOCKS_VERSION}"

    # Apply the Windows (winsock2) portability patch. The patch is ifdef-
    # gated on _WIN32, so it's safe to apply unconditionally — Linux/BSD/
    # macOS builds pick up only whitespace-equivalent changes.
    local patches_dir="/build/patches/microsocks"
    if [ -d "$patches_dir" ]; then
        for patch_file in "$patches_dir"/*.patch; do
            [ -f "$patch_file" ] || continue
            log_tool "microsocks" "Applying $(basename "$patch_file")..."
            patch -p1 < "$patch_file" || {
                log_tool_error "microsocks" "Failed to apply $(basename "$patch_file")"
                cleanup_build_dir "$build_dir"
                return 1
            }
        done
    fi

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    # Windows (Zig CC targeting *-windows-gnu) needs the winsock2 + winpthreads
    # import libraries linked in. On POSIX targets, just -lpthread suffices.
    local extra_libs="-lpthread"
    if [[ "${ZIG_TARGET:-}" == *"windows"* ]] || [[ "$arch" == *_windows ]]; then
        extra_libs="-lpthread -lws2_32"
    fi

    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    log_tool "microsocks" "Building microsocks for $arch..."

    make -j$(nproc) CC="${CC}" CFLAGS="$cflags" LDFLAGS="$ldflags $extra_libs" LIBS="$extra_libs" || {
        log_tool_error "microsocks" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }

    # The produced binary is named `microsocks` on POSIX; MinGW may append
    # .exe automatically for Windows PE targets. Handle both.
    local built_binary="microsocks"
    [ -f "microsocks.exe" ] && built_binary="microsocks.exe"

    $STRIP "$built_binary" 2>/dev/null || true
    local output_path=$(get_output_path "$arch" "microsocks")
    mkdir -p "$(dirname "$output_path")"
    cp "$built_binary" "$output_path"
    
    local size=$(get_binary_size "$output_path")
    log_tool "microsocks" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_microsocks "$arch"