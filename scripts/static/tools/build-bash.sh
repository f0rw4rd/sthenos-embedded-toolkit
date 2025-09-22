#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

BASH_VER="${BASH_VER:-5.2.15}"
BASH_URL="https://ftp.gnu.org/gnu/bash/bash-5.2.15.tar.gz"
BASH_SHA512="08a67f6da4af7a75ff2b2d5a9eb8fc46d8c6e9ae80ccaf73b51736d6609916861b1f3fced938ce3ea16d014edb324e1a3d8e03f4917f68dc56ffb665316f26c7"

build_bash() {
    local arch=$1
    local build_dir=$(create_build_dir "bash" "$arch")
    local TOOL_NAME="bash"
    
    if check_binary_exists "$arch" "bash"; then
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    if ! download_and_extract "$BASH_URL" "$build_dir" 0 "$BASH_SHA512"; then
        log_tool_error "bash" "Failed to download and extract source"
        return 1
    fi
    
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
