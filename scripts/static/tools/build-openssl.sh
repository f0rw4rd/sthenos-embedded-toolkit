#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/tools.sh"

TOOL_NAME="openssl"
SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd,macos,windows"
OPENSSL_VERSION="${OPENSSL_VERSION:-1.1.1w}"
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_SHA512="b4c625fe56a4e690b57b6a011a225ad0cb3af54bd8fb67af77b5eceac55cc7191291d96a660c5b568a08a2fbf62b4612818e7cca1bb95b2b6b4fc649b0552b6d"

get_openssl_target() {
    local arch=$1
    local openssl_target

    # Zig cross-platform targets — map to OpenSSL's OS-specific Configure names
    case $arch in
        x86_64_macos)       echo "darwin64-x86_64-cc";      return ;;
        aarch64_macos)      echo "darwin64-arm64-cc";       return ;;
        x86_64_freebsd)     echo "BSD-x86_64";              return ;;
        aarch64_freebsd)    echo "BSD-generic64";           return ;;
        riscv64_freebsd)    echo "BSD-generic64";           return ;;
        x86_64_openbsd)     echo "BSD-x86_64";              return ;;
        aarch64_openbsd)    echo "BSD-generic64";           return ;;
        x86_64_netbsd)      echo "BSD-x86_64";              return ;;
        aarch64_netbsd)     echo "BSD-generic64";           return ;;
        x86_64_windows)     echo "mingw64";                 return ;;
        aarch64_windows)    echo "mingw64";                 return ;;
    esac

    case $arch in
        x86_64) openssl_target="linux-x86_64" ;;
        ix86le|i486) openssl_target="linux-x86" ;;
        armv7m|armv7r) openssl_target="linux-generic32" ;;
        arm*)
            if [[ "$arch" == *"v7"* ]]; then
                openssl_target="linux-armv4"
            else
                openssl_target="linux-generic32"
            fi
            ;;
        aarch64*) openssl_target="linux-aarch64" ;;
        mips64n32*) openssl_target="linux-mips64" ;;
        mips64*) openssl_target="linux64-mips64" ;;
        mips*) openssl_target="linux-mips32" ;;
        ppc64*) openssl_target="linux-ppc64le" ;;
        ppc32*) openssl_target="linux-ppc" ;;
        riscv64) openssl_target="linux-generic64" ;;
        riscv32) openssl_target="linux-generic32" ;;
        s390x) openssl_target="linux64-s390x" ;;
        sh*) openssl_target="linux-generic32" ;;
        *) openssl_target="linux-generic32" ;;
    esac

    echo "$openssl_target"
}

configure_openssl_cli() {
    local arch=$1
    local zlib_dir=$2

    local openssl_cflags=$(echo "$CFLAGS" | sed 's/-fno-pie//g; s/-no-pie//g')
    openssl_cflags="$openssl_cflags -fPIC"

    local openssl_target=$(get_openssl_target "$arch")

    # Disable assembly for Thumb-only ARM profiles and aarch64/thumb Windows
    # (which use the mingw64 Configure target expecting x86_64 asm).
    local openssl_asm_opt=""
    case "$arch" in
        armv7m|armv7r) openssl_asm_opt="no-asm" ;;
        aarch64_windows|thumb_windows) openssl_asm_opt="no-asm" ;;
    esac

    # riscv32 lacks legacy __NR_io_getevents syscall
    local openssl_afalg_opt=""
    case "$arch" in
        riscv32) openssl_afalg_opt="no-afalgeng" ;;
    esac

    # Save and unset CROSS_COMPILE -- OpenSSL's Configure uses it to prefix
    # compiler names, which conflicts with our already-set CC.
    local _saved_cross_compile="${CROSS_COMPILE:-}"
    unset CROSS_COMPILE

    # Darwin/BSD via Zig can't do fully static binaries
    local openssl_static_opt="-static"
    if ! platform_supports_static; then
        openssl_static_opt=""
    fi

    # devcrypto engine needs Linux /dev/crypto headers
    local openssl_devcrypto_opt=""
    case "$arch" in
        *_macos|*_freebsd|*_openbsd|*_netbsd|*_dragonfly)
            openssl_devcrypto_opt="no-devcryptoeng"
            ;;
    esac

    ./Configure \
        --prefix="/tmp/openssl-install-$$" \
        --openssldir="/tmp/openssl-install-$$/ssl" \
        "$openssl_target" \
        no-shared \
        no-dso \
        --with-zlib-include="$zlib_dir/include" \
        --with-zlib-lib="$zlib_dir/lib" \
        zlib \
        no-async \
        no-comp \
        no-ec2m \
        no-sm2 \
        no-sm4 \
        $openssl_devcrypto_opt \
        $openssl_asm_opt \
        $openssl_afalg_opt \
        enable-ssl3 \
        enable-ssl3-method \
        enable-weak-ssl-ciphers \
        $openssl_static_opt \
        -ffunction-sections -fdata-sections \
        $openssl_cflags
    local _configure_rc=$?

    # Restore CROSS_COMPILE
    if [ -n "$_saved_cross_compile" ]; then
        export CROSS_COMPILE="$_saved_cross_compile"
    fi

    return $_configure_rc
}

build_openssl_cli() {
    local arch=$1

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "$TOOL_NAME"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1
    download_toolchain "$arch" || return 1

    # Build zlib dependency
    local zlib_dir=$(build_zlib_cached "$arch") || {
        log_tool_error "$TOOL_NAME" "Failed to build zlib for $arch"
        return 1
    }

    local build_dir
    build_dir=$(create_build_dir "$TOOL_NAME" "$arch")
    trap "cleanup_build_dir '$build_dir'" EXIT

    if ! download_and_extract "$OPENSSL_URL" "$build_dir" 0 "$OPENSSL_SHA512"; then
        log_tool_error "$TOOL_NAME" "Failed to download and extract source"
        return 1
    fi

    cd "$build_dir/openssl-${OPENSSL_VERSION}"

    # musl's strerror_r is POSIX-signature (returns int) even under _GNU_SOURCE.
    # OpenSSL 1.1.1w's crypto/o_str.c hardcodes the GNU signature when
    # _GNU_SOURCE is defined, causing -Wint-conversion errors with strict GCC
    # (e.g., loongarch64-unknown-linux-musl-cross 13.x). Patch the GNU branch
    # guard to also require glibc -- musl defines neither __GLIBC__ nor the
    # char*-returning strerror_r, so it falls through to the POSIX/XSI branch.
    if [ "${LIBC_TYPE:-}" = "musl" ] || [[ "${CROSS_COMPILE:-}" == *musl* ]]; then
        sed -i 's|^#elif defined(_GNU_SOURCE)$|#elif defined(_GNU_SOURCE) \&\& defined(__GLIBC__)|' crypto/o_str.c
    fi

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    if [ "${USE_ZIG:-0}" != "1" ]; then
        export_cross_compiler "$CROSS_COMPILE"
    fi

    log_tool "$TOOL_NAME" "Configuring OpenSSL for $arch..."
    configure_openssl_cli "$arch" "$zlib_dir" || {
        log_tool_error "$TOOL_NAME" "Configure failed for $arch"
        return 1
    }

    log_tool "$TOOL_NAME" "Building OpenSSL for $arch..."
    parallel_make depend || {
        log_tool_error "$TOOL_NAME" "make depend failed for $arch"
        return 1
    }
    parallel_make || {
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    }

    # The openssl CLI binary is at apps/openssl (or apps/openssl.exe on Windows)
    local openssl_bin="apps/openssl"
    [ -f "apps/openssl.exe" ] && openssl_bin="apps/openssl.exe"
    install_binary "$openssl_bin" "$arch" "openssl" "$TOOL_NAME" || {
        log_tool_error "$TOOL_NAME" "Install failed for $arch"
        return 1
    }

    trap - EXIT
    cleanup_build_dir "$build_dir"
    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>" "$@"

    local arch=$1
    mkdir -p "/build/output/$arch"

    build_openssl_cli "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
