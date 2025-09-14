#!/bin/bash
# Compile flags configuration

# Source arch_helper for get_arch_cflags function
source "$(dirname "${BASH_SOURCE[0]}")/arch_helper.sh"

# Usage: get_compile_flags <arch> <mode> [tool]
# mode: static, shared
get_compile_flags() {
    local arch=$1
    local mode=$2
    local tool=${3:-}
    
    # Debug output to stderr
    if [ "${DEBUG:-}" = "1" ]; then
        echo "[DEBUG] get_compile_flags called with: arch=$arch, mode=$mode, tool=$tool" >&2
    fi
    
    local base_flags=""
    
    case "$mode" in
        static)
            # Optimized for old embedded systems (size-focused)
            base_flags="-Os -fno-pie -fno-pic -D_GNU_SOURCE"
            base_flags="$base_flags -fno-strict-aliasing -ffunction-sections -fdata-sections"
            base_flags="$base_flags -fvisibility=hidden -fno-ident -fmerge-all-constants"
            base_flags="$base_flags -fno-unwind-tables -fno-asynchronous-unwind-tables"
            base_flags="$base_flags -fomit-frame-pointer"
            base_flags="$base_flags -fno-stack-protector"
            base_flags="-static $base_flags"
            # Add random seed for reproducible builds
            if [ -n "$tool" ]; then
                base_flags="$base_flags -frandom-seed=${tool}-${arch}"
            fi
            ;;
        shared)
            # Shared libraries need PIC
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
    
    # Architecture-specific flags from ARCH_CONFIG
    local arch_flags=$(get_arch_cflags "$arch")
    if [ -n "$arch_flags" ]; then
        base_flags="$base_flags $arch_flags"
    fi
    
    # Tool-specific flags (if needed)
    if [ -n "$tool" ]; then
        base_flags="$(add_tool_specific_flags "$tool" "$base_flags")"
    fi
    
    # Add debug flags if enabled
    if [ "${DEBUG:-}" = "1" ]; then
        base_flags="$base_flags -g1"
    fi
    
    # Skip adding CFLAGS_ARCH since arch_flags already includes it from get_arch_cflags
    # This prevents duplicate flags when CFLAGS_ARCH is set in the environment
    
    echo "$base_flags"
}

# Get linker flags based on mode
# Usage: get_link_flags <arch> <mode> [lib_name]
get_link_flags() {
    local arch=$1
    local mode=$2
    local lib_name=${3:-}
    local libc_type="${LIBC_TYPE:-glibc}"
    
    local link_flags=""
    
    case "$mode" in
        static)
            # Optimized for old systems
            link_flags="-no-pie -static -Wl,--gc-sections -Wl,--strip-all"
            link_flags="$link_flags -Wl,--as-needed -Wl,--build-id=sha1"
            
            # Architecture-specific static link flags
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
            
            # Add hash style for glibc
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


# Add tool-specific flags
add_tool_specific_flags() {
    local tool=$1
    local flags=$2
    
    case "$tool" in
        busybox|busybox_nodrop)
            # BusyBox likes smaller size optimizations
            flags="${flags/-Os/-Os}"  # Ensure -Os is used
            ;;
        gdb|gdb-slim|gdb-full)
            # GDB-specific optimizations
            ;;
        python|python3)
            # Python needs certain features
            flags="${flags/-fvisibility=hidden/}"
            ;;
    esac
    
    echo "$flags"
}

# Get toolchain info (compiler, strip, etc.)
# Usage: get_toolchain_info <arch> <tool_type>
# tool_type: gcc, strip, ar, ranlib, etc.
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

# Get musl toolchain tool
get_musl_toolchain_tool() {
    local arch=$1
    local tool_type=$2
    
    # Source architecture mapping if needed
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

# Get glibc toolchain tool
# Get C++ compile flags
# Usage: get_cxx_flags <arch> <mode> [tool]
get_cxx_flags() {
    local arch=$1
    local mode=${2:-static}
    local tool=${3:-}
    
    local base_flags=$(get_compile_flags "$arch" "$mode" "$tool")
    
    # C++-specific flags
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