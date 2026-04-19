#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/tools.sh"

TOOL_NAME="strace"
SUPPORTED_OS="linux,android"  # strace is Linux-specific
# Arches with no upstream strace support:
#   - riscv32: upstream strace only supports riscv64 (configure errors out with
#     "architecture riscv32 is not supported by strace"). Hard upstream gate.
STRACE_UNSUPPORTED_ARCHS="riscv32"
STRACE_VERSION="${STRACE_VERSION:-6.6}"
STRACE_URL="https://github.com/strace/strace/releases/download/v${STRACE_VERSION}/strace-${STRACE_VERSION}.tar.xz"
STRACE_SHA512="77ea45c72e513f6c07026cd9b2cc1a84696a5a35cdd3b06dd4a360fb9f9196958e3f6133b4a9c91e091c24066ba29e0330b6459d18a9c390caae2dba97ab399b"

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
    
    # Check OS compatibility
    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    for unsupported in $STRACE_UNSUPPORTED_ARCHS; do
        if [ "$arch" = "$unsupported" ]; then
            log_tool "$TOOL_NAME" "SKIP: $arch has no upstream strace support in strace-${STRACE_VERSION}"
            return 2
        fi
    done

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
    
    if ! download_and_extract "$STRACE_URL" "$build_dir" 0 "$STRACE_SHA512"; then
        log_tool_error "$TOOL_NAME" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/${TOOL_NAME}-${STRACE_VERSION}"

    # strace auto-enables -Werror on most archs via its WARN_CFLAGS detection.
    # Newer GCC (loongarch64, etc.) emits -Wcalloc-transposed-args on count.c
    # which then fails the build. Appending -Wno-error to user CFLAGS disables
    # the promotion to error without dropping the warning output.
    local werror_relax="-Wno-error"

    # m68k-specific: strace's xlat/pollflags hardcodes POLLWRBAND=0x0100 for
    # m68k (kernel UAPI value), but musl's userspace <poll.h> exposes
    # POLLWRBAND=0x0200 uniformly across all archs. The resulting static_assert
    # fails at compile time (a hard error, not suppressible via -Wno-error).
    # Remove m68k from the arch-specific branch in both the .in (source of
    # truth) and the pre-generated .h so the "default" 0x0200 branch is used.
    if [ "$arch" = "m68k" ]; then
        local xlat_dir="$build_dir/${TOOL_NAME}-${STRACE_VERSION}/src/xlat"
        if [ -f "$xlat_dir/pollflags.in" ]; then
            sed -i 's|defined(__m68k__) \|\| defined(__mips__)|defined(__mips__)|g' \
                "$xlat_dir/pollflags.in"
        fi
        if [ -f "$xlat_dir/pollflags.h" ]; then
            sed -i 's|defined(__m68k__) \|\| defined(__mips__)|defined(__mips__)|g' \
                "$xlat_dir/pollflags.h"
            # Keep .h newer than .in so gen.sh does not re-run and overwrite.
            touch "$xlat_dir/pollflags.h"
        fi
    fi

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    export CFLAGS="$cflags $werror_relax"
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
