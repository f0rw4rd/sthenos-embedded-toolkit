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
    
    local cache_dir="$DEPS_CACHE_DIR/$arch/$dep_name-$version"
    
    if $install_func check "$cache_dir"; then
        log_info "Using cached $dep_name $version for $arch from $cache_dir" >&2
        echo "$cache_dir"
        return 0
    fi
    
    log_info "Building $dep_name $version for $arch..." >&2
    
    setup_toolchain_for_arch "$arch" || return 1
    download_source "$dep_name" "$version" "$url" "$extract_name" || return 1
    
    local build_dir="/tmp/$dep_name-build-${arch}-$$"
    mkdir -p "$build_dir" "$cache_dir"
    
    cd "$build_dir"
    
    # Detect archive format from downloaded file
    local archive_file=""
    if [ -f "/build/sources/$extract_name.tar.gz" ]; then
        archive_file="/build/sources/$extract_name.tar.gz"
    elif [ -f "/build/sources/$extract_name.tar.bz2" ]; then
        archive_file="/build/sources/$extract_name.tar.bz2"
    elif [ -f "/build/sources/$extract_name.tar.xz" ]; then
        archive_file="/build/sources/$extract_name.tar.xz"
    else
        # Try to find by URL filename
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
    
    # Only call export_cross_compiler for musl builds
    # For glibc, the variables are already set by setup_toolchain_for_arch
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
    
    # OpenSSL's Configure script uses CROSS_COMPILE env var if set,
    # but we already have the full compiler paths in CC/CXX
    unset CROSS_COMPILE
    
    ./Configure \
        --prefix="$cache_dir" \
        --openssldir="$cache_dir/ssl" \
        "$openssl_target" \
        no-shared \
        no-dso \
        no-zlib \
        no-async \
        no-comp \
        no-idea \
        no-mdc2 \
        no-rc5 \
        no-ec2m \
        no-sm2 \
        no-sm4 \
        no-ssl3 \
        no-seed \
        no-weak-ssl-ciphers \
        -static \
        -ffunction-sections -fdata-sections \
        "$openssl_cflags"
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
    local version="${2:-1.1.1w}"
    
    build_dependency_generic \
        "openssl" \
        "$version" \
        "https://www.openssl.org/source/openssl-$version.tar.gz" \
        "openssl-$version" \
        "$arch" \
        configure_openssl \
        build_openssl \
        install_openssl
}

configure_libpcap() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    export CFLAGS="$CFLAGS -ffunction-sections -fdata-sections"
    
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
    local version="${2:-1.10.4}"
    
    build_dependency_generic \
        "libpcap" \
        "$version" \
        "https://www.tcpdump.org/release/libpcap-$version.tar.gz" \
        "libpcap-$version" \
        "$arch" \
        configure_libpcap \
        build_libpcap \
        install_libpcap
}

configure_zlib() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    export CFLAGS="$CFLAGS -ffunction-sections -fdata-sections"
    
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
    local version="${2:-1.3.1}"
    
    build_dependency_generic \
        "zlib" \
        "$version" \
        "https://zlib.net/zlib-$version.tar.gz" \
        "zlib-$version" \
        "$arch" \
        configure_zlib \
        build_zlib \
        install_zlib
}

configure_ncurses() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    export CFLAGS="$CFLAGS -ffunction-sections -fdata-sections -fPIC"
    
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
    local version="${2:-6.4}"
    
    build_dependency_generic \
        "ncurses" \
        "$version" \
        "https://ftp.gnu.org/pub/gnu/ncurses/ncurses-$version.tar.gz" \
        "ncurses-$version" \
        "$arch" \
        configure_ncurses \
        build_ncurses \
        install_ncurses
}

configure_readline() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    local ncurses_dir
    ncurses_dir=$(build_ncurses_cached "$arch") || return 1
    
    export CFLAGS="$CFLAGS -ffunction-sections -fdata-sections -I$ncurses_dir/include"
    export LDFLAGS="$LDFLAGS -L$ncurses_dir/lib"
    
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
    local version="${2:-8.2}"
    
    build_dependency_generic \
        "readline" \
        "$version" \
        "https://ftp.gnu.org/gnu/readline/readline-$version.tar.gz" \
        "readline-$version" \
        "$arch" \
        configure_readline \
        build_readline \
        install_readline
}

configure_libelf() {
    local arch=$1
    local build_dir=$2
    local cache_dir=$3
    
    # libelf needs zlib
    local zlib_dir
    zlib_dir=$(build_zlib_cached "$arch") || return 1
    
    export CFLAGS="$CFLAGS -ffunction-sections -fdata-sections -I$zlib_dir/include"
    export LDFLAGS="$LDFLAGS -L$zlib_dir/lib"
    
    ./configure \
        --host=$HOST \
        --prefix="$cache_dir" \
        --enable-static \
        --disable-shared \
        --disable-libdebuginfod \
        --disable-debuginfod \
        --without-bzlib \
        --without-lzma \
        CC="${CC}" \
        AR="${AR}"
}

build_libelf() {
    local arch=$1
    local build_dir=$2
    
    # Build exactly like the original working code but only static lib
    make -C lib
    # Only build the static library, not the shared one
    make -C libelf libelf.a
}

install_libelf() {
    local action=$1
    local cache_dir=$2
    local build_dir=$3
    
    if [ "$action" = "check" ]; then
        [ -f "$cache_dir/lib/libelf.a" ]
        return $?
    fi
    
    # Install only headers and static lib
    make -C libelf install-includeHEADERS install-libLIBRARIES
}

