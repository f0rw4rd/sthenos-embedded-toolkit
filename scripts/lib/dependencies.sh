#!/bin/bash
# Shared dependency management for static builds

# Source centralized build flags
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/build_flags.sh"

# Cache directory for built dependencies
DEPS_CACHE_DIR="/build/deps-cache"

# Build and cache OpenSSL
build_openssl_cached() {
    local arch=$1
    local version="${2:-1.1.1w}"
    local cache_dir="$DEPS_CACHE_DIR/$arch/openssl-$version"
    
    # Check if already built
    if [ -f "$cache_dir/lib/libssl.a" ] && [ -f "$cache_dir/lib/libcrypto.a" ]; then
        echo "Using cached OpenSSL $version for $arch from $cache_dir" >&2
        echo "$cache_dir"
        return 0
    fi
    
    echo "Building OpenSSL $version for $arch..." >&2
    
    # Setup architecture first
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "openssl" "$version" "https://www.openssl.org/source/openssl-$version.tar.gz" "openssl-$version" || return 1
    
    # Create build directory
    local build_dir="/tmp/openssl-build-${arch}-$$"
    mkdir -p "$build_dir" "$cache_dir"
    
    cd "$build_dir"
    tar xf /build/sources/openssl-$version.tar.gz --strip-components=1 || {
        rm -rf "$build_dir"
        return 1
    }
    
    # Setup build environment using centralized flags
    local cflags=$(get_compile_flags "$arch" "openssl")
    local ldflags=$(get_link_flags "$arch")
    
    # OpenSSL needs -fPIC for shared objects even in static builds, but no PIE flags
    # Strip PIE flags that cause issues with OpenSSL configure
    local openssl_cflags=$(echo "$cflags" | sed 's/-fno-pie//g; s/-no-pie//g')
    openssl_cflags="$openssl_cflags -fPIC"
    
    export CFLAGS="$openssl_cflags"
    export CXXFLAGS="$openssl_cflags" 
    export LDFLAGS="$ldflags"
    
    # Determine OpenSSL target based on architecture
    local openssl_target=""
    case "$arch" in
        x86_64) openssl_target="linux-x86_64" ;;
        i486|ix86le) openssl_target="linux-x86" ;;
        arm*) openssl_target="linux-armv4" ;;
        aarch64_be) openssl_target="linux64-aarch64" ;;  # OpenSSL doesn't have specific BE target
        aarch64) openssl_target="linux-aarch64" ;;
        mips64) openssl_target="linux64-mips64" ;;
        mips64*) openssl_target="linux64-mips64" ;;
        mips*) openssl_target="linux-mips32" ;;
        ppc64*|powerpc64*) openssl_target="linux-ppc64" ;;
        ppc*|powerpc*) openssl_target="linux-ppc" ;;
        s390x) openssl_target="linux64-s390x" ;;
        riscv64) openssl_target="linux64-riscv64" ;;
        riscv32) openssl_target="linux32-riscv32" ;;
        *) openssl_target="linux-generic32" ;;  # Generic 32-bit for other archs
    esac
    
    ./Configure "$openssl_target" \
        --prefix="$cache_dir" \
        --openssldir="$cache_dir" \
        no-shared \
        no-tests \
        no-engine \
        no-pic || {
        echo "OpenSSL configure failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Fix the Makefile to use correct compiler and tools
    sed -i "s|^CC=.*|CC=$CC|" Makefile
    sed -i "s|^CFLAGS=.*|CFLAGS=$CFLAGS|" Makefile
    sed -i "s|^AR=.*|AR=$AR|" Makefile
    sed -i "s|^RANLIB=.*|RANLIB=$RANLIB|" Makefile
    
    # Build OpenSSL
    make -j$(nproc) || {
        echo "OpenSSL build failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Install to cache
    make install_sw || {
        echo "OpenSSL install failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    echo "OpenSSL $version built and cached for $arch at $cache_dir" >&2
    echo "$cache_dir"
    return 0
}

# Build and cache libpcap
build_libpcap_cached() {
    local arch=$1
    local version="${2:-1.10.4}"
    local cache_dir="$DEPS_CACHE_DIR/$arch/libpcap-$version"
    
    # Check if already built
    if [ -f "$cache_dir/lib/libpcap.a" ]; then
        echo "Using cached libpcap $version for $arch from $cache_dir" >&2
        echo "$cache_dir"
        return 0
    fi
    
    echo "Building libpcap $version for $arch..." >&2
    
    # Setup architecture first
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "libpcap" "$version" "https://www.tcpdump.org/release/libpcap-$version.tar.gz" "libpcap-$version" || return 1
    
    # Create build directory
    local build_dir="/tmp/libpcap-build-${arch}-$$"
    mkdir -p "$build_dir" "$cache_dir"
    
    cd "$build_dir"
    tar xf /build/sources/libpcap-$version.tar.gz --strip-components=1 || {
        rm -rf "$build_dir"
        return 1
    }
    
    # Setup build environment using centralized flags
    local cflags=$(get_compile_flags "$arch" "libpcap")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export CXXFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    # Configure libpcap
    ./configure \
        --host=$HOST \
        --prefix="$cache_dir" \
        --disable-shared \
        --enable-static \
        --without-libnl \
        --disable-usb \
        --disable-bluetooth \
        --disable-dbus \
        --disable-rdma \
        CC="$CC" \
        CFLAGS="$CFLAGS" \
        LDFLAGS="$LDFLAGS" || {
        echo "libpcap configure failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build libpcap
    make -j$(nproc) || {
        echo "libpcap build failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Install to cache
    make install || {
        echo "libpcap install failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    echo "libpcap $version built and cached for $arch at $cache_dir" >&2
    echo "$cache_dir"
    return 0
}

# Build and cache zlib
build_zlib_cached() {
    local arch=$1
    local version="${2:-1.3.1}"
    local cache_dir="$DEPS_CACHE_DIR/$arch/zlib-$version"
    
    # Check if already built
    if [ -f "$cache_dir/lib/libz.a" ]; then
        echo "Using cached zlib $version for $arch from $cache_dir" >&2
        echo "$cache_dir"
        return 0
    fi
    
    echo "Building zlib $version for $arch..." >&2
    
    # Setup architecture first
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "zlib" "$version" "https://zlib.net/zlib-$version.tar.gz" "zlib-$version" || return 1
    
    # Create build directory
    local build_dir="/tmp/zlib-build-${arch}-$$"
    mkdir -p "$build_dir" "$cache_dir"
    
    cd "$build_dir"
    tar xf /build/sources/zlib-$version.tar.gz --strip-components=1 || {
        rm -rf "$build_dir"
        return 1
    }
    
    # Setup build environment using centralized flags
    local cflags=$(get_compile_flags "$arch" "libpcap")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export CXXFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    # Configure zlib
    CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
    ./configure \
        --prefix="$cache_dir" \
        --static || {
        echo "zlib configure failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build zlib
    make -j$(nproc) || {
        echo "zlib build failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Install to cache
    make install || {
        echo "zlib install failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    echo "zlib $version built and cached for $arch at $cache_dir" >&2
    echo "$cache_dir"
    return 0
}

# Build and cache ncurses
build_ncurses_cached() {
    local arch=$1
    local version="${2:-6.4}"
    local cache_dir="$DEPS_CACHE_DIR/$arch/ncurses-$version"
    
    # Check if already built
    if [ -f "$cache_dir/lib/libncurses.a" ]; then
        echo "Using cached ncurses $version for $arch from $cache_dir" >&2
        echo "$cache_dir"
        return 0
    fi
    
    echo "Building ncurses $version for $arch..." >&2
    
    # Setup architecture first
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "ncurses" "$version" "https://ftp.gnu.org/pub/gnu/ncurses/ncurses-$version.tar.gz" "ncurses-$version" || return 1
    
    # Create build directory
    local build_dir="/tmp/ncurses-build-${arch}-$$"
    mkdir -p "$build_dir" "$cache_dir"
    
    cd "$build_dir"
    tar xf /build/sources/ncurses-$version.tar.gz --strip-components=1 || {
        rm -rf "$build_dir"
        return 1
    }
    
    # Setup build environment using centralized flags
    local cflags=$(get_compile_flags "$arch" "libpcap")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export CXXFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    # Configure ncurses
    ./configure \
        --host=$HOST \
        --prefix="$cache_dir" \
        --without-shared \
        --without-cxx-binding \
        --without-ada \
        --without-manpages \
        --without-tests \
        --disable-database \
        --with-fallbacks=linux,xterm,xterm-256color \
        CC="$CC" \
        CFLAGS="$CFLAGS" \
        LDFLAGS="$LDFLAGS" >/dev/null 2>&1 || {
        echo "ncurses configure failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build ncurses
    make -j$(nproc) >/dev/null 2>&1 || {
        echo "ncurses build failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Install to cache
    make install >/dev/null 2>&1 || {
        echo "ncurses install failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    echo "ncurses $version built and cached for $arch at $cache_dir" >&2
    echo "$cache_dir"
    return 0
}

# Build and cache readline
build_readline_cached() {
    local arch=$1
    local version="${2:-8.2}"
    local cache_dir="$DEPS_CACHE_DIR/$arch/readline-$version"
    
    # Check if already built
    if [ -f "$cache_dir/lib/libreadline.a" ]; then
        echo "Using cached readline $version for $arch from $cache_dir" >&2
        echo "$cache_dir"
        return 0
    fi
    
    echo "Building readline $version for $arch..." >&2
    
    # Setup architecture first
    setup_arch "$arch" || return 1
    
    # First ensure ncurses is built
    local ncurses_dir=$(build_ncurses_cached "$arch") || return 1
    
    # Download source
    download_source "readline" "$version" "https://ftp.gnu.org/gnu/readline/readline-$version.tar.gz" "readline-$version" || return 1
    
    # Create build directory
    local build_dir="/tmp/readline-build-${arch}-$$"
    mkdir -p "$build_dir" "$cache_dir"
    
    cd "$build_dir"
    tar xf /build/sources/readline-$version.tar.gz --strip-components=1 || {
        rm -rf "$build_dir"
        return 1
    }
    
    # Setup build environment using centralized flags
    local cflags=$(get_compile_flags "$arch" "libpcap")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export CXXFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    
    # Configure readline
    ./configure \
        --host=$HOST \
        --prefix="$cache_dir" \
        --disable-shared \
        --enable-static \
        --with-curses \
        CC="$CC" \
        CFLAGS="$CFLAGS -I$ncurses_dir/include" \
        LDFLAGS="$LDFLAGS -L$ncurses_dir/lib" >/dev/null 2>&1 || {
        echo "readline configure failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build readline
    make -j$(nproc) >/dev/null 2>&1 || {
        echo "readline build failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Install to cache
    make install >/dev/null 2>&1 || {
        echo "readline install failed for $arch" >&2
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    echo "readline $version built and cached for $arch at $cache_dir" >&2
    echo "$cache_dir"
    return 0
}


# Export functions
export -f build_openssl_cached
export -f build_libpcap_cached
export -f build_zlib_cached
export -f build_ncurses_cached
export -f build_readline_cached