#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/arch_helper.sh"

get_compile_flags() {
    local arch=$1
    local mode=$2
    local tool=${3:-}
    
    if [ "${DEBUG:-}" = "1" ]; then
        echo "[DEBUG] get_compile_flags called with: arch=$arch, mode=$mode, tool=$tool" >&2
    fi
    
    local base_flags=""
    
    case "$mode" in
        static)
            base_flags="-Os -fno-pie -fno-pic -D_GNU_SOURCE"
            base_flags="$base_flags -fno-strict-aliasing -ffunction-sections -fdata-sections"
            base_flags="$base_flags -fvisibility=hidden -fno-ident -fmerge-all-constants"
            base_flags="$base_flags -fno-unwind-tables -fno-asynchronous-unwind-tables"
            base_flags="$base_flags -fomit-frame-pointer"
            base_flags="$base_flags -fno-stack-protector"
            base_flags="-static $base_flags"
            if [ -n "$tool" ]; then
                base_flags="$base_flags -frandom-seed=${tool}-${arch}"
            fi
            ;;
        shared)
            base_flags="-Os -fPIC -D_GNU_SOURCE"
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
            link_flags="-no-pie -static -Wl,--gc-sections -Wl,--strip-all"
            link_flags="$link_flags -Wl,--as-needed -Wl,--build-id=sha1"
            
            case "$arch" in
                mips*)
                    link_flags="$link_flags -Wl,--no-export-dynamic"
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
            flags="${flags/-Os/-Os}"  # Ensure -Os is used
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
