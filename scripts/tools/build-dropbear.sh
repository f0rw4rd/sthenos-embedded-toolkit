#!/bin/bash
# Build script for dropbear SSH server/client
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

DROPBEAR_VERSION="${DROPBEAR_VERSION:-2022.83}"
DROPBEAR_URL="https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2"

build_dropbear() {
    local arch=$1
    local build_dir="/tmp/dropbear-build-${arch}-$$"
    local TOOL_NAME="dropbear"
    
    # Check if binary already exists
    if check_binary_exists "$arch" "dropbear"; then
        return 0
    fi
    
    echo "[dropbear] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "dropbear" "$DROPBEAR_VERSION" "$DROPBEAR_URL" || return 1
    
    # Create build directory and extract
    mkdir -p "$build_dir"
    cd "$build_dir"
    tar xf /build/sources/dropbear-${DROPBEAR_VERSION}.tar.bz2
    cd dropbear-${DROPBEAR_VERSION}
    
    # Get build flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    # Configure dropbear
    # --disable-zlib: removes zlib dependency (slight performance hit but smaller)
    # --disable-syslog: smaller binary, logs to stderr instead
    # --disable-lastlog: don't update lastlog
    # --disable-utmp: don't update utmp/wtmp
    # --disable-utmpx: don't update utmpx/wtmpx
    # --disable-wtmp: don't update wtmp
    # --disable-wtmpx: don't update wtmpx
    CFLAGS="$cflags" \
    LDFLAGS="$ldflags" \
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
        echo "[dropbear] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Enable/disable features in localoptions.h
    cat > localoptions.h << 'EOF'
/* Dropbear custom options for embedded systems */

/* Algorithms - disable weaker ones to save space */
#define DROPBEAR_AES128 1
#define DROPBEAR_AES256 1
#define DROPBEAR_3DES 0
#define DROPBEAR_ENABLE_CTR_MODE 1
#define DROPBEAR_ENABLE_CBC_MODE 0

/* Enable only strong MACs */
#define DROPBEAR_SHA1_96_HMAC 0
#define DROPBEAR_SHA2_256_HMAC 1
#define DROPBEAR_SHA2_512_HMAC 1

/* Features to disable for smaller binary */
#define DROPBEAR_X11FWD 0
#define DROPBEAR_SVR_AGENTFWD 0
#define DROPBEAR_CLI_AGENTFWD 0
#define DROPBEAR_SVR_LOCALTCPFWD 1
#define DROPBEAR_CLI_LOCALTCPFWD 1
#define DROPBEAR_SVR_REMOTETCPFWD 1
#define DROPBEAR_CLI_REMOTETCPFWD 1

/* Enable SCP */
#define DROPBEAR_SCP 1

/* Use smaller DH groups */
#define DROPBEAR_DH_GROUP14_SHA256 1
#define DROPBEAR_DH_GROUP14_SHA1 0
#define DROPBEAR_DH_GROUP16 0

/* Reduce key sizes for embedded */
#define DROPBEAR_DEFAULT_RSA_SIZE 2048
#define DROPBEAR_DSS 0  /* DSS is deprecated */

/* Misc space savers */
#define DROPBEAR_SMALL_CODE 1
EOF
    
    # Build dropbear
    # PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp"
    make -j$(nproc) PROGRAMS="dropbear dbclient dropbearkey scp" STATIC=1 || {
        echo "[dropbear] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Strip and copy binaries
    $STRIP dropbear
    $STRIP dbclient
    $STRIP dropbearkey
    $STRIP scp
    
    # Copy main dropbear SSH server
    cp dropbear "/build/output/$arch/dropbear"
    
    # Create symlinks for other tools (or copy them)
    cp dbclient "/build/output/$arch/dbclient"
    cp dropbearkey "/build/output/$arch/dropbearkey"
    cp scp "/build/output/$arch/scp"
    
    # Create ssh symlink to dbclient for compatibility
    cd "/build/output/$arch"
    ln -sf dbclient ssh
    
    # Get sizes
    local size=$(ls -lh dropbear | awk '{print $5}')
    echo "[dropbear] Built successfully for $arch"
    echo "  - dropbear (SSH server): $size"
    echo "  - dbclient (SSH client): $(ls -lh dbclient | awk '{print $5}')"
    echo "  - dropbearkey (key gen): $(ls -lh dropbearkey | awk '{print $5}')"
    echo "  - scp (secure copy): $(ls -lh scp | awk '{print $5}')"
    
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
build_dropbear "$arch"