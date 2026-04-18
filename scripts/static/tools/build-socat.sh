#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"

SOCAT_VERSION="${SOCAT_VERSION:-1.8.0.3}"
SOCAT_URL="http://www.dest-unreach.org/socat/download/socat-${SOCAT_VERSION}.tar.gz"
SOCAT_SHA512="600a3387e9756e0937d2db49de9066df03d9818e4042da6b72109d1b5688dd72352754773a19bd2558fe93ec6a8a73e80e7cf2602fd915960f66c403fd89beef"

SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd,macos"

build_socat() {
    local arch=$1
    local build_dir=$(create_build_dir "socat" "$arch")
    local TOOL_NAME="socat"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "socat"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1
    
    if ! download_and_extract "$SOCAT_URL" "$build_dir" 0 "$SOCAT_SHA512"; then
        log_tool_error "socat" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/socat-${SOCAT_VERSION}"
    
    generate_socat_cross_cache "$arch" config.cache

    # Darwin aarch64 removed struct stat64 (arm64 stat is natively 64-bit).
    # Force socat to use struct stat instead by overriding the cache entry.
    case "$arch" in
        *_macos|*_darwin)
            sed -i 's/^sc_cv_type_stat64=.*/sc_cv_type_stat64=no/' config.cache
            ;;
    esac
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    # socat.c embeds __DATE__/__TIME__; Clang treats this as an error under -Werror.
    # On Darwin/BSD: openpty lives in <util.h>/<libutil.h> not <pty.h>, and FreeBSD's
    # mqd_t is a pointer not an int — downgrade these to warnings so cross-compile proceeds.
    cflags="$cflags -Wno-date-time -Wno-error=date-time"
    cflags="$cflags -Wno-error=implicit-function-declaration -Wno-error=int-conversion"

    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    ./configure \
        --host=$HOST \
        --cache-file=config.cache \
        --disable-openssl \
        --disable-readline \
        --disable-libwrap \
        --disable-fips || {
        log_tool_error "socat" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    make -j$(nproc) || {
        log_tool_error "socat" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP socat
    local output_path=$(get_output_path "$arch" "socat")
    mkdir -p "$(dirname "$output_path")"
    cp socat "$output_path"
    
    local size=$(get_binary_size "$output_path")
    log_tool "socat" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_socat "$arch"
