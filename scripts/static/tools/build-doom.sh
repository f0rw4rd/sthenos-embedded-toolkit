#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/core/os_targets.sh"
source "$LIB_DIR/build_helpers.sh"

TOOL_NAME="doom"
BINARY_NAME="doom-ascii"
# doom-ascii renders to a text terminal (stdout + termios/Windows-console input),
# so it runs over serial/SSH. Tested-building OS set below (WASI is excluded: no
# terminal model, and Zig ships no wasi libc for non-wasm arches).
SUPPORTED_OS="linux,android,windows,macos,maccatalyst,freebsd,openbsd,netbsd"

# Pinned to a specific commit (no upstream release tags) so the SHA512 is stable.
DOOM_VERSION="0.3.1"
DOOM_COMMIT="b5188d7c9c4da6c81264a7803e8725ac3df2cfea"
DOOM_URL="https://github.com/wojciech-graj/doom-ascii/archive/${DOOM_COMMIT}.tar.gz"
DOOM_SHA512="3a24d0c9ee734c9cbf95cff095d4ae5dba34cc5f903a39cdf0a12f99ff523c8d854c37c07bf04e2aa91270852a55c3de81682f14740e72d30a6e5e776324ac4b"

# Optional: DOOM_EMBED_WAD=1 bakes the freely-distributable shareware IWAD
# (Doom v1.9, verified) into the binary, so the result is a single ~2.4MB
# self-contained executable that needs no WAD file on disk.
DOOM_WAD_URL="https://github.com/Akbar30Bill/DOOM_wads/raw/master/doom1.wad"
DOOM_WAD_SHA512="6c2798417f0a0feaa1ab8777edb54e821eb336acfe953d62214dac46dd62429f58da97f9d13beac5fdaf944e70a07c60c96af9a885a0daf38eff1619cde71c2a"

# Resolve the target OS from the arch name (e.g. x86_64_freebsd -> freebsd).
doom_target_os() {
    local arch=$1
    if [ "${USE_ZIG:-0}" != "1" ]; then
        echo "linux"
        return
    fi
    local os
    for os in "${ALL_OS_TARGETS[@]}"; do
        [[ "$arch" == *"_${os}" ]] && { echo "$os"; return; }
    done
    echo "linux"
}

# doomgeneric_ascii.c selects its Windows console path on OS_WINDOWS (not the
# compiler's _WIN32), so Windows needs it defined explicitly. Everything POSIX
# uses the portable termios path. We deliberately do NOT define __MACOSX__ on
# Darwin: that path pulls in <CoreFoundation/CFUserNotification.h> (a GUI error
# dialog) which Zig's macOS SDK doesn't ship and a terminal build doesn't want —
# macOS instead uses the same generic POSIX path as the BSDs.
doom_platform_defines() {
    case "$1" in
        windows)
            echo "-DOS_WINDOWS" ;;
        linux|android)
            echo "-DNORMALUNIX -DLINUX" ;;
        *)
            echo "-DNORMALUNIX" ;;  # macOS, BSDs, illumos, etc: POSIX/termios path
    esac
}

apply_doom_patches() {
    [ -d /build/patches/doom ] || return 0
    local p
    for p in /build/patches/doom/*.patch; do
        [ -f "$p" ] || continue
        log_tool "$TOOL_NAME" "Applying $(basename "$p")..."
        patch -p1 < "$p" || return 1
    done
}

# DOOM_EMBED_WAD=1: bake the shareware IWAD into the binary. The WAD is stored
# raw-DEFLATE compressed and inflated at startup via puff (bundled, no deps),
# then served through fmemopen (see the w_file_stdc.c patch). Runs from the
# extracted source root (src/ present).
doom_embed_setup() {
    local asset_dir="$STATIC_SCRIPT_DIR/tools/doom-embed"
    if ! command -v python3 >/dev/null 2>&1; then
        log_tool_error "$TOOL_NAME" "DOOM_EMBED_WAD requires python3 (not found)"
        return 1
    fi
    download_source "doom1-wad" "1.9" "$DOOM_WAD_URL" "$DOOM_WAD_SHA512" || return 1
    cp "$asset_dir/puff.c" "$asset_dir/puff.h" \
       "$asset_dir/doom_embed.c" "$asset_dir/doom_embed.h" src/ || return 1
    python3 "$asset_dir/gen_wad_header.py" /build/sources/doom1.wad src/doom_wad_deflated.h >&2 || return 1

    # Route the WAD loader's fopen through the embedded buffer...
    perl -0pi -e 's/#include "w_file.h"\n/#include "w_file.h"\n#include <string.h>\n#include "doom_embed.h"\n/' src/w_file_stdc.c
    perl -0pi -e 's/    fstream = fopen\(path, "rb"\);\n/#ifdef DOOM_EMBED_WAD\n    if (!strcmp(path, DOOM_EMBED_SENTINEL)) {\n        unsigned int _elen = 0;\n        const unsigned char *_edata = doom_embed_get_wad(\&_elen);\n        fstream = (_edata != NULL) ? fmemopen((void *)_edata, _elen, "rb") : NULL;\n    } else {\n        fstream = fopen(path, "rb");\n    }\n#else\n    fstream = fopen(path, "rb");\n#endif\n/' src/w_file_stdc.c
    # ...and fall back to the embedded IWAD when none is found on disk.
    perl -0pi -e 's/#include "d_iwad.h"\n/#include "d_iwad.h"\n#include "doom_embed.h"\n/' src/d_iwad.c
    perl -0pi -e 's/(result = SearchDirectoryForIWAD\(iwad_dirs\[i\], mask, mission\);\n        \}\n    \}\n\n)    return result;/$1#ifdef DOOM_EMBED_WAD\n    if (result == NULL) { result = strdup(DOOM_EMBED_SENTINEL); *mission = doom; }\n#endif\n    return result;/' src/d_iwad.c

    # perl -pi is silent on a missed pattern; verify the critical edits landed.
    if ! grep -q fmemopen src/w_file_stdc.c || ! grep -q DOOM_EMBED_SENTINEL src/d_iwad.c; then
        log_tool_error "$TOOL_NAME" "embed patch failed to apply (upstream source layout changed?)"
        return 1
    fi
    log_tool "$TOOL_NAME" "Embedded shareware doom1.wad (DEFLATE-compressed)"
    return 0
}

build_doom() {
    local arch=$1

    # Embed (self-contained WAD) is the default; set DOOM_EMBED_WAD=0 for the
    # smaller bring-your-own-WAD engine.
    local embed="${DOOM_EMBED_WAD:-1}"
    # The embed loader uses fmemopen (POSIX), which the Windows CRT lacks — fall
    # back to the external-WAD build there so Windows still compiles.
    case "$arch" in
        *windows*)
            if [ "$embed" = "1" ]; then
                log_tool_warn "$TOOL_NAME" "embed unsupported on Windows (no fmemopen); building external-WAD doom-ascii"
                embed=0
            fi
            ;;
    esac
    # Self-contained (WAD baked in) installs as "doom"; the bring-your-own-WAD
    # engine installs as "doom-ascii" so both can coexist in the same output dir.
    local dest_name="$BINARY_NAME"
    [ "$embed" = "1" ] && dest_name="doom"

    check_tool_support "$SUPPORTED_OS" "$TOOL_NAME" || return 1
    check_binary_exists "$arch" "$dest_name" && return 0

    setup_toolchain_for_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Failed to setup toolchain for $arch"
        return 1
    }

    local build_dir
    build_dir=$(create_build_dir "$TOOL_NAME" "$arch")
    trap "cleanup_build_dir '$build_dir'" EXIT

    if ! download_and_extract "$DOOM_URL" "$build_dir" 1 "$DOOM_SHA512"; then
        log_tool_error "$TOOL_NAME" "Failed to download and extract source"
        return 1
    fi

    cd "$build_dir"

    apply_doom_patches || {
        log_tool_error "$TOOL_NAME" "Patch failed for $arch"
        return 1
    }

    if [ "$embed" = "1" ]; then
        doom_embed_setup || {
            log_tool_error "$TOOL_NAME" "Embed setup failed for $arch"
            return 1
        }
    fi

    local target_os
    target_os=$(doom_target_os "$arch")

    local cflags ldflags
    cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    ldflags=$(get_link_flags "$arch" "static")

    cflags="$cflags $(doom_platform_defines "$target_os")"
    cflags="$cflags -D_DEFAULT_SOURCE -DVERSION=$DOOM_VERSION -std=gnu99 -Isrc"
    # Vanilla Doom is 1993 C: tolerate legacy constructs that modern GCC/Clang
    # (esp. Zig's clang) rejects by default.
    cflags="$cflags -fcommon -Wno-error=implicit-function-declaration -Wno-error=int-conversion"
    [ "$embed" = "1" ] && cflags="$cflags -DDOOM_EMBED_WAD"

    if [ "${USE_ZIG:-0}" = "0" ]; then
        export_cross_compiler "$CROSS_COMPILE"
    fi

    log_tool "$TOOL_NAME" "Compiling doom-ascii for $arch (os=$target_os)..."
    # Compile+link the whole source set in one go (bypasses upstream's recursive
    # Makefile, which hardcodes musl-gcc/mingw and forces -flto).
    if ! $CC $cflags src/*.c -o "$BINARY_NAME" $ldflags -lm; then
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    fi

    if ! install_binary "$BINARY_NAME" "$arch" "$dest_name" "$TOOL_NAME"; then
        return 1
    fi

    trap - EXIT
    cleanup_build_dir "$build_dir"
    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>" "$@"
    local arch=$1
    mkdir -p "/build/output/$arch"
    build_doom "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
