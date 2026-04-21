#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/source_versions.sh"

# ncat's own sources contain NO libpcap calls — the dependency only comes in
# via nmap's top-level configure + the shared libnsock.a (whose nsock_pcap.c is
# fully guarded by `#if HAVE_PCAP`). That means for non-Linux Zig targets where
# libpcap can't build (macOS lacks net/bpf.h via Zig's Darwin shim; Windows
# needs Npcap SDK) we can cleanly drop libpcap and still get working ncat:
# TCP/UDP relay, -e exec, --ssl, port-forwarding, broker mode all survive.
SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd,macos,windows"

build_ncat() {
    local arch=$1
    local build_dir=$(create_build_dir "ncat" "$arch")
    local TOOL_NAME="ncat"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "ncat"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1

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
            log_tool_error "ncat" "Failed to build/get libpcap for $arch"
            cleanup_build_dir "$build_dir"
            return 1
        }
    fi

    if ! download_and_extract "$NMAP_URL" "$build_dir" 0 "$NMAP_SHA512"; then
        log_tool_error "ncat" "Failed to download and extract source"
        return 1
    fi

    cd "$build_dir/nmap-${NMAP_VERSION}"

    # Zig's bundled mingw-w64 Windows SDK is case-sensitive and fully C99
    # (clang front-end, no MSVC compiler intrinsics). The nmap source tree
    # assumes the opposite, so apply two groups of Windows-only fix-ups:
    #
    # 1. Normalise mixed-case Windows SDK header names (<WINCRYPT.H>,
    #    <Winsock2.h>, <WinDef.h>, <Mswsock.h>) to lowercase.
    # 2. Replace MSVC `__intN` typedefs in nbase_winconfig.h with C99
    #    stdint equivalents — clang doesn't understand `__int8` etc. and
    #    the include chain pulls this header in on every Windows TU.
    sed -i 's|<WINCRYPT\.H>|<wincrypt.h>|'   nbase/nbase_winunix.h 2>/dev/null || true
    sed -i 's|<WinDef\.h>|<windef.h>|'       ncat/sys_wrap.h       2>/dev/null || true
    sed -i 's|<Winsock2\.h>|<winsock2.h>|'   nsock/src/nsock_internal.h \
                                             nsock/src/engine_poll.c \
                                             nsock/src/engine_iocp.c 2>/dev/null || true
    sed -i 's|"Winsock2\.h"|"winsock2.h"|'   nsock/src/netutils.c 2>/dev/null || true
    sed -i 's|<Mswsock\.h>|<mswsock.h>|'     nsock/src/engine_iocp.c 2>/dev/null || true

    if [ -f nbase/nbase_winconfig.h ]; then
        # Replace the MSVC `__intN` typedef block with a stdint.h include.
        # Also pull in <sys/time.h> — nbase detects HAVE_GETTIMEOFDAY=1 on
        # Zig's mingw-w64 (which does provide gettimeofday()), so nbase.h's
        # conditional prototype is skipped; without the POSIX header the
        # call sites (ncat_main.c, nbase_rnd.c) see an implicit
        # declaration and fail under -Wimplicit-function-declaration.
        sed -i '/^typedef unsigned __int8 uint8_t;$/,/^typedef signed __int64 int64_t;$/c\
#include <stdint.h>\
#include <sys/time.h>' nbase/nbase_winconfig.h
    fi

    # nbase_time.c unconditionally defines its own gettimeofday / sleep
    # replacements inside `#ifdef WIN32`, which clash with mingw-w64's
    # builtin declarations on Zig. Simpler fix: turn the whole
    # `#ifdef WIN32` block holding gettimeofday+sleep into
    # `#if defined(WIN32) && !defined(HAVE_GETTIMEOFDAY)` by matching the
    # exact line that opens it.
    if [ -f nbase/nbase_time.c ]; then
        python3 - <<'PYEOF'
import re
p = 'nbase/nbase_time.c'
with open(p) as f:
    src = f.read()
# Find the LAST `#ifdef WIN32` block — the one opening gettimeofday.
# Replace it with an additional HAVE_GETTIMEOFDAY guard.
pat = '#ifdef WIN32\nint gettimeofday'
repl = '#if defined(WIN32) && !defined(HAVE_GETTIMEOFDAY)\nint gettimeofday'
if pat in src:
    src = src.replace(pat, repl, 1)
    with open(p, 'w') as f:
        f.write(src)
PYEOF
    fi

    # nsock_winconfig.h hardcodes `#define HAVE_OPENSSL 1` and
    # `#define HAVE_PCAP 1` for any WIN32 build — regardless of the
    # --without-openssl / --without-libpcap we pass at configure time.
    # For the ncat (no-SSL, no-pcap) script, strip both so nsock_ssl.h /
    # nsock_pcap.h don't try to pull in their missing headers.
    if [ -f nsock/include/nsock_winconfig.h ]; then
        sed -i 's|^#define HAVE_OPENSSL 1|/* HAVE_OPENSSL intentionally undefined for non-SSL build */|' \
            nsock/include/nsock_winconfig.h
        sed -i 's|^#define HAVE_PCAP 1|/* HAVE_PCAP intentionally undefined for libpcap-less build */|' \
            nsock/include/nsock_winconfig.h
    fi


    update_config_scripts

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    local configure_args=(
        --host=$HOST
        --without-openssl
        --without-zenmap
        --without-ndiff
        --without-nmap-update
        --without-libssh2
        --without-libz
        --without-liblua
        --enable-static
    )

    # Libs that always need linking + any Windows/platform extras.
    local extra_libs="-lm"
    local make_vars=()

    if [ "$use_libpcap" = "1" ]; then
        cflags="$cflags -I$pcap_dir/include"
        ldflags="$ldflags -L$pcap_dir/lib"
        configure_args+=(--with-libpcap="$pcap_dir")
    else
        # Both nmap's top-level configure and the ncat sub-configure lack
        # a `no)` branch for --with-libpcap. Passing --without-libpcap drops
        # into the catch-all (setting CPPFLAGS="-Ino/include ...") and in
        # the top-level case also forces the bundled libpcap subdir to be
        # configured (dies on macOS for lack of net/bpf.h). Inject a `no)`
        # case that marks libpcap as "already satisfied" so the subdir is
        # skipped and no bogus -Ino paths leak into CPPFLAGS. LIBPCAP_LIBS
        # stays empty, PCAP_LIBS in the ncat Makefile stays empty, and
        # nsock_pcap.c compiles to an empty object under the #if HAVE_PCAP
        # guard. (nsock/src/configure already has a proper `no)` branch
        # upstream, so we only patch configure + ncat/configure.)
        python3 - <<'PYEOF'
import sys
for path in ('configure', 'ncat/configure'):
    with open(path) as f:
        s = f.read()
    old = "  included)\n    have_libpcap=no\n   ;;\n  *)"
    new = "  included)\n    have_libpcap=no\n   ;;\n  no)\n    have_libpcap=yes\n   ;;\n  *)"
    if old not in s:
        print(f"ncat: libpcap-case patch did not apply cleanly for {path}", file=sys.stderr)
        sys.exit(1)
    with open(path, 'w') as f:
        f.write(s.replace(old, new, 1))
PYEOF

        configure_args+=(--without-libpcap)
        make_vars+=("PCAP_LIBS=" "LIBPCAP_LIBS=")
    fi

    # Windows targets need winsock2 / ws2_32 for the BSD socket API shim and
    # iphlpapi for interface/routing lookups used by netutils.c.
    if [[ "${ZIG_TARGET:-}" == *windows* ]] || [[ "$arch" == *_windows ]]; then
        extra_libs="$extra_libs -lws2_32 -liphlpapi"
        # Zig cc -target x86_64-windows-gnu emits foo.obj (MSVC convention)
        # when invoked with just `-c foo.c`. Autoconf's AC_PROG_CC probe
        # then caches OBJEXT=obj, which cascades into the generated
        # Makefiles as `snprintf.obj`, `nbase_time.obj`, etc. — but no
        # build rule matches `.c -> .obj`, so make aborts with
        # "No rule to make target 'snprintf.obj'". Force OBJEXT=o via the
        # autoconf cache so every sub-configure (nbase, nsock, ncat) picks
        # it up. Also pre-seed:
        #   * endianness — nbase/configure aborts on the cross-compile
        #     endian probe for Windows otherwise;
        #   * ac_cv_c_undeclared_builtin_options — the top-level nmap
        #     configure runs this probe inside the
        #     `if test have_libpcap=yes` branch (which our injected `no)`
        #     case now enters), and zig cc doesn't fail on undeclared
        #     builtins the way GNU cc does, so the probe aborts the
        #     configure.  Passing an empty string lets the probe skip.
        export ac_cv_objext=o
        export ac_cv_c_bigendian=no
        export ac_cv_c_undeclared_builtin_options=""

        # zig cc -target *-windows-* defaults its `-c foo.c` output to
        # foo.obj (MSVC/PE convention). Autoconf's test-compile probes
        # don't pass -o explicitly, then look for foo.o — which never
        # exists — so every feature probe reports "no". Wrap zig cc so
        # that when invoked with `-c <file>.c` and no `-o`, we inject
        # `-o <file>.o`.
        local zig_cc_wrapper=/tmp/.zig-cc-obj-wrapper-ncat.sh
        cat > "$zig_cc_wrapper" <<'WRAP_EOF'
#!/bin/bash
# Force .o output extension for autoconf compatibility on Windows targets.
has_dash_o=0
has_dash_c=0
src=""
for a in "$@"; do
    case "$a" in
        -o|--output) has_dash_o=1 ;;
        -o*)         has_dash_o=1 ;;
        -c)          has_dash_c=1 ;;
        *.c|*.cc|*.cpp|*.cxx|*.C)
            # Track the last source file seen (autoconf passes exactly one).
            src="$a"
            ;;
    esac
done
if [ "$has_dash_c" = "1" ] && [ "$has_dash_o" = "0" ] && [ -n "$src" ]; then
    base=$(basename "$src")
    obj="${base%.*}.o"
    exec zig cc -target __ZIG_TARGET__ "$@" -o "$obj"
fi
exec zig cc -target __ZIG_TARGET__ "$@"
WRAP_EOF
        # HOST was set to the actual zig triple (e.g. x86_64-windows-gnu)
        # by setup_arch; ZIG_TARGET holds the arch alias (x86_64_windows).
        sed -i "s|__ZIG_TARGET__|${HOST}|g" "$zig_cc_wrapper"
        chmod +x "$zig_cc_wrapper"
        export CC="$zig_cc_wrapper"
        # libpcre is only consumed by nmap proper; ncat doesn't link it.
        # On Windows Zig, the bundled libpcre's configure aborts because
        # mingw-w64 lacks <sys/wait.h>. Since we only build the ncat
        # subdir after configure, pretend system pcre2 is present so the
        # top-level configure skips the libpcre sub-configure altogether.
        export ac_cv_header_pcre2_h=yes
        export ac_cv_lib_pcre2_8_pcre2_compile_8=yes
    fi

    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export LIBS="$extra_libs"

    ./configure "${configure_args[@]}" || {
        log_tool_error "ncat" "Configure failed for $arch"
        if [ "${DEBUG:-0}" = "1" ] && [ -f config.log ]; then
            echo "--- config.log tail ---" >&2
            tail -100 config.log >&2
        fi
        cleanup_build_dir "$build_dir"
        return 1
    }

    # POST-CONFIGURE patches — the files below are generated by ./configure
    # and don't exist until now.
    #
    # The nsock engine source files (engine_poll.c, engine_iocp.c) choose
    # between nsock_config.h and nsock_winconfig.h with
    # `#ifdef HAVE_CONFIG_H ... #elif WIN32 ...`. We compile with
    # -DHAVE_CONFIG_H, so on Windows they pick up nsock_config.h (which
    # lacks HAVE_POLL / HAVE_IOCP) and the whole engine body sits inside
    # a never-taken branch — empty .o files, unresolved externals at
    # link time. Force the two flags on in the autoconf-generated config.
    if [[ "${ZIG_TARGET:-}" == *windows* ]] || [[ "$arch" == *_windows ]]; then
        if [ -f nsock/include/nsock_config.h ]; then
            # Enable HAVE_POLL — engine_poll.c gates its entire body on
            # this flag, and without it the engine_poll symbol referenced
            # from nsock_engines.c is undefined at link time.
            sed -i 's|/\* #undef HAVE_POLL \*/|#define HAVE_POLL 1|' nsock/include/nsock_config.h
        fi
        # Strip HAVE_IOCP from nsock_winconfig.h too — engine_iocp.c is
        # Windows/MSVC-only code that clang (zig cc) rejects (compound-
        # literal IN6ADDR_ANY_INIT, void*/ULONG_PTR conversions). We
        # don't need IOCP for ncat's use cases: POLL + SELECT cover
        # everything the TCP/UDP relay does.
        if [ -f nsock/include/nsock_winconfig.h ]; then
            sed -i 's|^#define HAVE_IOCP 1|/* HAVE_IOCP disabled — engine_iocp.c needs MSVC */|' \
                nsock/include/nsock_winconfig.h
        fi
    fi

    # The generated sub-Makefiles (nbase/, nsock/src/) hard-code
    # `AR = ar` / `RANLIB = ranlib` at generation time and ignore the
    # environment, so pass them explicitly. Without this, nbase/nsock archives
    # are created with host GNU ar, which zig's Mach-O linker refuses to parse
    # ("unknown cpu architecture: ...").
    cd ncat

    # ncat's and nsock's Makefiles generate a dependency file via
    #   $(CC) -MM $(CPPFLAGS) $(SRCS) > makefile.dep
    # passing ALL source files in one zig cc invocation. Zig cc's -MM
    # multi-input handling silently drops the system include search
    # path for every file after the first, so every <stdint.h> /
    # <string.h> lookup fails. We don't need incremental rebuilds (each
    # build runs from a clean /tmp), so neuter both dep targets.
    for mf in Makefile ../nsock/src/Makefile; do
        [ -f "$mf" ] || continue
        if grep -q '^makefile\.dep:' "$mf"; then
            sed -i '/^makefile\.dep:/,/^$/c\
makefile.dep:\
\t@true\
' "$mf"
        fi
    done

    # Windows-specific Makefile fixup: the autotools Makefile.in is POSIX-
    # only. Upstream Ncat's Visual Studio project swaps in the Windows
    # counterparts instead; do the same for our Zig mingw-w64 build:
    #   - ncat_posix.c  -> ncat_win.c
    #   - also link ncat_exec_win.o (netexec / netrun / setenv_portable /
    #     set_pseudo_sigchld_handler live there — referenced from
    #     ncat_listen.c / ncat_connect.c)
    #   - nbase needs nbase_winunix.o added to its archive
    #     (win_stdin_start_thread is used from ncat_core.c).
    if [[ "${ZIG_TARGET:-}" == *windows* ]] || [[ "$arch" == *_windows ]]; then
        sed -i 's|\bncat_posix\.o\b|ncat_win.o|g;
                s|\bncat_posix\.c\b|ncat_win.c|g' Makefile
        sed -i 's|^\(OBJS = [^#]*\)$|\1 ncat_exec_win.o|' Makefile
        sed -i 's|^\(SRCS = [^#]*\)$|\1 ncat_exec_win.c|' Makefile
        if [ -f ../nbase/Makefile ]; then
            sed -i 's|\(${LIBOBJDIR}getaddrinfo\$U.o\)|\1 ${LIBOBJDIR}nbase_winunix$U.o|' ../nbase/Makefile
        fi
    fi
    # Zig cc's global cache races when invoked by many parallel make jobs
    # against the same target — occasional "file not found" on system
    # headers that definitely exist. Serialise for Windows/macOS Zig
    # targets; native GCC + Linux is unaffected and stays parallel.
    local make_jobs="-j$(nproc)"
    if [ "${USE_ZIG:-0}" = "1" ]; then
        case "${ZIG_TARGET:-}" in
            *windows*|*macos*|*darwin*) make_jobs="-j1" ;;
        esac
    fi
    make $make_jobs "${make_vars[@]}" AR="$AR" RANLIB="$RANLIB" LIBS="$extra_libs" || {
        log_tool_error "ncat" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }

    # MinGW appends .exe for PE targets; everywhere else produces plain `ncat`.
    local built_binary="ncat"
    [ -f "ncat.exe" ] && built_binary="ncat.exe"

    $STRIP "$built_binary" 2>/dev/null || true
    local output_path=$(get_output_path "$arch" "ncat")
    mkdir -p "$(dirname "$output_path")"
    cp "$built_binary" "$output_path"

    local size=$(get_binary_size "$output_path")
    log_tool "ncat" "Built successfully for $arch ($size)"

    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_ncat "$arch"
