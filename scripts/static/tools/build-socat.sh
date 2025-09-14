#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source common.sh which loads all required libraries
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"

SOCAT_VERSION="${SOCAT_VERSION:-1.7.4.4}"
SOCAT_URL="http://www.dest-unreach.org/socat/download/socat-${SOCAT_VERSION}.tar.gz"

build_socat() {
    local arch=$1
    local build_dir=$(create_build_dir "socat" "$arch")
    local TOOL_NAME="socat"
    
    if check_binary_exists "$arch" "socat"; then
        return 0
    fi
    
    
    setup_toolchain_for_arch "$arch" || return 1
    
    download_source "socat" "$SOCAT_VERSION" "$SOCAT_URL" || return 1
    
    cd "$build_dir"
    tar xf /build/sources/socat-${SOCAT_VERSION}.tar.gz
    cd socat-${SOCAT_VERSION}
    
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

    if [[ "$arch" == "x86_64" || "$arch" == "aarch64" || "$arch" == *"64"* ]]; then
        sed -i 's/ac_cv_sizeof_long=4/ac_cv_sizeof_long=8/' config.cache
        sed -i 's/ac_cv_sizeof_size_t=4/ac_cv_sizeof_size_t=8/' config.cache
        sed -i 's/ac_cv_sizeof_time_t=4/ac_cv_sizeof_time_t=8/' config.cache
        sed -i 's/ac_cv_sizeof_void_p=4/ac_cv_sizeof_void_p=8/' config.cache
    fi
    
    if [[ "$arch" == *"be"* ]]; then
        sed -i 's/ac_cv_c_bigendian=no/ac_cv_c_bigendian=yes/' config.cache
    fi
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
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
    cp socat "/build/output/$arch/socat"
    
    local size=$(ls -lh "/build/output/$arch/socat" | awk '{print $5}')
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