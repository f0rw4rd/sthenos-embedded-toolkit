#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"

DROPBEAR_VERSION="${DROPBEAR_VERSION:-2022.83}"
DROPBEAR_URL="https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2"
DROPBEAR_SHA512="c63afa615d64b0c8c5e739c758eb8ae277ecc36a4223b766bf562702de69910904cbc3ea98d22989df478ae419e1f81057fe1ee09616c80cb859f58f44175422"

build_dropbear() {
    local arch=$1
    local build_dir=$(create_build_dir "dropbear" "$arch")
    local TOOL_NAME="dropbear"
    
    if check_binary_exists "$arch" "dropbear"; then
        return 0
    fi
    
    
    setup_toolchain_for_arch "$arch" || return 1
    
    if ! download_and_extract "$DROPBEAR_URL" "$build_dir" 0 "$DROPBEAR_SHA512"; then
        log_tool_error "dropbear" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/dropbear-${DROPBEAR_VERSION}"
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    CFLAGS="${CFLAGS:-} $cflags" \
    LDFLAGS="${LDFLAGS:-} $ldflags" \
    ./configure \
        --host=$HOST \
        --disable-zlib \
        --disable-syslog \
        --disable-lastlog \
        --disable-utmp \
        --disable-utmpx \
        --disable-wtmp \
        --disable-wtmpx \
        --disable-pututline \
        --disable-pututxline \
        --enable-static \
        || {
        log_tool_error "dropbear" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    # For m68k_coldfire, disable password auth since crypt() is not available
    if [ "$arch" = "m68k_coldfire" ]; then
        cat > localoptions.h << 'EOF'
/* Dropbear custom options for embedded systems */

/* Disable password auth for m68k_coldfire (no crypt()) */
#define DROPBEAR_SVR_PASSWORD_AUTH 0
#define DROPBEAR_CLI_PASSWORD_AUTH 0

/* Algorithms - disable weaker ones to save space */
EOF
    else
        cat > localoptions.h << 'EOF'
/* Dropbear custom options for embedded systems */

/* Algorithms - disable weaker ones to save space */
EOF
    fi
    
    make -j$(nproc) PROGRAMS="dropbear dbclient dropbearkey scp" STATIC=1 || {
        log_tool_error "dropbear" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP dropbear
    $STRIP dbclient
    $STRIP dropbearkey
    $STRIP scp
    
    cp dropbear "/build/output/$arch/dropbear"
    
    cp dbclient "/build/output/$arch/dbclient"
    cp dropbearkey "/build/output/$arch/dropbearkey"
    cp scp "/build/output/$arch/scp"
    
    local size=$(get_binary_size dropbear)
    log_tool "dropbear" "Built successfully for $arch"
    log_tool "dropbear" "  - dropbear (SSH server): $size"
    log_tool "dropbear" "  - dbclient (SSH client): $(get_binary_size dbclient)"
    log_tool "dropbear" "  - dropbearkey (key gen): $(get_binary_size dropbearkey)"
    log_tool "dropbear" "  - scp (secure copy): $(get_binary_size scp)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

validate_args 1 "Usage: $0 <architecture>" "$@"

arch=$1
build_dropbear "$arch"
