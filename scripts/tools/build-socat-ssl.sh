#!/bin/bash
# Build script for socat with SSL support
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/dependencies.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

SOCAT_VERSION="${SOCAT_VERSION:-1.7.4.4}"
SOCAT_URL="http://www.dest-unreach.org/socat/download/socat-${SOCAT_VERSION}.tar.gz"

build_socat_ssl() {
    local arch=$1
    local build_dir="/tmp/socat-ssl-build-${arch}-$$"
    local TOOL_NAME="socat-ssl"
    
    # Check if binary already exists
    if check_binary_exists "$arch" "socat-ssl"; then
        return 0
    fi
    
    echo "[socat-ssl] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Get OpenSSL from cache
    local ssl_dir=$(build_openssl_cached "$arch") || {
        echo "[socat-ssl] Failed to build/get OpenSSL for $arch"
        return 1
    }
    
    # Get readline from cache
    local readline_dir=$(build_readline_cached "$arch") || {
        echo "[socat-ssl] Failed to build/get readline for $arch"
        return 1
    }
    
    # Get ncurses from cache (dependency of readline)
    local ncurses_dir=$(build_ncurses_cached "$arch") || {
        echo "[socat-ssl] Failed to build/get ncurses for $arch"
        return 1
    }
    
    # Trim any whitespace/newlines from the directory paths
    ssl_dir=$(echo "$ssl_dir" | tr -d '\n' | xargs)
    readline_dir=$(echo "$readline_dir" | tr -d '\n' | xargs)
    ncurses_dir=$(echo "$ncurses_dir" | tr -d '\n' | xargs)
    
    # Download source
    download_source "socat" "$SOCAT_VERSION" "$SOCAT_URL" || return 1
    
    # Create build directory and extract
    mkdir -p "$build_dir"
    cd "$build_dir"
    tar xf /build/sources/socat-${SOCAT_VERSION}.tar.gz
    cd socat-${SOCAT_VERSION}
    
    # Create config.cache with cross-compilation values
    cat > config.cache << EOF
ac_cv_func_setenv=yes
ac_cv_func_unsetenv=yes
ac_cv_func_snprintf_c99=yes
ac_cv_have_z_modifier=yes
sc_cv_sys_crdly_shift=9
sc_cv_sys_tabdly_shift=11
sc_cv_sys_csize_shift=4
ac_cv_sizeof_char=1
ac_cv_sizeof_short=2
ac_cv_sizeof_int=4
ac_cv_sizeof_long=4
ac_cv_sizeof_long_long=8
ac_cv_sizeof_off_t=8
ac_cv_sizeof_off64_t=8
ac_cv_sizeof_size_t=4
ac_cv_sizeof_time_t=4
ac_cv_sizeof_void_p=4
ac_cv_type_uint8_t=yes
ac_cv_type_uint16_t=yes
ac_cv_type_uint32_t=yes
ac_cv_type_uint64_t=yes
ac_cv_c_bigendian=no
sc_cv_type_longlong=yes
sc_cv_type_off64_t=yes
sc_cv_type_socklen_t=yes
sc_cv_type_stat64=yes
EOF

    # Adjust for 64-bit architectures
    if [[ "$arch" == "x86_64" || "$arch" == "aarch64" || "$arch" == "aarch64_be" || "$arch" == "riscv64" || "$arch" == "mips64" || "$arch" == "mips64"* || "$arch" == "ppc64"* || "$arch" == "powerpc64"* || "$arch" == "s390x" ]]; then
        sed -i 's/ac_cv_sizeof_long=4/ac_cv_sizeof_long=8/' config.cache
        sed -i 's/ac_cv_sizeof_size_t=4/ac_cv_sizeof_size_t=8/' config.cache
        sed -i 's/ac_cv_sizeof_time_t=4/ac_cv_sizeof_time_t=8/' config.cache
        sed -i 's/ac_cv_sizeof_void_p=4/ac_cv_sizeof_void_p=8/' config.cache
    fi
    
    # Adjust for big endian architectures
    if [[ "$arch" == *"be"* ]]; then
        sed -i 's/ac_cv_c_bigendian=no/ac_cv_c_bigendian=yes/' config.cache
    fi
    
    # Configure socat with centralized build flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    # Debug output
    echo "[socat-ssl] CFLAGS: $cflags -I$ssl_dir/include -I$readline_dir/include -I$ncurses_dir/include"
    echo "[socat-ssl] LDFLAGS: $ldflags -L$ssl_dir/lib -L$readline_dir/lib -L$ncurses_dir/lib"
    echo "[socat-ssl] CC: $CC"
    echo "[socat-ssl] HOST: $HOST"
    
    CFLAGS="$cflags -I$ssl_dir/include -I$readline_dir/include -I$ncurses_dir/include" \
    LDFLAGS="$ldflags -L$ssl_dir/lib -L$readline_dir/lib -L$ncurses_dir/lib" \
    LIBS="-lssl -lcrypto -lreadline -lncurses" \
    ./configure \
        --host=$HOST \
        --cache-file=config.cache \
        --enable-openssl \
        --disable-libwrap \
        --disable-fips || {
        echo "[socat-ssl] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Build socat
    make V=1 -j$(nproc) || {
        echo "[socat-ssl] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Strip and copy binary
    $STRIP socat
    cp socat "/build/output/$arch/socat-ssl"
    
    # Get size
    local size=$(ls -lh "/build/output/$arch/socat-ssl" | awk '{print $5}')
    echo "[socat-ssl] Built successfully for $arch ($size)"
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    return 0
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    echo "Architectures: arm32v5le arm32v5lehf arm32v7le arm32v7lehf mips32v2le mips32v2be ppc32be ix86le x86_64 aarch64 mips64le ppc64le"
    exit 1
fi

arch=$1
build_socat_ssl "$arch"