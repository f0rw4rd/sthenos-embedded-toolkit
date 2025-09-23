#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

CURL_VERSION="${CURL_VERSION:-8.16.0}"
CURL_URL="https://curl.se/download/curl-${CURL_VERSION}.tar.xz"
CURL_SHA512="8262c3dc113cfd5744ef1b82dbccaa69448a9395ad5c094c22df5cf537a047a927d3332db2cb3be12a31a68a60d8d0fa8485b916e975eda36a4ebd860da4f621"

build_curl_full() {
    local arch=$1
    local build_dir=$(create_build_dir "curl-full" "$arch")
    local TOOL_NAME="curl-full"
    
    local output_path=$(get_output_path "$arch" "curl-full")
    if [ -f "$output_path" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(get_binary_size "$output_path")
        log "[$arch] Already built: $output_path ($size)"
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    log_tool "curl-full" "Building dependencies for $arch..."
    
    local openssl_dir=$(build_openssl_cached "$arch") || {
        log_tool_error "curl-full" "Failed to build/get OpenSSL for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    local zlib_dir=$(build_zlib_cached "$arch") || {
        log_tool_error "curl-full" "Failed to build/get zlib for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    local libssh2_dir=$(build_libssh2_cached "$arch") || {
        log_tool_error "curl-full" "Failed to build/get libssh2 for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    if ! download_and_extract "$CURL_URL" "$build_dir" 0 "$CURL_SHA512"; then
        log_tool_error "curl-full" "Failed to download and extract source"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    cd "$build_dir/curl-${CURL_VERSION}"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    cflags="$cflags -I$openssl_dir/include -I$zlib_dir/include -I$libssh2_dir/include"
    ldflags="$ldflags -L$openssl_dir/lib -L$zlib_dir/lib -L$libssh2_dir/lib"
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export PKG_CONFIG="pkg-config --static"
    export PKG_CONFIG_PATH="$openssl_dir/lib/pkgconfig:$zlib_dir/lib/pkgconfig:$libssh2_dir/lib/pkgconfig"
    
    log_tool "curl-full" "Configuring curl-full for $arch..."
    
    ./configure \
        --host=$HOST \
        --prefix=/usr \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-silent-rules \
        --enable-optimize \
        --enable-symbol-hiding \
        --enable-http \
        --enable-ftp \
        --enable-file \
        --disable-ldap \
        --disable-ldaps \
        --enable-rtsp \
        --enable-proxy \
        --enable-dict \
        --enable-telnet \
        --enable-tftp \
        --enable-pop3 \
        --enable-imap \
        --enable-smb \
        --enable-smtp \
        --enable-gopher \
        --enable-mqtt \
        --enable-manual \
        --enable-ipv6 \
        --enable-threaded-resolver \
        --enable-pthreads \
        --enable-verbose \
        --disable-sspi \
        --enable-tls-srp \
        --enable-unix-sockets \
        --enable-cookies \
        --enable-socketpair \
        --enable-http-auth \
        --enable-doh \
        --enable-mime \
        --enable-dateparse \
        --enable-netrc \
        --enable-progress-meter \
        --enable-dnsshuffle \
        --enable-get-easy-options \
        --enable-alt-svc \
        --enable-hsts \
        --enable-websockets \
        --enable-headers-api \
        --with-openssl="$openssl_dir" \
        --with-zlib="$zlib_dir" \
        --with-libssh2="$libssh2_dir" \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
        --with-ca-path=/etc/ssl/certs \
        --with-ca-fallback \
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
        --without-hyper \
        --without-rustls || {
        log_tool_error "curl-full" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    log_tool "curl-full" "Building curl-full for $arch..."
    
    make -j$(nproc) LDFLAGS="-static -all-static -Wl,-s $ldflags" || {
        log_tool_error "curl-full" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP src/curl
    mkdir -p "$(dirname "$output_path")"
    cp src/curl "$output_path"
    
    local size=$(get_binary_size "$output_path")
    log_tool "curl-full" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_curl_full "$arch"
