#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

SOCAT_VERSION="${SOCAT_VERSION:-1.8.0.3}"
SOCAT_URL="http://www.dest-unreach.org/socat/download/socat-${SOCAT_VERSION}.tar.gz"
SOCAT_SHA512="600a3387e9756e0937d2db49de9066df03d9818e4042da6b72109d1b5688dd72352754773a19bd2558fe93ec6a8a73e80e7cf2602fd915960f66c403fd89beef"

SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd"  # macOS: ncurses dep needs sys/ttydev.h missing from Zig Darwin shim

build_socat_ssl() {
    local arch=$1
    local build_dir=$(create_build_dir "socat-ssl" "$arch")
    local TOOL_NAME="socat-ssl"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "socat-ssl"; then
        return 0
    fi
    
    
    setup_toolchain_for_arch "$arch" || return 1
    
    # Split local decl from assignment — `local x=$(cmd)` always returns 0.
    local ssl_dir
    ssl_dir=$(build_openssl_cached "$arch") || {
        log_tool_error "socat-ssl" "Failed to build/get OpenSSL for $arch"
        return 1
    }

    local readline_dir
    readline_dir=$(build_readline_cached "$arch") || {
        log_tool_error "socat-ssl" "Failed to build/get readline for $arch"
        return 1
    }

    local ncurses_dir
    ncurses_dir=$(build_ncurses_cached "$arch") || {
        log_tool_error "socat-ssl" "Failed to build/get ncurses for $arch"
        return 1
    }
    
    ssl_dir=$(echo "$ssl_dir" | tr -d '\n' | xargs)
    readline_dir=$(echo "$readline_dir" | tr -d '\n' | xargs)
    ncurses_dir=$(echo "$ncurses_dir" | tr -d '\n' | xargs)
    
    if ! download_and_extract "$SOCAT_URL" "$build_dir" 0 "$SOCAT_SHA512"; then
        log_tool_error "socat-ssl" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/socat-${SOCAT_VERSION}"
    
    generate_socat_cross_cache "$arch" config.cache

    # Darwin aarch64 removed struct stat64 (arm64 stat is natively 64-bit).
    case "$arch" in
        *_macos|*_darwin)
            sed -i 's/^sc_cv_type_stat64=.*/sc_cv_type_stat64=no/' config.cache
            ;;
    esac
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    # socat.c embeds __DATE__/__TIME__; Clang treats this as an error under -Werror.
    # On Darwin/BSD: openpty header location differs, FreeBSD mqd_t is a pointer.
    cflags="$cflags -Wno-date-time -Wno-error=date-time"
    cflags="$cflags -Wno-error=implicit-function-declaration -Wno-error=int-conversion"

    log_tool "socat-ssl" "CFLAGS: $cflags -I$ssl_dir/include -I$readline_dir/include -I$ncurses_dir/include"
    log_tool "socat-ssl" "LDFLAGS: $ldflags -L$ssl_dir/lib -L$readline_dir/lib -L$ncurses_dir/lib"
    log_tool "socat-ssl" "CC: $CC"
    log_tool "socat-ssl" "HOST: $HOST"
    
    CFLAGS="${CFLAGS:-} $cflags -I$ssl_dir/include -I$readline_dir/include -I$ncurses_dir/include" \
    LDFLAGS="${LDFLAGS:-} $ldflags -L$ssl_dir/lib -L$readline_dir/lib -L$ncurses_dir/lib" \
    LIBS="-lssl -lcrypto -lreadline -lncurses" \
    ./configure \
        --host=$HOST \
        --cache-file=config.cache \
        --enable-openssl \
        --disable-libwrap \
        --disable-fips || {
        log_tool_error "socat-ssl" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    make V=1 -j$(nproc) || {
        log_tool_error "socat-ssl" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP socat
    local output_path=$(get_output_path "$arch" "socat-ssl")
    mkdir -p "$(dirname "$output_path")"
    cp socat "$output_path"
    
    local size=$(ls -lh "/build/output/$arch/socat-ssl" | awk '{print $5}')
    log_tool "socat-ssl" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_socat_ssl "$arch"
