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

build_socat_ssl() {
    local arch=$1
    local build_dir=$(create_build_dir "socat-ssl" "$arch")
    local TOOL_NAME="socat-ssl"
    
    local output_path=$(get_output_path "$arch" "socat-ssl")
    if [ -f "$output_path" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(get_binary_size "$output_path")
        log "[$arch] Already built: $output_path ($size)"
        return 0
    fi
    
    
    setup_toolchain_for_arch "$arch" || return 1
    
    local ssl_dir=$(build_openssl_cached "$arch") || {
        log_tool_error "socat-ssl" "Failed to build/get OpenSSL for $arch"
        return 1
    }
    
    local readline_dir=$(build_readline_cached "$arch") || {
        log_tool_error "socat-ssl" "Failed to build/get readline for $arch"
        return 1
    }
    
    local ncurses_dir=$(build_ncurses_cached "$arch") || {
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

    if [[ "$arch" == "x86_64" || "$arch" == "aarch64" || "$arch" == "aarch64_be" || "$arch" == "riscv64" || "$arch" == "mips64" || "$arch" == "mips64"* || "$arch" == "ppc64"* || "$arch" == "s390x" ]]; then
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
