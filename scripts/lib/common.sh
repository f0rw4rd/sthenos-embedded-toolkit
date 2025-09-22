#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
export BASE_DIR

STATIC_SCRIPT_DIR="$BASE_DIR/scripts/static"
export STATIC_SCRIPT_DIR

COMMON_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$COMMON_DIR/logging.sh"
source "$COMMON_DIR/core/compile_flags.sh"
source "$COMMON_DIR/build_helpers.sh"
source "$COMMON_DIR/core/architectures.sh"
source "$COMMON_DIR/core/arch_helper.sh"

download_toolchain() {
    local arch=$1
    
    
    return 0
}

declare -A TOOL_SCRIPTS=(
    ["strace"]="$SCRIPT_DIR/../static/tools/build-strace.sh"
    ["busybox"]="$SCRIPT_DIR/../static/tools/build-busybox.sh"
    ["busybox_nodrop"]="$SCRIPT_DIR/../static/tools/build-busybox-nodrop.sh"
    ["bash"]="$SCRIPT_DIR/../static/tools/build-bash.sh"
    ["socat"]="$SCRIPT_DIR/../static/tools/build-socat.sh"
    ["socat-ssl"]="$SCRIPT_DIR/../static/tools/build-socat-ssl.sh"
    ["tcpdump"]="$SCRIPT_DIR/../static/tools/build-tcpdump.sh"
    ["ncat"]="$SCRIPT_DIR/../static/tools/build-ncat.sh"
    ["ncat-ssl"]="$SCRIPT_DIR/../static/tools/build-ncat-ssl.sh"
    ["gdbserver"]="$SCRIPT_DIR/../static/tools/build-gdbserver.sh"
    ["nmap"]="$SCRIPT_DIR/../static/tools/build-nmap.sh"
    ["dropbear"]="$SCRIPT_DIR/../static/tools/build-dropbear.sh"
    ["ltrace"]="$SCRIPT_DIR/../static/tools/build-ltrace.sh"
    ["ply"]="$SCRIPT_DIR/../static/tools/build-ply.sh"
    ["can-utils"]="$SCRIPT_DIR/../static/tools/build-can-utils.sh"
    ["shell"]="$SCRIPT_DIR/../static/tools/build-shell-static.sh"
    ["custom"]="$SCRIPT_DIR/../static/tools/build-custom.sh"
    ["custom-glibc"]="$SCRIPT_DIR/../static/tools/build-custom-glibc.sh"
)

declare -A SHARED_LIB_SCRIPTS=(
    ["libshells"]="$SCRIPT_DIR/../shared/tools/build-shell-libs.sh"
    ["libtlsnoverify"]="$SCRIPT_DIR/../shared/tools/build-tls-noverify.sh"
    ["libdesock"]="$SCRIPT_DIR/../shared/tools/build-libdesock.sh"
    ["libcustom"]="$SCRIPT_DIR/../shared/tools/build-custom-lib.sh"
)

setup_arch() {
    local arch=$1
    
    if ! is_valid_arch "$arch"; then
        log_error "Unknown architecture: $arch"
        return 1
    fi
    
    local musl_name=$(get_musl_toolchain "$arch")
    local musl_cross=$(get_musl_cross "$arch")
    local glibc_name=$(get_glibc_toolchain "$arch")
    local bootlin_arch=$(get_bootlin_arch "$arch")
    local cflags_arch=$(get_arch_cflags "$arch")
    local config_arch=$(get_config_arch "$arch")
    
    local toolchain_dir
    local toolchain_type
    
    if [ -n "$musl_name" ]; then
        toolchain_type="musl"
        CROSS_COMPILE="${musl_name}-"
        HOST="$musl_name"
        
        toolchain_dir="/build/toolchains-musl/${musl_name}-cross"
        
    elif [ -n "$glibc_name" ]; then
        toolchain_type="glibc"
        CROSS_COMPILE="${glibc_name}-"
        HOST="$glibc_name"
        
        if [ -n "$bootlin_arch" ]; then
            local toolchain_pattern="/build/toolchains-glibc/${bootlin_arch}--glibc--stable-*"
            toolchain_dir=$(find /build/toolchains-glibc -maxdepth 1 -type d -name "${bootlin_arch}--glibc--stable-*" | head -1)
            
            if [ -z "$toolchain_dir" ]; then
                log_error "No Bootlin glibc toolchain found matching pattern: ${bootlin_arch}--glibc--stable-*"
                return 1
            fi
        else
            log_error "No bootlin_arch defined for glibc-only architecture: $arch"
            return 1
        fi
        
    else
        log_error "No toolchain defined for architecture: $arch (neither musl nor glibc)"
        return 1
    fi
    
    unset CFLAGS_ARCH CONFIG_ARCH
    
    CFLAGS_ARCH="$cflags_arch"
    CONFIG_ARCH="$config_arch"
    
    if [ ! -d "$toolchain_dir" ]; then
        log_error "Toolchain not found for $arch at $toolchain_dir ($toolchain_type)"
        log_error "Please rebuild the Docker image"
        return 1
    fi
    
    export PATH="${toolchain_dir}/bin:$PATH"
    export CROSS_COMPILE HOST CFLAGS_ARCH CONFIG_ARCH
    
    export CC="${CROSS_COMPILE}gcc"
    export CXX="${CROSS_COMPILE}g++"
    export AR="${CROSS_COMPILE}ar"
    export RANLIB="${CROSS_COMPILE}ranlib"
    export STRIP="${CROSS_COMPILE}strip"
    export LD="${CROSS_COMPILE}ld"
    
    export TOOLCHAIN_TYPE="$toolchain_type"
    
    if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
        log_error "Compiler ${CROSS_COMPILE}gcc not found in PATH"
        return 1
    fi
    
    mkdir -p /build/output/$arch
    
    log_tool "$arch" "Setup with $toolchain_type toolchain: $toolchain_dir" >&2
    
    if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
        log "[DEBUG] Toolchain Configuration for $arch:" >&2
        log "  CROSS_COMPILE: $CROSS_COMPILE" >&2
        log "  CC: $CC" >&2
        log "  CXX: $CXX" >&2
        log "  AR: $AR" >&2
        log "  LD: $LD" >&2
        log "  PATH: $PATH" >&2
        log "  Toolchain Dir: $toolchain_dir" >&2
        log "  Toolchain Type: $toolchain_type" >&2
        which "${CROSS_COMPILE}gcc" >/dev/null 2>&1 && log "  Compiler Path: $(which ${CROSS_COMPILE}gcc)" >&2
    fi
    
    return 0
}



download_and_extract() {
    local url=$1
    local dest_dir=$2
    local strip_components=${3:-1}
    local expected_sha512=$4
    
    local filename=$(basename "$url")
    
    source "$(dirname "${BASH_SOURCE[0]}")/build_helpers.sh"
    if ! download_source "package" "unknown" "$url" "$expected_sha512"; then
        return 1
    fi
    
    log_tool "extract" "Extracting $filename..."
    
    local source_file="/build/sources/$filename"
    
    case "$filename" in
        *.tar.gz|*.tgz)
            tar xzf "$source_file" -C "$dest_dir" --strip-components=$strip_components
            ;;
        *.tar.bz2)
            tar xjf "$source_file" -C "$dest_dir" --strip-components=$strip_components
            ;;
        *.tar.xz)
            tar xJf "$source_file" -C "$dest_dir" --strip-components=$strip_components
            ;;
        *)
            log_error "Unknown archive format: $filename"
            return 1
            ;;
    esac
    
    return 0
}


setup_toolchain_for_arch() {
    local arch=$1
    
    if [ "$LIBC_TYPE" = "glibc" ]; then
        
        if ! type get_glibc_toolchain >/dev/null 2>&1; then
            source "$SCRIPT_DIR/core/arch_helper.sh"
        fi
        
        local toolchain_name=$(get_glibc_toolchain "$arch")
        if [ -z "$toolchain_name" ]; then
            toolchain_name="$arch-linux"
        fi
        
        CC="${toolchain_name}-gcc"
        CXX="${toolchain_name}-g++"
        LD="${toolchain_name}-ld"
        AR="${toolchain_name}-ar"
        RANLIB="${toolchain_name}-ranlib"
        STRIP="${toolchain_name}-strip"
        NM="${toolchain_name}-nm"
        OBJCOPY="${toolchain_name}-objcopy"
        OBJDUMP="${toolchain_name}-objdump"
        HOST="${toolchain_name}"
        CROSS_COMPILE="${toolchain_name}-"
        export CC CXX LD AR RANLIB STRIP NM OBJCOPY OBJDUMP HOST CROSS_COMPILE
        return 0
    else
        setup_arch "$arch"
        return $?
    fi
}

export -f setup_arch
export -f download_and_extract
export -f setup_toolchain_for_arch
