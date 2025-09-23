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

build_curl() {
    local arch=$1
    local build_dir=$(create_build_dir "curl" "$arch")
    local TOOL_NAME="curl"
    
    local output_path=$(get_output_path "$arch" "curl")
    if [ -f "$output_path" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(get_binary_size "$output_path")
        log "[$arch] Already built: $output_path ($size)"
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    if ! download_and_extract "$CURL_URL" "$build_dir" 0 "$CURL_SHA512"; then
        log_tool_error "curl" "Failed to download and extract source"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    cd "$build_dir/curl-${CURL_VERSION}"
    
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
    
    make -j$(nproc) LDFLAGS="-static -all-static -Wl,-s $ldflags" || {
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
