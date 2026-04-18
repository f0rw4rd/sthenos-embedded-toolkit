#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

GDB_VERSION="${GDB_VERSION:-16.3}"
GDB_URL="https://mirrors.kernel.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz"
GDB_SHA512="fffd6689c3405466a179670b04720dc825e4f210a761f63dd2b33027432f8cd5d1c059c431a5ec9e165eedd1901220b5329d73c522f9a444788888c731b29e9c"

SUPPORTED_OS="linux,android"  # gdbserver uses Linux ptrace flavor and /proc

build_gdbserver() {
    local arch=$1
    local build_dir=$(create_build_dir "gdbserver" "$arch")
    local TOOL_NAME="gdbserver"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "gdbserver"; then
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    if ! download_and_extract "$GDB_URL" "$build_dir" 0 "$GDB_SHA512"; then
        log_tool_error "gdbserver" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/gdb-${GDB_VERSION}"

    # Patch loongarch64 for musl: gdbserver references elf_{lsx,lasx,lbt}regset_t
    # which are glibc-specific typedefs (sysdeps/unix/sysv/linux/loongarch/bits/procfs.h).
    # Musl doesn't provide them. Alpine Linux patches musl; we patch the source instead.
    # Definitions match glibc and kernel struct sizes.
    case "$arch" in
        loongarch64)
            cat > gdbserver/loongarch-musl-compat.h <<'PATCH'
#ifndef LOONGARCH_MUSL_COMPAT_H
#define LOONGARCH_MUSL_COMPAT_H
#ifndef __GLIBC__
#include <stdint.h>
typedef union { double d[2]; float f[4]; } __attribute__((aligned(16))) elf_lsxregset_t[32];
typedef union { double d[4]; float f[8]; } __attribute__((aligned(32))) elf_lasxregset_t[32];
typedef struct { uint64_t scr[4]; uint32_t eflags; uint32_t ftop; } elf_lbtregset_t;
#endif
#endif
PATCH
            sed -i '1i #include "loongarch-musl-compat.h"' gdbserver/linux-loongarch-low.cc
            log_tool "gdbserver" "Applied musl LoongArch LSX/LASX/LBT typedef patch"
            ;;
    esac

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    ./configure \
        --host=$HOST \
        --target=$HOST \
        --prefix=/usr \
        --disable-gdb \
        --enable-gdbserver \
        --disable-gdbtk \
        --disable-tui \
        --disable-werror \
        --without-x \
        --disable-sim \
        --without-lzma \
        --without-python \
        --without-guile \
        --without-gmp \
        --without-mpfr \
        --disable-inprocess-agent \
        --disable-nls \
        --without-expat \
        --disable-source-highlight || {
        log_tool_error "gdbserver" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    make -j$(nproc) all-gdbserver MAKEINFO=true || {
        log_tool_error "gdbserver" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP gdbserver/gdbserver
    local output_path=$(get_output_path "$arch" "gdbserver")
    mkdir -p "$(dirname "$output_path")"
    cp gdbserver/gdbserver "$output_path"
    
    local size=$(ls -lh "/build/output/$arch/gdbserver" | awk '{print $5}')
    log_tool "gdbserver" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_gdbserver "$arch"
