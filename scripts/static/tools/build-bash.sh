#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

BASH_VER="${BASH_VER:-5.2.15}"
BASH_URL="https://ftp.gnu.org/gnu/bash/bash-5.2.15.tar.gz"

build_bash() {
    local arch=$1
    local build_dir=$(create_build_dir "bash" "$arch")
    local TOOL_NAME="bash"
    
    if check_binary_exists "$arch" "bash"; then
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    download_source "bash" "$BASH_VER" "$BASH_URL" || return 1
    
    cp -a /build/sources/bash-${BASH_VER} "$build_dir/"
    cd "$build_dir/bash-${BASH_VER}"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    ac_cv_func_strtoimax=no \
    ./configure \
        --host=$HOST \
        --enable-static-link \
        --without-bash-malloc \
        --disable-nls \
        --disable-rpath \
        --disable-net-redirections \
        --disable-progcomp \
        --disable-help-builtin || {
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    make -j$(nproc) || {
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP bash
    cp bash "/build/output/$arch/bash"
    
    local size=$(get_binary_size "/build/output/$arch/bash")
    log_tool "bash" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

validate_args 1 "Usage: $0 <architecture>" "$@"

arch=$1
build_bash "$arch"