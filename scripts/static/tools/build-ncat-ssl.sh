#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/source_versions.sh"

# Same libpcap story as build-ncat.sh: ncat's SSL build is identical except
# it links OpenSSL (already cross-builds for macOS/Windows via Zig). All the
# Windows fix-ups below mirror build-ncat.sh — kept inline so each script is
# self-contained. See build-ncat.sh for the rationale of each patch.
SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd,macos,windows"

build_ncat_ssl() {
    local arch=$1
    local build_dir=$(create_build_dir "ncat-ssl" "$arch")
    local TOOL_NAME="ncat-ssl"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "ncat-ssl"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1

    # `local x=$(cmd)` always returns 0 (the local builtin masks the subshell exit).
    # Declare, then assign, so dependency failures actually abort this build.
    local ssl_dir
    ssl_dir=$(build_openssl_cached "$arch") || {
        log_tool_error "ncat-ssl" "Failed to build/get OpenSSL for $arch"
        return 1
    }

    # Decide whether to build against libpcap. Zig non-Linux targets go
    # pcap-less; everything else keeps the original behaviour.
    local use_libpcap=1
    if [ "${USE_ZIG:-0}" = "1" ]; then
        case "${ZIG_TARGET:-}" in
            *linux*|*android*) use_libpcap=1 ;;
            *)                 use_libpcap=0 ;;
        esac
    fi

    local pcap_dir=""
    if [ "$use_libpcap" = "1" ]; then
        pcap_dir=$(build_libpcap_cached "$arch") || {
            log_tool_error "ncat-ssl" "Failed to build/get libpcap for $arch"
            cleanup_build_dir "$build_dir"
            return 1
        }
    fi

    if ! download_and_extract "$NMAP_URL" "$build_dir" 0 "$NMAP_SHA512"; then
        log_tool_error "ncat-ssl" "Failed to download and extract source"
        return 1
    fi

    cd "$build_dir/nmap-${NMAP_VERSION}"

    # ---- Windows case-sensitive / MSVC-ism source fix-ups (see build-ncat.sh) ----
    sed -i 's|<WINCRYPT\.H>|<wincrypt.h>|'   nbase/nbase_winunix.h 2>/dev/null || true
    sed -i 's|<WinDef\.h>|<windef.h>|'       ncat/sys_wrap.h       2>/dev/null || true
    sed -i 's|<Winsock2\.h>|<winsock2.h>|'   nsock/src/nsock_internal.h \
                                             nsock/src/engine_poll.c \
                                             nsock/src/engine_iocp.c 2>/dev/null || true
    sed -i 's|"Winsock2\.h"|"winsock2.h"|'   nsock/src/netutils.c 2>/dev/null || true
    sed -i 's|<Mswsock\.h>|<mswsock.h>|'     nsock/src/engine_iocp.c 2>/dev/null || true

    if [ -f nbase/nbase_winconfig.h ]; then
        sed -i '/^typedef unsigned __int8 uint8_t;$/,/^typedef signed __int64 int64_t;$/c\
#include <stdint.h>\
#include <sys/time.h>' nbase/nbase_winconfig.h
    fi

    if [ -f nbase/nbase_time.c ]; then
        python3 - <<'PYEOF'
p = 'nbase/nbase_time.c'
with open(p) as f:
    src = f.read()
pat = '#ifdef WIN32\nint gettimeofday'
repl = '#if defined(WIN32) && !defined(HAVE_GETTIMEOFDAY)\nint gettimeofday'
if pat in src:
    with open(p, 'w') as f:
        f.write(src.replace(pat, repl, 1))
PYEOF
    fi

    # ncat-ssl *does* want HAVE_OPENSSL; only strip HAVE_PCAP from
    # nsock_winconfig.h (pcap is disabled for Zig non-Linux targets).
    if [ -f nsock/include/nsock_winconfig.h ]; then
        sed -i 's|^#define HAVE_PCAP 1|/* HAVE_PCAP intentionally undefined for libpcap-less build */|' \
            nsock/include/nsock_winconfig.h
    fi

    # On Windows, ncat_ssl.c pulls in <openssl/applink.c> — a shim OpenSSL
    # ships for applications linking against its DLL variant. Our OpenSSL
    # build is fully static (no DLL), so the shim is both unneeded and
    # absent from the install tree; comment the include out.
    if [ -f ncat/ncat_ssl.c ]; then
        sed -i 's|^#include <openssl/applink\.c>|/* applink.c omitted: static OpenSSL */|' \
            ncat/ncat_ssl.c
    fi

    update_config_scripts

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    cflags="$cflags -I$ssl_dir/include"
    ldflags="$ldflags -L$ssl_dir/lib"

    local configure_args=(
        --host=$HOST
        --with-openssl=$ssl_dir
        --without-zenmap
        --without-ndiff
        --without-nmap-update
        --without-libssh2
        --without-libz
        --without-liblua
        --enable-static
    )

    local extra_libs="-lm"
    local make_vars=()

    if [ "$use_libpcap" = "1" ]; then
        cflags="$cflags -I$pcap_dir/include"
        ldflags="$ldflags -L$pcap_dir/lib"
        configure_args+=(--with-libpcap="$pcap_dir")
    else
        python3 - <<'PYEOF'
import sys
for path in ('configure', 'ncat/configure'):
    with open(path) as f:
        s = f.read()
    old = "  included)\n    have_libpcap=no\n   ;;\n  *)"
    new = "  included)\n    have_libpcap=no\n   ;;\n  no)\n    have_libpcap=yes\n   ;;\n  *)"
    if old not in s:
        print(f"ncat-ssl: libpcap-case patch did not apply cleanly for {path}", file=sys.stderr)
        sys.exit(1)
    with open(path, 'w') as f:
        f.write(s.replace(old, new, 1))
PYEOF

        configure_args+=(--without-libpcap)
        make_vars+=("PCAP_LIBS=" "LIBPCAP_LIBS=")
    fi

    if [[ "${ZIG_TARGET:-}" == *windows* ]] || [[ "$arch" == *_windows ]]; then
        # Windows system libraries. crypt32 + bcrypt are needed by OpenSSL's
        # Windows random/cert store backends. ws2_32 + iphlpapi cover sockets
        # + interface enumeration for netutils.c.
        extra_libs="$extra_libs -lws2_32 -liphlpapi -lcrypt32 -lbcrypt"
        export ac_cv_objext=o
        export ac_cv_c_bigendian=no
        export ac_cv_c_undeclared_builtin_options=""

        local zig_cc_wrapper=/tmp/.zig-cc-obj-wrapper-ncat-ssl.sh
        cat > "$zig_cc_wrapper" <<'WRAP_EOF'
#!/bin/bash
has_dash_o=0
has_dash_c=0
src=""
for a in "$@"; do
    case "$a" in
        -o|--output) has_dash_o=1 ;;
        -o*)         has_dash_o=1 ;;
        -c)          has_dash_c=1 ;;
        *.c|*.cc|*.cpp|*.cxx|*.C) src="$a" ;;
    esac
done
if [ "$has_dash_c" = "1" ] && [ "$has_dash_o" = "0" ] && [ -n "$src" ]; then
    base=$(basename "$src")
    obj="${base%.*}.o"
    exec zig cc -target __ZIG_TARGET__ "$@" -o "$obj"
fi
exec zig cc -target __ZIG_TARGET__ "$@"
WRAP_EOF
        sed -i "s|__ZIG_TARGET__|${HOST}|g" "$zig_cc_wrapper"
        chmod +x "$zig_cc_wrapper"
        export CC="$zig_cc_wrapper"

        export ac_cv_header_pcre2_h=yes
        export ac_cv_lib_pcre2_8_pcre2_compile_8=yes
    fi

    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export LIBS="$extra_libs"

    ./configure "${configure_args[@]}" || {
        log_tool_error "ncat-ssl" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }

    # ---- Post-configure fix-ups (see build-ncat.sh) ----
    if [[ "${ZIG_TARGET:-}" == *windows* ]] || [[ "$arch" == *_windows ]]; then
        if [ -f nsock/include/nsock_config.h ]; then
            sed -i 's|/\* #undef HAVE_POLL \*/|#define HAVE_POLL 1|' nsock/include/nsock_config.h
        fi
        if [ -f nsock/include/nsock_winconfig.h ]; then
            sed -i 's|^#define HAVE_IOCP 1|/* HAVE_IOCP disabled — engine_iocp.c needs MSVC */|' \
                nsock/include/nsock_winconfig.h
        fi
    fi

    cd ncat

    for mf in Makefile ../nsock/src/Makefile; do
        [ -f "$mf" ] || continue
        if grep -q '^makefile\.dep:' "$mf"; then
            sed -i '/^makefile\.dep:/,/^$/c\
makefile.dep:\
\t@true\
' "$mf"
        fi
    done

    if [[ "${ZIG_TARGET:-}" == *windows* ]] || [[ "$arch" == *_windows ]]; then
        sed -i 's|\bncat_posix\.o\b|ncat_win.o|g;
                s|\bncat_posix\.c\b|ncat_win.c|g' Makefile
        sed -i 's|^\(OBJS = [^#]*\)$|\1 ncat_exec_win.o|' Makefile
        sed -i 's|^\(SRCS = [^#]*\)$|\1 ncat_exec_win.c|' Makefile
        if [ -f ../nbase/Makefile ]; then
            sed -i 's|\(${LIBOBJDIR}getaddrinfo\$U.o\)|\1 ${LIBOBJDIR}nbase_winunix$U.o|' ../nbase/Makefile
        fi
    fi

    local make_jobs="-j$(nproc)"
    if [ "${USE_ZIG:-0}" = "1" ]; then
        case "${ZIG_TARGET:-}" in
            *windows*|*macos*|*darwin*) make_jobs="-j1" ;;
        esac
    fi

    make $make_jobs "${make_vars[@]}" AR="$AR" RANLIB="$RANLIB" LIBS="$extra_libs" || {
        log_tool_error "ncat-ssl" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }

    local built_binary="ncat"
    [ -f "ncat.exe" ] && built_binary="ncat.exe"

    $STRIP "$built_binary" 2>/dev/null || true
    local output_path=$(get_output_path "$arch" "ncat-ssl")
    mkdir -p "$(dirname "$output_path")"
    cp "$built_binary" "$output_path"

    if ! strings "$output_path" | grep -q "OpenSSL"; then
        log_tool_warn "ncat-ssl" "Warning: Binary may not have SSL support"
    fi

    cleanup_build_dir "$build_dir"

    local size=$(get_binary_size "$output_path")
    log_tool "ncat-ssl" "Built successfully for $arch ($size)"

    return 0
}

if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f build_ncat_ssl
else
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <architecture>"
        echo "Example: $0 x86_64"
        exit 1
    fi

    build_ncat_ssl "$1"
fi
