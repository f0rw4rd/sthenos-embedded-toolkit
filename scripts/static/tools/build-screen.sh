#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/tools.sh"

TOOL_NAME="screen"
SUPPORTED_OS="linux,android"  # Not verified on BSD/macOS; re-enable once tested
SCREEN_VERSION="${SCREEN_VERSION:-5.0.1}"
SCREEN_URL="https://ftp.gnu.org/gnu/screen/screen-${SCREEN_VERSION}.tar.gz"
SCREEN_SHA512="9bda35689d73a816515df30f50101531cf3af8906cb47f086d1f97c464cb729f4ee6e3d4aca220acc4c6125d81e923ee3a11fb3a85fe6994002bf1e0f3cc46fb"

configure_screen() {
    local arch=$1
    local ncurses_dir=$2
    local crypt_stub_dir=$3

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    export CFLAGS="$cflags -I$ncurses_dir/include -I$ncurses_dir/include/ncurses"
    export LDFLAGS="$ldflags -L$ncurses_dir/lib"

    # Bootlin glibc sysroots (sparc64, nios2) ship no libcrypt/crypt.h.
    # glibc 2.38+ moved crypt() into libxcrypt, which Buildroot doesn't bundle.
    # Screen's --disable-pam path still calls crypt() for :password auth. We
    # pre-seed the configure cache to skip the fatal AC_SEARCH_LIBS probe, and
    # (when needed) link against a tiny stub so :password degrades gracefully
    # instead of blocking the build. On other archs (musl, or glibc with
    # libcrypt) the real crypt() in libc is found and used normally.
    # Append the crypt stub to LIBS (not LDFLAGS): screen's Makefile places
    # $(LIBS) after all object files, so the archive is seen when the crypt
    # symbol is still unresolved. Wrap in --no-as-needed to survive any
    # earlier --as-needed in the link line.
    local extra_libs=""
    if [ -n "$crypt_stub_dir" ]; then
        extra_libs="-Wl,--no-as-needed -L$crypt_stub_dir -lcrypt_stub -Wl,--as-needed"
    fi

    ./configure \
        --host=$HOST \
        --enable-static \
        --disable-shared \
        --disable-pam \
        --disable-socket-dir \
        --disable-telnet \
        --disable-use-locale \
        --with-sys-screenrc=/etc/screenrc \
        ac_cv_search_crypt="none required" \
        LIBS="$extra_libs"
}

# Build a minimal libcrypt_stub.a providing a crypt() that always returns "*"
# (no valid hash), so screen's password check never authenticates. Used only
# for arches whose glibc sysroot lacks libcrypt (Buildroot sparc64/nios2).
build_crypt_stub() {
    local stub_dir=$1

    mkdir -p "$stub_dir"
    cat > "$stub_dir/crypt_stub.c" <<'EOF'
/* Stub for glibc sysroots without libxcrypt: returns a non-matching hash. */
char *crypt(const char *key, const char *salt) {
    (void)key; (void)salt;
    static char out[2] = "*";
    return out;
}
EOF
    "$CC" -c -Os -fPIC "$stub_dir/crypt_stub.c" -o "$stub_dir/crypt_stub.o" || return 1
    "$AR" rcs "$stub_dir/libcrypt_stub.a" "$stub_dir/crypt_stub.o" || return 1
    return 0
}

build_screen_impl() {
    local arch=$1

    parallel_make
}

install_screen() {
    local arch=$1

    install_binary "screen" "$arch" "screen" "$TOOL_NAME"
}

build_screen() {
    local arch=$1

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "$TOOL_NAME"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Unknown architecture: $arch"
        return 1
    }

    download_toolchain "$arch" || return 1

    # Build ncurses dependency (screen requires tgetent from ncurses/termcap)
    local ncurses_dir
    ncurses_dir=$(build_ncurses_cached "$arch") || {
        log_tool_error "$TOOL_NAME" "Failed to build ncurses dependency for $arch"
        return 1
    }

    local build_dir
    build_dir=$(create_build_dir "$TOOL_NAME" "$arch")

    trap "cleanup_build_dir '$build_dir'" EXIT

    if ! download_and_extract "$SCREEN_URL" "$build_dir" 0 "$SCREEN_SHA512"; then
        log_tool_error "$TOOL_NAME" "Failed to download and extract source"
        return 1
    fi

    cd "$build_dir/${TOOL_NAME}-${SCREEN_VERSION}"

    # Detect sysroots missing libcrypt (Buildroot glibc for sparc64/nios2).
    # If crypt() isn't linkable, build a local stub archive to satisfy the
    # password-auth references that screen emits when PAM is disabled.
    local crypt_stub_dir=""
    if [ "${USE_ZIG:-0}" != "1" ]; then
        local probe_dir="$build_dir/crypt-probe"
        mkdir -p "$probe_dir"
        echo 'extern char *crypt(const char *, const char *); int main(void){return crypt("","")==0;}' \
            > "$probe_dir/probe.c"
        if ! "$CC" "$probe_dir/probe.c" -o "$probe_dir/probe" 2>/dev/null; then
            crypt_stub_dir="$build_dir/crypt-stub"
            build_crypt_stub "$crypt_stub_dir" || {
                log_tool_error "$TOOL_NAME" "Failed to build crypt stub for $arch"
                return 1
            }
        fi
        rm -rf "$probe_dir"
    fi

    configure_screen "$arch" "$ncurses_dir" "$crypt_stub_dir" || {
        log_tool_error "$TOOL_NAME" "Configure failed for $arch"
        return 1
    }

    build_screen_impl "$arch" || {
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    }

    install_screen "$arch" || {
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

    build_screen "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
