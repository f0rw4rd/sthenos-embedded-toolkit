#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/core/compile_flags.sh"
source "$SCRIPT_DIR/build_helpers.sh"
source "$SCRIPT_DIR/tools.sh"

DEPS_CACHE_DIR="/build/deps-cache"

build_dependency_generic() {
    local dep_name=$1
    local version=$2
    local url=$3
    local extract_name=$4
    local arch=$5
    local configure_func=$6
    local build_func=$7
    local install_func=$8
    local expected_sha512=$9
    
    local cache_dir="$DEPS_CACHE_DIR/$arch/$dep_name-$version"
    
    if $install_func check "$cache_dir"; then
        log_info "Using cached $dep_name $version for $arch from $cache_dir" >&2
        echo "$cache_dir"
        return 0
    fi
    
    log_info "Building $dep_name $version for $arch..." >&2
    
    setup_toolchain_for_arch "$arch" || return 1
    download_source "$dep_name" "$version" "$url" "$expected_sha512" "$extract_name" || return 1
    
    local build_dir="/tmp/$dep_name-build-${arch}-$$"
    mkdir -p "$build_dir" "$cache_dir"
    
    cd "$build_dir"
    
    local archive_file=""
    if [ -f "/build/sources/$extract_name.tar.gz" ]; then
        archive_file="/build/sources/$extract_name.tar.gz"
    elif [ -f "/build/sources/$extract_name.tar.bz2" ]; then
        archive_file="/build/sources/$extract_name.tar.bz2"
    elif [ -f "/build/sources/$extract_name.tar.xz" ]; then
        archive_file="/build/sources/$extract_name.tar.xz"
    else
        local url_file=$(basename "$url")
        if [ -f "/build/sources/$url_file" ]; then
            archive_file="/build/sources/$url_file"
        else
            log_error "Archive not found for $extract_name"
            rm -rf "$build_dir"
            return 1
        fi
    fi
    
    tar xf "$archive_file" --strip-components=1 || {
        rm -rf "$build_dir"
        return 1
    }
    
    local cflags=$(get_compile_flags "$arch" "static" "$dep_name")
    local ldflags=$(get_link_flags "$arch" "static")
    
    if [ "$LIBC_TYPE" != "glibc" ]; then
        export_cross_compiler "$CROSS_COMPILE"
    fi
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    if ! $configure_func "$arch" "$build_dir" "$cache_dir" >&2; then
        log_error "Configuration failed for $dep_name on $arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    if ! $build_func "$arch" "$build_dir" >&2; then
        log_error "Build failed for $dep_name on $arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    if ! $install_func install "$cache_dir" "$build_dir" >&2; then
        log_error "Installation failed for $dep_name on $arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    cleanup_build_dir "$build_dir"
    
    echo "$cache_dir"
    return 0
}

configure_openssl() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    local openssl_cflags=$(echo "$CFLAGS" | sed 's/-fno-pie//g; s/-no-pie//g')
    openssl_cflags="$openssl_cflags -fPIC"
    
    local openssl_target
    case $arch in
        x86_64) openssl_target="linux-x86_64" ;;
        ix86le|i486) openssl_target="linux-x86" ;;
        arm*) 
            if [[ "$arch" == *"v7"* ]]; then
                openssl_target="linux-armv4"
            else
                openssl_target="linux-generic32"
            fi
            ;;
        aarch64*) openssl_target="linux-aarch64" ;;
        mips64*) openssl_target="linux64-mips64" ;;
        mips*) openssl_target="linux-mips32" ;;
        ppc64*) openssl_target="linux-ppc64le" ;;
        ppc32*) openssl_target="linux-ppc" ;;
        riscv64) openssl_target="linux-generic64" ;;
        riscv32) openssl_target="linux-generic32" ;;
        s390x) openssl_target="linux-s390x" ;;
        sh*) openssl_target="linux-generic32" ;;
        *) openssl_target="linux-generic32" ;;
    esac
    
    unset CROSS_COMPILE
    
    # For s390x, we need to use linux64-s390x instead of linux-s390x
    if [ "$arch" = "s390x" ]; then
        openssl_target="linux64-s390x"
    fi
    
    # Build zlib first if enabling zlib support
    local zlib_dir=$(build_zlib_cached "$arch") || {
        log_error "Failed to build zlib for OpenSSL"
        return 1
    }
    
    ./Configure \
        --prefix="$cache_dir" \
        --openssldir="$cache_dir/ssl" \
        "$openssl_target" \
        no-shared \
        no-dso \
        --with-zlib-include="$zlib_dir/include" \
        --with-zlib-lib="$zlib_dir/lib" \
        zlib \
        no-async \
        no-comp \
        no-ec2m \
        no-sm2 \
        no-sm4 \
        enable-ssl3 \
        enable-ssl3-method \
        enable-weak-ssl-ciphers \
        -static \
        -ffunction-sections -fdata-sections \
        $openssl_cflags
}

build_openssl() {
    local arch=$1
    local build_dir=$2
    
    parallel_make depend
    parallel_make
}

install_openssl() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libssl.a" ] && [ -f "$cache_dir/lib/libcrypto.a" ]
        return $?
    fi
    
    make install_sw
}

build_openssl_cached() {
    local arch=$1
    local version="1.1.1w"
    local sha512="b4c625fe56a4e690b57b6a011a225ad0cb3af54bd8fb67af77b5eceac55cc7191291d96a660c5b568a08a2fbf62b4612818e7cca1bb95b2b6b4fc649b0552b6d"
    
    build_dependency_generic \
        "openssl" \
        "$version" \
        "https://www.openssl.org/source/openssl-$version.tar.gz" \
        "openssl-$version" \
        "$arch" \
        configure_openssl \
        build_openssl \
        install_openssl \
        "$sha512"
}

configure_libpcap() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    local cflags=$(get_compile_flags "$arch" "static" "libpcap")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags -ffunction-sections -fdata-sections"
    export LDFLAGS="$ldflags"
    
    ./configure \
        --host=$HOST \
        --prefix="$cache_dir" \
        --disable-shared \
        --enable-static \
        --disable-usb \
        --disable-netmap \
        --disable-bluetooth \
        --disable-dbus \
        --disable-rdma \
        --with-pcap=linux \
        --without-libnl
}

build_libpcap() {
    local arch=$1
    local build_dir=$2
    
    parallel_make
}

install_libpcap() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libpcap.a" ]
        return $?
    fi
    
    make install
}

build_libpcap_cached() {
    local arch=$1
    local version="1.10.4"
    local sha512="1f6d6ddd07dae7c557054cb246437ecdaf39d579592a5a6bdf1144eea6cb5a779ac4ca647cfed11ec1b0bb18efc63b845444e497070bacefaaed19a5787ae5e1"
    
    build_dependency_generic \
        "libpcap" \
        "$version" \
        "https://www.tcpdump.org/release/libpcap-$version.tar.gz" \
        "libpcap-$version" \
        "$arch" \
        configure_libpcap \
        build_libpcap \
        install_libpcap \
        "$sha512"
}

configure_zlib() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    local cflags=$(get_compile_flags "$arch" "static" "zlib")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags -ffunction-sections -fdata-sections"
    export LDFLAGS="$ldflags"
    
    ./configure \
        --prefix="$cache_dir" \
        --static
}

build_zlib() {
    local arch=$1
    local build_dir=$2
    
    parallel_make
}

install_zlib() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libz.a" ]
        return $?
    fi
    
    make install
}

build_zlib_cached() {
    local arch=$1
    local version="1.3.1"
    local sha512="580677aad97093829090d4b605ac81c50327e74a6c2de0b85dd2e8525553f3ddde17556ea46f8f007f89e435493c9a20bc997d1ef1c1c2c23274528e3c46b94f"
    
    build_dependency_generic \
        "zlib" \
        "$version" \
        "https://zlib.net/zlib-$version.tar.gz" \
        "zlib-$version" \
        "$arch" \
        configure_zlib \
        build_zlib \
        install_zlib \
        "$sha512"
}

configure_ncurses() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    local cflags=$(get_compile_flags "$arch" "static" "ncurses")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags -ffunction-sections -fdata-sections -fPIC"
    export LDFLAGS="$ldflags"
    
    ./configure \
        --host=$HOST \
        --prefix="$cache_dir" \
        --enable-static \
        --disable-shared \
        --without-ada \
        --without-cxx-binding \
        --without-manpages \
        --without-progs \
        --without-tests \
        --disable-big-core \
        --disable-home-terminfo \
        --without-develop \
        --without-debug \
        --without-profile \
        --with-terminfo-dirs="/usr/share/terminfo" \
        --with-default-terminfo-dir="/usr/share/terminfo" \
        --enable-pc-files \
        --with-pkg-config-libdir="$cache_dir/lib/pkgconfig"
}

build_ncurses() {
    local arch=$1
    local build_dir=$2
    
    parallel_make
}

install_ncurses() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libncurses.a" ]
        return $?
    fi
    
    make install
}

build_ncurses_cached() {
    local arch=$1
    local version="6.4"
    local sha512="1c2efff87a82a57e57b0c60023c87bae93f6718114c8f9dc010d4c21119a2f7576d0225dab5f0a227c2cfc6fb6bdbd62728e407f35fce5bf351bb50cf9e0fd34"
    
    build_dependency_generic \
        "ncurses" \
        "$version" \
        "https://ftp.gnu.org/pub/gnu/ncurses/ncurses-$version.tar.gz" \
        "ncurses-$version" \
        "$arch" \
        configure_ncurses \
        build_ncurses \
        install_ncurses \
        "$sha512"
}

configure_readline() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    local ncurses_dir
    ncurses_dir=$(build_ncurses_cached "$arch") || return 1
    
    local cflags=$(get_compile_flags "$arch" "static" "readline")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags -ffunction-sections -fdata-sections -I$ncurses_dir/include"
    export LDFLAGS="$ldflags -L$ncurses_dir/lib"
    
    ./configure \
        --host=$HOST \
        --prefix="$cache_dir" \
        --enable-static \
        --disable-shared \
        --with-curses
}

build_readline() {
    local arch=$1
    local build_dir=$2
    
    parallel_make
}

install_readline() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libreadline.a" ]
        return $?
    fi
    
    make install
}

build_readline_cached() {
    local arch=$1
    local version="8.2"
    local sha512="0a451d459146bfdeecc9cdd94bda6a6416d3e93abd80885a40b334312f16eb890f8618a27ca26868cebbddf1224983e631b1cbc002c1a4d1cd0d65fba9fea49a"
    
    build_dependency_generic \
        "readline" \
        "$version" \
        "https://ftp.gnu.org/gnu/readline/readline-$version.tar.gz" \
        "readline-$version" \
        "$arch" \
        configure_readline \
        build_readline \
        install_readline \
        "$sha512"
}

configure_libelf() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    if [ -d "/build/patches/elfutils" ]; then
        for patch_file in /build/patches/elfutils/*.patch; do
            if [ -f "$patch_file" ]; then
                log_info "Applying $(basename "$patch_file")..." >&2
                patch -p1 < "$patch_file" || true
            fi
        done
    fi
    
    local zlib_dir
    zlib_dir=$(build_zlib_cached "$arch") || return 1
    
    local extra_cflags=""
    local extra_ldflags=""
    local extra_libs=""
    
    if echo "${CC}" | grep -q "musl"; then
        local fts_dir=$(build_musl_fts_cached "$arch") || return 1
        local obstack_dir=$(build_musl_obstack_cached "$arch") || return 1
        local argp_dir=$(build_argp_standalone_cached "$arch") || return 1
        
        extra_cflags="-I$fts_dir/include -I$obstack_dir/include -I$argp_dir/include"
        extra_ldflags="-L$fts_dir/lib -L$obstack_dir/lib -L$argp_dir/lib"
        extra_libs="-largp -lfts -lobstack"
    fi
    
    export CFLAGS="$CFLAGS -ffunction-sections -fdata-sections -fPIC -I$zlib_dir/include $extra_cflags"
    export LDFLAGS="$LDFLAGS -L$zlib_dir/lib $extra_ldflags"
    export LIBS="$extra_libs -lz"
    
    ./configure \
        --host=$HOST \
        --prefix="$cache_dir" \
        --enable-static \
        --disable-shared \
        --disable-libdebuginfod \
        --disable-debuginfod \
        --disable-symbol-versioning \
        --disable-nls \
        --without-bzlib \
        --without-lzma \
        --without-zstd \
        --enable-demangler \
        --program-prefix="" \
        CC="${CC}" \
        AR="${AR}"
}

build_libelf() {
    local arch=$1
    local build_dir=$2
    
    make -C lib LIBS="${LIBS}" || true
    make -C libelf libelf.a LIBS="${LIBS}"
}

install_libelf() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libelf.a" ]
        return $?
    fi
    
    make -C libelf install-includeHEADERS install-libLIBRARIES
}

configure_musl_fts() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    ./bootstrap.sh
    
    local host_triplet
    if [ -n "${CC}" ]; then
        host_triplet=$(${CC} -dumpmachine 2>/dev/null) || host_triplet="${HOST}"
    else
        host_triplet="${HOST}"
    fi
    
    CFLAGS="-fPIC $CFLAGS" ./configure \
        --prefix="$cache_dir" \
        --enable-static \
        --disable-shared \
        --host="${host_triplet}"
}

build_musl_fts() {
    local arch=$1
    local build_dir=$2
    
    parallel_make
}

install_musl_fts() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libfts.a" ]
        return $?
    fi
    
    make install
}

build_musl_fts_cached() {
    local arch=$1
    local version="1.2.7"
    local sha512="949f73b9406b06bd8712c721b4ec89afcb37d4eaef5666cccf3712242d3a57fc0acf3ca994934e0f57c1e92f40521a9370132a21eb6d1957415a83c76bf20feb"
    
    build_dependency_generic \
        "musl-fts" \
        "$version" \
        "https://github.com/void-linux/musl-fts/archive/v$version.tar.gz" \
        "v$version" \
        "$arch" \
        configure_musl_fts \
        build_musl_fts \
        install_musl_fts \
        "$sha512"
}

configure_musl_obstack() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    ./bootstrap.sh
    
    local host_triplet
    if [ -n "${CC}" ]; then
        host_triplet=$(${CC} -dumpmachine 2>/dev/null) || host_triplet="${HOST}"
    else
        host_triplet="${HOST}"
    fi
    
    CFLAGS="-fPIC $CFLAGS" ./configure \
        --prefix="$cache_dir" \
        --enable-static \
        --disable-shared \
        --host="${host_triplet}"
}

build_musl_obstack() {
    local arch=$1
    local build_dir=$2
    
    parallel_make
}

install_musl_obstack() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libobstack.a" ]
        return $?
    fi
    
    make install
}

build_musl_obstack_cached() {
    local arch=$1
    local version="1.2.3"
    local sha512="b2bbed19c4ab2714ca794bdcb1a84fad1af964e884d4f3bbe91c9937ca089d92b8472cb05ebe998a9f5c85cb922b9b458db91eff29077bd099942e1ce18e16cc"
    
    build_dependency_generic \
        "musl-obstack" \
        "$version" \
        "https://github.com/void-linux/musl-obstack/archive/v$version.tar.gz" \
        "v$version" \
        "$arch" \
        configure_musl_obstack \
        build_musl_obstack \
        install_musl_obstack \
        "$sha512"
}

configure_argp_standalone() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    if [ -f "/build/patches/argp-standalone/gnu89-inline.patch" ]; then
        patch -p1 < /build/patches/argp-standalone/gnu89-inline.patch || true
    fi
    
    autoreconf -vif
    
    local host_triplet
    if [ -n "${CC}" ]; then
        host_triplet=$(${CC} -dumpmachine 2>/dev/null) || host_triplet="${HOST}"
    else
        host_triplet="${HOST}"
    fi
    
    CFLAGS="-fPIC $CFLAGS" ./configure \
        --prefix="$cache_dir" \
        --enable-static \
        --disable-shared \
        --host="${host_triplet}"
}

build_argp_standalone() {
    local arch=$1
    local build_dir=$2
    
    parallel_make
}

install_argp_standalone() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libargp.a" ]
        return $?
    fi
    
    install -D -m644 argp.h "$cache_dir/include/argp.h"
    install -D -m755 libargp.a "$cache_dir/lib/libargp.a"
}

build_argp_standalone_cached() {
    local arch=$1
    local version="1.5.0"
    local sha512="fa2eb61ea00f7a13385e5c1e579dd88471d6ba3a13b6353e924fe71914b90b40688b42a9f1789bc246e03417fee1788b1990753cda8c8d4a544e85f26b63f9e2"
    
    build_dependency_generic \
        "argp-standalone" \
        "$version" \
        "https://github.com/argp-standalone/argp-standalone/archive/refs/tags/$version.tar.gz" \
        "$version" \
        "$arch" \
        configure_argp_standalone \
        build_argp_standalone \
        install_argp_standalone \
        "$sha512"
}

build_libelf_cached() {
    local arch=$1
    local version="0.193"
    local sha512="557e328e3de0d2a69d09c15a9333f705f3233584e2c6a7d3ce855d06a12dc129e69168d6be64082803630397bd64e1660a8b5324d4f162d17922e10ddb367d76"
    
    build_dependency_generic \
        "elfutils" \
        "$version" \
        "https://sourceware.org/elfutils/ftp/$version/elfutils-$version.tar.bz2" \
        "elfutils-$version" \
        "$arch" \
        configure_libelf \
        build_libelf \
        install_libelf \
        "$sha512"
}

configure_libssh2() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    # Build OpenSSL first as dependency
    local openssl_dir=$(build_openssl_cached "$arch") || {
        log_error "Failed to build OpenSSL for libssh2"
        return 1
    }
    
    # Build zlib as optional dependency for compression
    local zlib_dir=$(build_zlib_cached "$arch") || {
        log_error "Failed to build zlib for libssh2"
        return 1
    }
    
    local cflags=$(get_compile_flags "$arch" "static" "libssh2")
    local ldflags=$(get_link_flags "$arch" "static")
    
    # Add OpenSSL and zlib paths
    cflags="$cflags -I$openssl_dir/include -I$zlib_dir/include"
    ldflags="$ldflags -L$openssl_dir/lib -L$zlib_dir/lib"
    
    export CFLAGS="$cflags -ffunction-sections -fdata-sections"
    export LDFLAGS="$ldflags"
    export LIBS="-lssl -lcrypto -lz"
    
    ./configure \
        --host=$HOST \
        --prefix="$cache_dir" \
        --with-openssl \
        --with-libssl-prefix="$openssl_dir" \
        --with-libz \
        --with-libz-prefix="$zlib_dir" \
        --disable-shared \
        --enable-static \
        --disable-examples-build \
        --disable-debug \
        --disable-dependency-tracking
}

build_libssh2() {
    local arch=$1
    local build_dir=$2
    
    parallel_make
}

install_libssh2() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libssh2.a" ]
        return $?
    fi
    
    make install
}

build_libssh2_cached() {
    local arch=$1
    local version="1.11.1"
    local sha512="8703636fc28f0b12c8171712f3d605e0466a5bb9ba06e136c3203548fc3408ab07defd71dc801d7009a337e1e02fd60e8933a2a526d5ef0ce53153058d201233"
    
    build_dependency_generic \
        "libssh2" \
        "$version" \
        "https://libssh2.org/download/libssh2-$version.tar.gz" \
        "libssh2-$version" \
        "$arch" \
        configure_libssh2 \
        build_libssh2 \
        install_libssh2 \
        "$sha512"
}
