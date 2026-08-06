#!/bin/bash


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/core/os_targets.sh"
source "$LIB_DIR/build_helpers.sh"

TOOL_NAME="custom"
# Only OSes where Zig has good libc support for cross-compilation
# BSDs now supported since we use dynamic libc
SUPPORTED_OS="any"
SOURCE_PATH="/build/example-custom-tool"    # Your source code directory
BINARY_NAME="custom"                        # Name of final executable

# Resolve the target OS from the arch name (e.g. x86_64_freebsd -> freebsd).
# Non-Zig arches are always Linux.
custom_target_os() {
    local arch=$1
    if [ "${USE_ZIG:-0}" != "1" ]; then
        echo "linux"
        return
    fi
    local os
    for os in "${ALL_OS_TARGETS[@]}"; do
        if [[ "$arch" == *"_${os}" ]]; then
            echo "$os"
            return
        fi
    done
    echo "linux"
}

# Human-readable C library for the target, so a cross-built binary reports the
# libc it was actually linked against instead of guessing from preprocessor
# macros (musl defines no identifying macro, and Zig targets use the platform
# libc, not musl/glibc).
custom_libc_desc() {
    local target_os=$1
    if [ "${USE_ZIG:-0}" != "1" ]; then
        echo "${LIBC_TYPE:-musl}"
        return
    fi
    case "$target_os" in
        macos|ios|tvos|watchos|visionos|maccatalyst) echo "Darwin libSystem" ;;
        freebsd)   echo "FreeBSD libc" ;;
        openbsd)   echo "OpenBSD libc" ;;
        netbsd)    echo "NetBSD libc" ;;
        dragonfly) echo "DragonFly libc" ;;
        windows)   echo "mingw-w64 (msvcrt)" ;;
        wasi)      echo "wasi-libc" ;;
        linux)     echo "musl (zig)" ;;
        *)         echo "zig libc" ;;
    esac
}

build_custom() {
    local arch=$1
    
    # Check OS compatibility
    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi
    
    if check_binary_exists "$arch" "$TOOL_NAME"; then
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Failed to setup toolchain for $arch"
        return 1
    }
    download_toolchain "$arch" || return 1
    
    local build_dir
    build_dir=$(create_build_dir "$TOOL_NAME" "$arch")
    trap "cleanup_build_dir '$build_dir'" EXIT
    
    cp -r "$SOURCE_PATH"/* "$build_dir/"
    cd "$build_dir"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    # Authoritative target facts for the info box — the build system knows the
    # exact arch/OS/libc, so the binary reports them instead of guessing.
    local target_os
    target_os=$(custom_target_os "$arch")
    export STHENOS_ARCH="$arch"
    export STHENOS_OS="$target_os"
    export STHENOS_LIBC="$(custom_libc_desc "$target_os")"

    # Only export cross compiler for non-Zig builds
    if [ "${USE_ZIG:-0}" = "0" ]; then
        export_cross_compiler "$CROSS_COMPILE"
    fi
    
    make clean || true
    if ! make -j$(nproc 2>/dev/null || echo 4); then
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        trap - EXIT
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    if ! install_binary "./$BINARY_NAME" "$arch" "$BINARY_NAME" "$TOOL_NAME"; then
        trap - EXIT
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    trap - EXIT
    cleanup_build_dir "$build_dir"
    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>" "$@"
    local arch=$1
    mkdir -p "/build/output/$arch"
    build_custom "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

