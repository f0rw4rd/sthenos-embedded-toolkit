#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/tools.sh"

TOOL_NAME="mtd-utils"
SUPPORTED_OS="linux,android"
MTD_UTILS_VERSION="${MTD_UTILS_VERSION:-2.3.1}"
MTD_UTILS_URL="https://github.com/sigma-star/mtd-utils/archive/refs/tags/v${MTD_UTILS_VERSION}.tar.gz"
MTD_UTILS_SHA512="b6b9b7bf3e14aa04928fda1b5597f5a80196806e4dd6610339328eac0ebed1b1191a64321166563e76b4918f660ec6bbba75ee8ec88334ee94dd1023cde5fbb9"

build_mtd_utils() {
    local arch=$1
    local TOOL_NAME="mtd-utils"
    local mtd_dir=$(get_output_dir "$arch" "mtd-utils")

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then return 1; fi

    if [ -d "$mtd_dir" ] && [ "$(ls -A "$mtd_dir" 2>/dev/null)" ]; then
        local tool_count=$(ls -1 "$mtd_dir" | wc -l)
        log_tool "mtd-utils" "Already built for $arch ($tool_count tools in ${mtd_dir##*/})"
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1

    # Build zlib dependency
    source "$LIB_DIR/dependency_builder.sh"
    local zlib_dir
    zlib_dir=$(build_zlib_cached "$arch") || {
        log_tool_error "mtd-utils" "Failed to build zlib dependency"
        return 1
    }

    local build_dir=$(create_build_dir "mtd-utils" "$arch")
    trap "cleanup_build_dir '$build_dir'" EXIT

    cd "$build_dir"

    log_tool "mtd-utils" "Building mtd-utils for $arch..."

    if ! download_and_extract "$MTD_UTILS_URL" "$build_dir" 0 "$MTD_UTILS_SHA512"; then
        log_tool_error "mtd-utils" "Failed to download and extract source"
        return 1
    fi

    cd "$build_dir/mtd-utils-${MTD_UTILS_VERSION}"

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    export CFLAGS="$cflags -I$zlib_dir/include"
    export LDFLAGS="$ldflags -L$zlib_dir/lib"

    # Only set cross compiler for GCC builds; Zig CC is already configured by setup_arch
    if [ "${USE_ZIG:-0}" != "1" ]; then
        export_cross_compiler "$CROSS_COMPILE"
    fi

    # Generate configure script (GitHub archive has no pre-generated configure).
    # Strip toolchain from PATH: Buildroot glibc toolchains ship broken autoreconf
    # wrappers with a hardcoded Perl @INC pointing at /builds/buildroot.org/...
    # which does not exist. Use only system autotools for this step.
    log_tool "mtd-utils" "Running autoreconf..."
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        /usr/bin/autoreconf --force --install --symlink || {
        log_tool_error "mtd-utils" "autoreconf failed for $arch"
        return 1
    }

    # Update config.sub/config.guess for cross-compilation support
    update_config_scripts .

    # Configure with minimal dependencies:
    # - zlib: yes (for compression support)
    # - lzo/zstd/selinux/crypto/xattr: no (minimize deps)
    # - ubifs: no (needs lzo and uuid)
    # - jffs: no (needs lzo/zlib combo through mkfs.jffs2)
    # - tests: no
    # - lsmtd: no (optional)
    # - ubihealthd: no (optional daemon)
    standard_configure "$arch" "$TOOL_NAME" \
        --with-zlib \
        --without-lzo \
        --without-zstd \
        --without-selinux \
        --without-crypto \
        --without-xattr \
        --without-ubifs \
        --without-jffs \
        --without-tests \
        --without-lsmtd \
        --disable-ubihealthd \
        --disable-unit-tests \
        ZLIB_CFLAGS="-I$zlib_dir/include" \
        ZLIB_LIBS="-L$zlib_dir/lib -lz" || {
        log_tool_error "mtd-utils" "Configure failed for $arch"
        return 1
    }

    make -j$(nproc) || {
        log_tool_error "mtd-utils" "Build failed for $arch"
        return 1
    }

    # Install binaries into output directory
    mkdir -p "$mtd_dir"

    # Core NAND utilities
    local nand_tools="nanddump nandwrite nandtest nftldump nftl_format nandflipbits"
    # Core UBI utilities
    local ubi_tools="ubiupdatevol ubimkvol ubirmvol ubicrc32 ubinfo ubiattach ubidetach ubinize ubiformat ubirename ubirsvol ubiblock ubiscan mtdinfo"
    # Misc flash utilities
    local misc_tools="flash_erase flash_lock flash_unlock flashcp mtdpart flash_otp_info flash_otp_dump flash_otp_lock flash_otp_erase flash_otp_write ftl_format ftl_check doc_loadbios docfdisk mtd_debug serve_image recv_image"

    local installed_count=0
    for tool in $nand_tools $ubi_tools $misc_tools; do
        if [ -f "$tool" ]; then
            $STRIP "$tool" 2>/dev/null || true
            cp "$tool" "$mtd_dir/"
            installed_count=$((installed_count + 1))
        fi
    done

    if [ $installed_count -eq 0 ]; then
        log_tool_error "mtd-utils" "No binaries were built for $arch"
        return 1
    fi

    log_tool "mtd-utils" "Built successfully for $arch ($installed_count tools installed in mtd-utils/)"

    trap - EXIT
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_mtd_utils "$arch"
