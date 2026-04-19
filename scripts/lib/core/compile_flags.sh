#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/arch_helper.sh"
source "$(dirname "${BASH_SOURCE[0]}")/os_targets.sh"

get_compile_flags() {
    local arch=$1
    local mode=$2
    local tool=${3:-}
    
    if [ "${DEBUG:-}" = "1" ]; then
        echo "[DEBUG] get_compile_flags called with: arch=$arch, mode=$mode, tool=$tool" >&2
    fi
    
    local base_flags=""
    
    # _GNU_SOURCE enables glibc/musl GNU extensions (e.g. GNU strerror_r returning char*).
    # Darwin/BSD libc provides the XSI variants instead, so defining _GNU_SOURCE there
    # produces type mismatches (OpenSSL crypto/o_str.c: int -> char* under -Wint-conversion
    # as error). Only set it for Linux/Android targets.
    local gnu_source_flag="-D_GNU_SOURCE"
    if [ "${USE_ZIG:-0}" = "1" ]; then
        case "${ZIG_TARGET:-}" in
            *macos*|*darwin*|*ios*|*tvos*|*watchos*|*visionos*|*freebsd*|*openbsd*|*netbsd*|*dragonfly*|*windows*|*wasi*)
                gnu_source_flag=""
                ;;
        esac
    fi

    case "$mode" in
        static)
            base_flags="-Os $gnu_source_flag"
            base_flags="$base_flags -fno-strict-aliasing -ffunction-sections -fdata-sections"
            base_flags="$base_flags -fvisibility=hidden -fno-ident -fmerge-all-constants"
            base_flags="$base_flags -fno-unwind-tables -fno-asynchronous-unwind-tables"
            base_flags="$base_flags -fomit-frame-pointer"
            base_flags="$base_flags -fno-stack-protector"

            # Force non-PIE for Linux static builds. Some toolchains
            # (e.g. musl.cc sh2, bootlin glibc) default to --enable-default-pie,
            # which produces text relocations that break static linking of libs
            # with legacy assembly (OpenSSL cast-586.o, aesni-x86.o, etc).
            # Windows/Wasm Zig targets require PIC, so skip -fno-pie there.
            if platform_supports_static; then
                if [ "${USE_ZIG:-0}" = "1" ] && { [[ "${ZIG_TARGET:-}" == *"windows"* ]] || [[ "${ZIG_TARGET:-}" == *"wasi"* ]]; }; then
                    base_flags="-static $base_flags"
                else
                    base_flags="-static -fno-pie -fno-pic $base_flags"
                fi
            fi
            
            if [ -n "$tool" ]; then
                base_flags="$base_flags -frandom-seed=${tool}-${arch}"
            fi
            ;;
        shared)
            base_flags="-Os -fPIC $gnu_source_flag"
            base_flags="$base_flags -fno-strict-aliasing -ffunction-sections -fdata-sections"
            base_flags="$base_flags -fvisibility=hidden -fno-ident"
            base_flags="$base_flags -Wall"
            ;;
        *)
            echo "Error: Unknown mode $mode" >&2
            return 1
            ;;
    esac
    
    local arch_flags=$(get_arch_cflags "$arch")
    if [ -n "$arch_flags" ]; then
        base_flags="$base_flags $arch_flags"
    fi
    
    if [ -n "$tool" ]; then
        base_flags="$(add_tool_specific_flags "$tool" "$base_flags")"
    fi
    
    if [ "${DEBUG:-}" = "1" ]; then
        base_flags="$base_flags -g1"
    fi
    
    
    echo "$base_flags"
}

get_link_flags() {
    local arch=$1
    local mode=$2
    local lib_name=${3:-}
    local libc_type="${LIBC_TYPE:-glibc}"
    
    local link_flags=""
    
    case "$mode" in
        static)
            if ! platform_supports_static; then
                # Determine platform-specific link flags for non-static targets
                local target_family=$(get_os_family_from_target)
                if [ "$target_family" = "darwin" ]; then
                    # Darwin ld64 uses different flags
                    link_flags="-Wl,-dead_strip"
                else
                    # BSDs don't support -static but use GNU ld flags
                    link_flags="-Wl,--gc-sections -Wl,--strip-all -Wl,--as-needed"
                fi
            else
                # Windows/Wasm Zig targets require PIE, so skip -no-pie there
                if [ "${USE_ZIG:-0}" = "1" ] && { [[ "${ZIG_TARGET:-}" == *"windows"* ]] || [[ "${ZIG_TARGET:-}" == *"wasi"* ]]; }; then
                    link_flags="-static -Wl,--gc-sections -Wl,--strip-all -Wl,--as-needed -Wl,--build-id=sha1"
                else
                    link_flags="-static -no-pie -Wl,--gc-sections -Wl,--strip-all -Wl,--as-needed -Wl,--build-id=sha1"
                fi
            fi
            
            case "$arch" in
                mips*)
                    link_flags="$link_flags -Wl,--no-export-dynamic"
                    ;;
                sh2|sh2eb)
                    # sh2/sh2eb musl.cc toolchains are built with --enable-default-pie
                    # but binutils 2.37 ld segfaults on static-pie for SuperH-2;
                    # disable PIE so the linker gets plain -static instead of -static -pie
                    link_flags="-no-pie $link_flags"
                    ;;
                m68k_coldfire)
                    # Bootlin m68k-coldfire glibc toolchain has an empty w_fmod.o in libm.a,
                    # so fmod() is unresolved despite -lm. Alias it to __ieee754_fmod which
                    # is present in e_fmod.o. We also append -lm here so the defsym's target
                    # symbol is always resolvable even for tools whose Makefiles don't pass
                    # -lm themselves (e.g. can-utils); binutils errors out on --defsym to an
                    # undefined symbol regardless of whether fmod is actually referenced.
                    link_flags="$link_flags -Wl,--defsym,fmod=__ieee754_fmod -lm"
                    ;;
            esac
            ;;
            
        shared)
            link_flags="-shared"
            if [ -n "$lib_name" ]; then
                link_flags="$link_flags -Wl,-soname,${lib_name}.so"
            fi
            
            if [ "$libc_type" = "glibc" ]; then
                link_flags="$link_flags -Wl,--hash-style=both"
            fi
            ;;
            
        *)
            echo "Error: Unknown mode $mode" >&2
            return 1
            ;;
    esac
    
    echo "$link_flags"
}


add_tool_specific_flags() {
    local tool=$1
    local flags=$2
    
    case "$tool" in
        busybox|busybox_nodrop)
            # No special flags needed; -Os is already set by default
            ;;
        gdb|gdb-slim|gdb-full)
            ;;
        python|python3)
            flags="${flags/-fvisibility=hidden/}"
            ;;
    esac
    
    echo "$flags"
}

get_toolchain_info() {
    local arch=$1
    local tool_type=$2
    local libc_type="${LIBC_TYPE:-glibc}"
    
    if [ "$libc_type" = "musl" ]; then
        get_musl_toolchain_tool "$arch" "$tool_type"
    else
        get_glibc_toolchain_tool "$arch" "$tool_type"
    fi
}

get_musl_toolchain_tool() {
    local arch=$1
    local tool_type=$2
    
    if ! type get_musl_toolchain_prefix >/dev/null 2>&1; then
        source /build/scripts/lib/shared/compile.sh
    fi
    
    local prefix=$(get_musl_toolchain_prefix "$arch")
    local toolchain_dir="/build/toolchains/${prefix}-cross"
    
    if [ ! -d "$toolchain_dir" ]; then
        toolchain_dir="/toolchains/${arch}"
    fi
    
    echo "${toolchain_dir}/bin/${prefix}-${tool_type}"
}

get_cxx_flags() {
    local arch=$1
    local mode=${2:-static}
    local tool=${3:-}
    
    local base_flags=$(get_compile_flags "$arch" "$mode" "$tool")
    
    base_flags="$base_flags -fvisibility-inlines-hidden"
    base_flags="$base_flags -fno-rtti"
    base_flags="$base_flags -fno-exceptions"
    
    echo "$base_flags"
}


get_glibc_toolchain_tool() {
    local arch=$1
    local tool_type=$2
    
    case "$tool_type" in
        gcc)
            get_compiler "$arch"
            ;;
        strip)
            get_strip "$arch"
            ;;
        ar)
            get_ar "$arch"
            ;;
        ranlib)
            get_ranlib "$arch"
            ;;
        *)
            local toolchain_dir=$(get_toolchain_dir "$arch")
            local prefix=$(get_toolchain_prefix "$arch")
            echo "${toolchain_dir}/bin/${prefix}-${tool_type}"
            ;;
    esac
}
