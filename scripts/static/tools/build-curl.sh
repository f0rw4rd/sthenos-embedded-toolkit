#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/source_versions.sh"

SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd,macos"  # Windows needs windres

build_curl() {
    local arch=$1
    local build_dir=$(create_build_dir "curl" "$arch")
    local TOOL_NAME="curl"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "curl"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1

    local output_path=$(get_output_path "$arch" "curl")

    if ! download_and_extract "$CURL_URL" "$build_dir" 0 "$CURL_SHA512"; then
        log_tool_error "curl" "Failed to download and extract source"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    cd "$build_dir/curl-${CURL_VERSION}"

    # Zig's Darwin sysroot lacks the SystemConfiguration framework headers.
    # lib/macos.c only calls SCDynamicStoreCopyProxies to prime IPv4->IPv6
    # synthesis on real macOS hardware; cross-built binaries can safely skip
    # it. Stub the file so the guard never includes the missing header.
    case "$arch" in
        *_macos|*_darwin)
            cat > lib/macos.c << 'EOF'
#include "curl_setup.h"
#include <curl/curl.h>
#include "macos.h"
#ifdef CURL_MACOS_CALL_COPYPROXIES
#undef Curl_macos_init
CURLcode Curl_macos_init(void) { return CURLE_OK; }
#endif
EOF
            ;;
    esac

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export PKG_CONFIG="pkg-config --static"
    
    log_tool "curl" "Configuring curl for $arch..."
    
    ./configure \
        --host=$HOST \
        --prefix=/usr \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-silent-rules \
        --disable-debug \
        --disable-curldebug \
        --enable-symbol-hiding \
        --disable-ares \
        --disable-rt \
        --disable-largefile \
        --disable-hsts \
        --disable-manual \
        --disable-libcurl-option \
        --disable-librtmp \
        --disable-rtsp \
        --disable-proxy \
        --disable-dict \
        --disable-telnet \
        --disable-tftp \
        --disable-pop3 \
        --disable-imap \
        --disable-smb \
        --disable-smtp \
        --disable-gopher \
        --disable-mqtt \
        --disable-sspi \
        --disable-ntlm \
        --disable-ntlm-wb \
        --disable-tls-srp \
        --disable-unix-sockets \
        --disable-cookies \
        --disable-socketpair \
        --disable-doh \
        --disable-dateparse \
        --disable-netrc \
        --disable-dnsshuffle \
        --disable-get-easy-options \
        --disable-alt-svc \
        --disable-headers-api \
        --disable-verbose \
        --disable-versioned-symbols \
        --disable-threaded-resolver \
        --enable-ipv6 \
        --disable-crypto-auth \
        --enable-ftp \
        --enable-file \
        --disable-ldap \
        --disable-ldaps \
        --disable-ipfs \
        --disable-websockets \
        --disable-mime \
        --enable-http-auth \
        --disable-aws \
        --disable-bearer-auth \
        --disable-kerberos-auth \
        --disable-negotiate-auth \
        --disable-digest-auth \
        --enable-basic-auth \
        --disable-form-api \
        --disable-bindlocal \
        --disable-sha512-256 \
        --enable-progress-meter \
        --without-ssl \
        --without-openssl \
        --without-zlib \
        --without-libssh2 \
        --without-brotli \
        --without-zstd \
        --without-libpsl \
        --without-libgsasl \
        --without-librtmp \
        --without-winidn \
        --without-libidn2 \
        --without-nghttp2 \
        --without-nghttp3 \
        --without-ngtcp2 \
        --without-quiche \
        --without-msh3 \
        --without-wolfssh \
        --without-wolfssl \
        --without-bearssl \
        --without-gnutls \
        --without-mbedtls \
        --without-nss \
        --without-ca-bundle \
        --without-ca-path \
        --without-ca-fallback \
        --without-hyper \
        --without-rustls || {
        log_tool_error "curl" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    log_tool "curl" "Building curl for $arch..."

    # libtool -all-static forces a static executable; Darwin/BSD can't do that.
    local make_ldflags="$ldflags"
    if platform_supports_static; then
        make_ldflags="$ldflags -all-static"
    fi

    make -j$(nproc) LDFLAGS="$make_ldflags" || {
        log_tool_error "curl" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP src/curl
    mkdir -p "$(dirname "$output_path")"
    cp src/curl "$output_path"
    
    local size=$(get_binary_size "$output_path")
    log_tool "curl" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_curl "$arch"
