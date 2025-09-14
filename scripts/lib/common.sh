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
    
    # STUB FUNCTION: Called by tool build scripts but does nothing
    # Toolchains are pre-downloaded in Docker image during build
    # The actual toolchain verification happens in setup_arch()
    # For actual toolchain download, see download_toolchain_impl() in download-toolchains.sh
    
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

setup_arch() {
    local arch=$1
    
    # Validate architecture
    if ! is_valid_arch "$arch"; then
        log_error "Unknown architecture: $arch"
        return 1
    fi
    
    # Get architecture info from centralized config
    local musl_name=$(get_musl_toolchain "$arch")
    local musl_cross=$(get_musl_cross "$arch")
    local glibc_name=$(get_glibc_toolchain "$arch")
    local bootlin_arch=$(get_bootlin_arch "$arch")
    local cflags_arch=$(get_arch_cflags "$arch")
    local config_arch=$(get_config_arch "$arch")
    
    local toolchain_dir
    local toolchain_type
    
    # Try musl first, then glibc if musl not available
    if [ -n "$musl_name" ]; then
        # Musl toolchain setup
        toolchain_type="musl"
        CROSS_COMPILE="${musl_name}-"
        HOST="$musl_name"
        
        # Use centralized toolchain directory structure
        toolchain_dir="/build/toolchains-musl/${musl_name}-cross"
        
    elif [ -n "$glibc_name" ]; then
        # Glibc-only toolchain setup (Bootlin toolchains)
        toolchain_type="glibc"
        CROSS_COMPILE="${glibc_name}-"
        HOST="$glibc_name"
        
        # Bootlin glibc toolchains follow pattern: /build/toolchains-glibc/<bootlin_arch>--glibc--stable-YYYY.MM-N
        if [ -n "$bootlin_arch" ]; then
            # Find the actual toolchain directory (may have date suffix)
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
    
    # Clear previous values to prevent contamination
    unset CFLAGS_ARCH CONFIG_ARCH
    
    CFLAGS_ARCH="$cflags_arch"
    CONFIG_ARCH="$config_arch"
    
    # Check if toolchain exists
    if [ ! -d "$toolchain_dir" ]; then
        log_error "Toolchain not found for $arch at $toolchain_dir ($toolchain_type)"
        log_error "Please rebuild the Docker image"
        return 1
    fi
    
    export PATH="${toolchain_dir}/bin:$PATH"
    export CROSS_COMPILE HOST CFLAGS_ARCH CONFIG_ARCH
    
    # Set additional toolchain variables
    export CC="${CROSS_COMPILE}gcc"
    export CXX="${CROSS_COMPILE}g++"
    export AR="${CROSS_COMPILE}ar"
    export RANLIB="${CROSS_COMPILE}ranlib"
    export STRIP="${CROSS_COMPILE}strip"
    export LD="${CROSS_COMPILE}ld"
    
    # Set toolchain type for build scripts that may need it
    export TOOLCHAIN_TYPE="$toolchain_type"
    
    # Verify compiler exists
    if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
        log_error "Compiler ${CROSS_COMPILE}gcc not found in PATH"
        return 1
    fi
    
    mkdir -p /build/output/$arch
    
    log_tool "$(date +%H:%M:%S)" "Setup $arch with $toolchain_type toolchain: $toolchain_dir"
    
    # Debug output when DEBUG is set
    if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
        log "[DEBUG] Toolchain Configuration for $arch:"
        log "  CROSS_COMPILE: $CROSS_COMPILE"
        log "  CC: $CC"
        log "  CXX: $CXX"
        log "  AR: $AR"
        log "  LD: $LD"
        log "  PATH: $PATH"
        log "  Toolchain Dir: $toolchain_dir"
        log "  Toolchain Type: $toolchain_type"
        which "${CROSS_COMPILE}gcc" 2>/dev/null && log "  Compiler Path: $(which ${CROSS_COMPILE}gcc)"
    fi
    
    return 0
}


get_arch_name() {
    local arch=$1
    # Use the mapping function from arch_helper
    map_arch_name "$arch"
}

download_and_extract() {
    local url=$1
    local dest_dir=$2
    local strip_components=${3:-1}
    
    local filename=$(basename "$url")
    
    source "$(dirname "${BASH_SOURCE[0]}")/build_helpers.sh"
    if ! download_source "package" "unknown" "$url"; then
        return 1
    fi
    
    log_tool "$(date +%H:%M:%S)" "Extracting $filename..."
    
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

verify_static_binary() {
    local binary=$1
    
    if [ ! -f "$binary" ]; then
        log_error "Binary not found: $binary"
        return 1
    fi
    
    # Check if it's statically linked
    if ldd "$binary" 2>/dev/null | grep -q "not a dynamic executable\|statically linked"; then
        return 0
    elif file "$binary" | grep -q "statically linked"; then
        return 0
    else
        log_warn "Binary may not be statically linked: $binary"
        return 1
    fi
}

# Setup toolchain based on libc type
# Setup toolchain for architecture
setup_toolchain_for_arch() {
    local arch=$1
    
    if [ "$LIBC_TYPE" = "glibc" ]; then
        # For glibc builds, we need to get the correct toolchain name
        # The toolchain is already in PATH from the parent build-static.sh
        # but we need to get the right prefix for the tools
        
        # Source architecture helper to get toolchain name
        if ! type get_glibc_toolchain >/dev/null 2>&1; then
            source "$SCRIPT_DIR/core/arch_helper.sh"
        fi
        
        local toolchain_name=$(get_glibc_toolchain "$arch")
        if [ -z "$toolchain_name" ]; then
            # Fallback to simple naming
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
        # For musl builds, use the standard setup_arch
        setup_arch "$arch"
        return $?
    fi
}

# Export functions
export -f setup_arch
export -f get_arch_name
export -f download_and_extract
export -f verify_static_binary
export -f setup_toolchain_for_arch