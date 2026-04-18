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
    ["curl"]="$SCRIPT_DIR/../static/tools/build-curl.sh"
    ["curl-full"]="$SCRIPT_DIR/../static/tools/build-curl-full.sh"
    ["microsocks"]="$SCRIPT_DIR/../static/tools/build-microsocks.sh"
    ["tinyproxy"]="$SCRIPT_DIR/../static/tools/build-tinyproxy.sh"
    ["i2c-tools"]="$SCRIPT_DIR/../static/tools/build-i2c-tools.sh"
    ["spidev-tools"]="$SCRIPT_DIR/../static/tools/build-spidev-tools.sh"
    ["openssl"]="$SCRIPT_DIR/../static/tools/build-openssl.sh"
    ["screen"]="$SCRIPT_DIR/../static/tools/build-screen.sh"
    ["mtd-utils"]="$SCRIPT_DIR/../static/tools/build-mtd-utils.sh"
    ["uboot-envtools"]="$SCRIPT_DIR/../static/tools/build-uboot-envtools.sh"
)

declare -A SHARED_LIB_SCRIPTS=(
    ["libshells"]="$SCRIPT_DIR/../shared/tools/build-shell-libs.sh"
    ["libtlsnoverify"]="$SCRIPT_DIR/../shared/tools/build-tls-noverify.sh"
    ["libdesock"]="$SCRIPT_DIR/../shared/tools/build-libdesock.sh"
    ["libcustom"]="$SCRIPT_DIR/../shared/tools/build-custom-lib.sh"
)

setup_arch() {
    local arch=$1

    if is_zig_target "$arch"; then
        # Zig CC mode
        export USE_ZIG=1
        export ZIG_TARGET="$arch"

        # Convert to proper Zig target triple
        # x86_64_windows -> x86_64-windows
        # aarch64_macos -> aarch64-macos
        # We only replace the LAST underscore(s) with dashes
        local parts=(${arch//_/ })
        local arch_part="${parts[0]}"
        if [[ "${parts[0]}" == "x86" ]] && [[ "${parts[1]}" == "64" ]]; then
            arch_part="x86_64"
            parts=("${parts[@]:2}")  # Remove first two elements
        else
            parts=("${parts[@]:1}")  # Remove first element
        fi

        # Join remaining parts with dashes (OS and optional ABI)
        local os_abi=$(IFS=-; echo "${parts[*]}")

        # Source OS targets if available for ABI defaults
        if [ -f "/build/scripts/lib/core/os_targets.sh" ]; then
            source "/build/scripts/lib/core/os_targets.sh"

            # Get OS name (first part of os_abi)
            local os_name="${os_abi%%-*}"

            # Get default ABI if not specified
            if [ "$os_abi" = "$os_name" ]; then
                local default_abi=$(get_default_abi "$os_name")
                if [ -n "$default_abi" ]; then
                    os_abi="${os_name}-${default_abi}"
                fi
            fi
        else
            # Fallback: For Windows, default to gnu ABI if not specified
            if [[ "$os_abi" == "windows" ]]; then
                os_abi="windows-gnu"
            fi
        fi

        local zig_triple="${arch_part}-${os_abi}"

        # Validate that Zig has libc support for this target
        if ! zig_has_libc "$zig_triple"; then
            log_error "Zig 0.16.0 does not have libc support for target '$zig_triple' (arch: $arch)"
            log_error "Without bundled libc, system headers (stdio.h, etc.) are unavailable."
            log_error "Run 'zig targets' and check the .libc section for supported targets."
            return 1
        fi

        # Set up Zig as compiler
        export CC="zig cc -target $zig_triple"
        export CXX="zig c++ -target $zig_triple"
        export AR="zig ar"
        # GNU libtool invokes `ranlib -t` to touch the archive; Zig's ranlib
        # rejects the -t flag and aborts `make install` mid-flow (breaking
        # header installation for libssh2 on OpenBSD etc.). Wrap it to
        # silently accept and ignore flags we don't recognise.
        local zig_ranlib_wrapper=/tmp/.zig-ranlib-wrapper.sh
        cat > "$zig_ranlib_wrapper" << 'WRAPPER_EOF'
#!/bin/bash
# Filter out flags zig ranlib doesn't support
args=()
for a in "$@"; do
    case "$a" in
        -t|-v|-D|-U) ;;  # GNU ranlib flags that Zig doesn't understand; ignore
        *) args+=("$a") ;;
    esac
done
exec zig ranlib "${args[@]}"
WRAPPER_EOF
        chmod +x "$zig_ranlib_wrapper"
        export RANLIB="$zig_ranlib_wrapper"

        # Windows builds (OpenSSL, curl, etc) invoke `windres` to compile .rc
        # resource files. Zig doesn't ship windres, and MinGW's is not in the
        # Docker image. The resource data is purely cosmetic (icons, version
        # info) and not required for static linking, so ship a stub that
        # produces an empty object file satisfying the Makefile dependency.
        if [[ "$zig_triple" == *"windows"* ]]; then
            local zig_windres_wrapper=/tmp/.zig-windres-wrapper.sh
            # Embed the current triple so the stub object matches the target arch
            cat > "$zig_windres_wrapper" << WINDRES_EOF
#!/bin/bash
# Emit an empty COFF object at the -o path matching the Zig target arch.
output=""
prev=""
for a in "\$@"; do
    if [ "\$prev" = "-o" ] || [ "\$prev" = "--output" ]; then
        output="\$a"
    fi
    prev="\$a"
done
if [ -z "\$output" ]; then
    output="\${!#}"
fi
echo 'int _windres_stub = 0;' | zig cc -target ${zig_triple} -c -x c -o "\$output" - 2>/dev/null
WINDRES_EOF
            chmod +x "$zig_windres_wrapper"
            # Expose as `windres` on PATH ahead of anything else
            local wrapper_bin_dir=/tmp/.zig-wrapper-bin
            mkdir -p "$wrapper_bin_dir"
            ln -sf "$zig_windres_wrapper" "$wrapper_bin_dir/windres"
            export PATH="$wrapper_bin_dir:$PATH"
        fi
        # Pick a strip that understands the target's object format.
        # Host GNU `strip` cannot parse Mach-O (macOS) or handle some BSD
        # variants. `zig objcopy --strip-all` is unimplemented in Zig 0.16 and
        # truncates its output file before failing, so we always strip to a
        # temp path and only replace the original on non-empty success — if
        # stripping fails, the binary stays unstripped rather than zeroed.
        # The linker's -Wl,--strip-all already handles most cases anyway.
        local zig_strip_wrapper=/tmp/.zig-strip-wrapper.sh
        cat > "$zig_strip_wrapper" << 'WRAPPER_EOF'
#!/bin/bash
for f in "$@"; do
    [ -f "$f" ] || continue
    tmp="${f}.stripped.$$"
    if zig objcopy --strip-all "$f" "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        mv "$tmp" "$f"
    else
        rm -f "$tmp"
    fi
done
WRAPPER_EOF
        chmod +x "$zig_strip_wrapper"
        export STRIP="$zig_strip_wrapper"
        export LD="zig cc -target $zig_triple"

        # Set CROSS_COMPILE to empty (not needed with Zig)
        export CROSS_COMPILE=""
        export HOST="$zig_triple"

        # Use full arch name for output directory (includes OS)
        mkdir -p /build/output/$arch

        # Set dependency prefix for cache separation
        export DEPS_PREFIX="zig"

        log_tool "$arch" "Using Zig CC for cross-compilation (target: $zig_triple)" >&2

        if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
            log "[DEBUG] Zig Configuration for $arch:" >&2
            log "  ZIG_TARGET: $zig_triple" >&2
            log "  CC: $CC" >&2
            log "  CXX: $CXX" >&2
            log "  AR: $AR" >&2
            log "  LD: $LD" >&2
            log "  DEPS_PREFIX: $DEPS_PREFIX" >&2
        fi

        return 0
    fi

    # Traditional GCC/toolchain mode
    export USE_ZIG=0
    export DEPS_PREFIX="gcc"

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

    # When LIBC_TYPE is explicitly glibc, skip musl even if available
    if [ "${LIBC_TYPE:-}" != "glibc" ] && [ -n "$musl_name" ]; then
        toolchain_type="musl"
        CROSS_COMPILE="${musl_name}-"
        HOST="$musl_name"

        toolchain_dir="/build/toolchains-musl/${musl_name}-cross"

    elif [ -n "$glibc_name" ]; then
        toolchain_type="glibc"
        CROSS_COMPILE="${glibc_name}-"
        HOST="$glibc_name"

        # Try glibc toolchain name as directory first (extracted Bootlin toolchains),
        # then fall back to Bootlin archive pattern for backward compatibility
        if [ -d "/build/toolchains-glibc/${glibc_name}" ]; then
            toolchain_dir="/build/toolchains-glibc/${glibc_name}"
        elif [ -n "$bootlin_arch" ]; then
            toolchain_dir=$(find /build/toolchains-glibc -maxdepth 1 -type d -name "${bootlin_arch}--glibc--stable-*" 2>/dev/null | head -1)
            if [ -z "$toolchain_dir" ]; then
                log_error "No glibc toolchain found for $arch (tried ${glibc_name} and ${bootlin_arch}--glibc--stable-*)"
                return 1
            fi
        else
            log_error "No glibc toolchain directory found for architecture: $arch"
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
    export NM="${CROSS_COMPILE}nm"
    export OBJCOPY="${CROSS_COMPILE}objcopy"
    export OBJDUMP="${CROSS_COMPILE}objdump"

    export TOOLCHAIN_TYPE="$toolchain_type"
    export LIBC_TYPE="${LIBC_TYPE:-$toolchain_type}"

    # Separate dependency cache by libc type to avoid musl/glibc cross-contamination
    # (glibc 2.38+ headers redirect strtoul→__isoc23_strtoul, breaking musl links)
    export DEPS_PREFIX="$toolchain_type"

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
        log "  NM: $NM" >&2
        log "  OBJCOPY: $OBJCOPY" >&2
        log "  OBJDUMP: $OBJDUMP" >&2
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


check_tool_support() {
    local supported_os="$1"
    local tool_name="$2"

    # If not using Zig, always allow (traditional GCC build)
    if [ "${USE_ZIG:-0}" = "0" ]; then
        return 0
    fi

    # Extract OS from Zig target (format: arch_os or arch_os_abi)
    local target_os=""
    if [[ "$ZIG_TARGET" == *"_"* ]]; then
        # For x86_64_windows, we need to handle the underscore in x86_64
        # Split on underscore and take the last part (or second-to-last if ABI exists)
        local parts=(${ZIG_TARGET//_/ })
        local num_parts=${#parts[@]}

        if [ $num_parts -ge 2 ]; then
            # Assume last part is OS unless it looks like an ABI
            target_os="${parts[-1]}"

            # Common ABIs: gnu, musl, msvc, none
            if [[ "$target_os" == "gnu" ]] || [[ "$target_os" == "musl" ]] || [[ "$target_os" == "msvc" ]] || [[ "$target_os" == "none" ]]; then
                # Last part is ABI, so OS is second-to-last
                target_os="${parts[-2]}"
            fi
        fi
    fi

    # If we couldn't determine OS, allow build (fail-safe)
    if [ -z "$target_os" ]; then
        return 0
    fi

    # Check if target OS is in supported list
    local IFS=','
    for os in $supported_os; do
        if [ "$os" = "$target_os" ] || [ "$os" = "any" ]; then
            return 0
        fi
    done

    log_error "$tool_name does not support $target_os (supported: $supported_os)"
    return 1
}

# Canonical toolchain setup for any arch/libc combination.
# Delegates to setup_arch which handles musl, glibc, and Zig paths.
# LIBC_TYPE is respected: when set to "glibc", musl is skipped even if available.
setup_toolchain_for_arch() {
    local arch=$1
    setup_arch "$arch"
    return $?
}

export -f setup_arch
export -f download_and_extract
export -f setup_toolchain_for_arch
