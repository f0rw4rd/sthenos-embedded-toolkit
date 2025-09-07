#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/build_helpers.sh"
source "$SCRIPT_DIR/lib/arch_map.sh"

LIBS_TO_BUILD=""
ARCHS_TO_BUILD=""

while [ $# -gt 0 ]; do
    case $1 in
        -d|--debug)
            shift
            ;;
        all)
            if [ -z "$LIBS_TO_BUILD" ]; then
                LIBS_TO_BUILD="all"
            elif [ -z "$ARCHS_TO_BUILD" ]; then
                ARCHS_TO_BUILD="all"
            fi
            shift
            ;;
        libdesock|shell-env|shell-helper|shell-bind|shell-reverse|shell-fifo|tls-noverify)
            LIBS_TO_BUILD="$1"
            shift
            ;;
        arm32v5le|arm32v5lehf|arm32v7le|arm32v7lehf|armeb|armv6|armv7m|armv7r|\
        aarch64|aarch64_be|aarch64be|\
        i486|ix86le|x86_64|\
        mips32v2le|mips32v2lesf|mips32v2be|mips32v2besf|mipsn32|mipsn32el|mips64|mips64le|mips64n32|mips64n32el|\
        ppc32be|ppc32besf|powerpcle|powerpclesf|powerpc64|ppc64le|\
        sh2|sh2eb|sh4|sh4eb|\
        microblaze|microblazeel|or1k|m68k|s390x|\
        riscv32|riscv64)
            ARCHS_TO_BUILD="$1"
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

[ -z "$LIBS_TO_BUILD" ] && LIBS_TO_BUILD="all"
[ -z "$ARCHS_TO_BUILD" ] && ARCHS_TO_BUILD="all"

if [ "$LIBS_TO_BUILD" = "all" ]; then
    LIBS_TO_BUILD="libdesock shell-env shell-helper shell-bind shell-reverse shell-fifo tls-noverify"
fi

if [ "$ARCHS_TO_BUILD" = "all" ]; then
    # Use the same architectures as glibc for consistency
    # Use canonical musl architecture names from main build system
    ARCHS_TO_BUILD="arm32v5le arm32v5lehf arm32v7le arm32v7lehf armeb armv6 armv7m armv7r aarch64 aarch64_be i486 ix86le x86_64 mips32v2le mips32v2lesf mips32v2be mips32v2besf mipsn32 mipsn32el mips64 mips64le mips64n32 mips64n32el ppc32be ppc32besf powerpcle powerpclesf powerpc64 ppc64le sh2 sh2eb sh4 sh4eb microblaze microblazeel or1k m68k s390x riscv32 riscv64"
fi

build_preload_musl() {
    local lib="$1"
    local arch="$2"
    local output_dir="/build/output-preload/musl/$arch"
    
    # Special handling for tls-noverify - use the dedicated build script
    if [ "$lib" = "tls-noverify" ]; then
        # Source the tls-noverify build script
        source "/build/scripts/preload/build-tls-noverify.sh"
        # Call the musl build function
        build_tls_noverify_musl "$arch"
        return $?
    fi
    
    # Special handling for libdesock - use the dedicated build script
    if [ "$lib" = "libdesock" ]; then
        # Source the libdesock build script
        source "/build/scripts/preload/build-libdesock.sh"
        # Call the musl build function
        build_libdesock_musl "$arch"
        return $?
    fi
    
    # Regular preload library handling
    local source="/build/preload-libs/${lib}.c"
    
    mkdir -p "$output_dir"
    
    if [ -f "$output_dir/${lib}.so" ]; then
        local size=$(get_binary_size "$output_dir/${lib}.so")
        log_tool "$arch" "Already built: ${lib}.so ($size)"
        return 0
    fi
    
    # Source the common architecture mapping
    source "$SCRIPT_DIR/preload/lib/compile-musl.sh"
    
    # Map glibc-style arch names to canonical musl names
    local canonical_arch=$(map_arch_name "$arch")
    
    # Handle glibc-only architectures
    if [[ "$canonical_arch" == *"[glibc-only]"* ]]; then
        log_tool "$arch" "Not supported in musl builds (glibc-only)"
        return 1
    fi
    
    # Get musl toolchain prefix using the common function
    local prefix=$(get_musl_toolchain_prefix "$canonical_arch")
    
    if [ -z "$prefix" ]; then
        log_tool "$arch" "Unknown architecture"
        return 1
    fi
    
    # In main build system, toolchain dir is named by canonical arch
    local toolchain_dir="/build/toolchains/${canonical_arch}"
    if [ ! -d "$toolchain_dir" ]; then
        # Try the preload-style naming with -cross suffix
        toolchain_dir="/build/toolchains/${prefix}-cross"
        if [ ! -d "$toolchain_dir" ]; then
            log_tool "$arch" "Toolchain not found for $canonical_arch"
            return 1
        fi
    fi
    
    local compiler="${toolchain_dir}/bin/${prefix}-gcc"
    local strip_cmd="${toolchain_dir}/bin/${prefix}-strip"
    
    if [ ! -x "$compiler" ]; then
        log_tool "$arch" "Compiler not found: $compiler"
        return 1
    fi
    
    log_tool "$arch" "Building ${lib}.so..."
    
    local cflags="-fPIC -O2 -Wall -D_GNU_SOURCE -fno-strict-aliasing"
    local ldflags="-shared -Wl,-soname,${lib}.so"
    
    local build_dir="/tmp/build-${lib}-${arch}-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Add pthread for tls-noverify
    local extra_libs="-ldl"
    if [ "$lib" = "tls-noverify" ]; then
        extra_libs="-ldl -lpthread"
    fi
    
    if $compiler $cflags -c "$source" -o "${lib}.o" 2>&1; then
        if $compiler $ldflags -o "${lib}.so" "${lib}.o" $extra_libs 2>&1; then
            $strip_cmd "${lib}.so" 2>/dev/null || true
            
            cp "${lib}.so" "$output_dir/" || {
                log_tool "$arch" "Failed to copy library"
                cleanup_build_dir "$build_dir"
                return 1
            }
            
            local size=$(get_binary_size "$output_dir/${lib}.so")
            log_tool "$arch" "Successfully built: ${lib}.so ($size)"
            
            cleanup_build_dir "$build_dir"
            return 0
        else
            log_tool "$arch" "Link failed"
        fi
    else
        log_tool "$arch" "Compilation failed"
    fi
    
    cleanup_build_dir "$build_dir"
    return 1
}

TOTAL=0
SUCCESS=0
FAILED=0

for lib in $LIBS_TO_BUILD; do
    for arch in $ARCHS_TO_BUILD; do
        TOTAL=$((TOTAL + 1))
        if build_preload_musl "$lib" "$arch"; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
        fi
        echo
    done
done

log_info "Total: $TOTAL"
log_info "Successful: $SUCCESS"
log_error "Failed: $FAILED"

exit $FAILED