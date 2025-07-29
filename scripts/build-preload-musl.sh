#!/bin/sh
# Build preload libraries with musl toolchains
# This runs inside the main Alpine container
set -e

# Default values
LIBS_TO_BUILD=""
ARCHS_TO_BUILD=""
DEBUG=""

# Parse arguments
while [ $# -gt 0 ]; do
    case $1 in
        -d|--debug)
            DEBUG=1
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
        shell-env|shell-helper|shell-bind|shell-reverse|shell-fifo)
            LIBS_TO_BUILD="$1"
            shift
            ;;
        x86_64|aarch64|arm32v7le|i486|mips64le|ppc64le|riscv64)
            ARCHS_TO_BUILD="$1"
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Default to all if not specified
[ -z "$LIBS_TO_BUILD" ] && LIBS_TO_BUILD="all"
[ -z "$ARCHS_TO_BUILD" ] && ARCHS_TO_BUILD="all"

# Expand "all"
if [ "$LIBS_TO_BUILD" = "all" ]; then
    LIBS_TO_BUILD="shell-env shell-helper shell-bind shell-reverse shell-fifo"
fi

if [ "$ARCHS_TO_BUILD" = "all" ]; then
    # Match the architectures from the main build system that have musl toolchains
    ARCHS_TO_BUILD="x86_64 aarch64 aarch64_be arm32v5le arm32v5lehf arm32v7le arm32v7lehf armeb armv6 armv7m armv7r i486 ix86le m68k microblaze microblazeel mips32v2be mips32v2le mips64 mips64le or1k ppc32be powerpcle powerpc64 ppc64le riscv32 riscv64 s390x sh2 sh2eb sh4 sh4eb"
fi

echo "==================================="
echo "Preload Library Build with Musl"
echo "==================================="
echo "Libraries: $LIBS_TO_BUILD"
echo "Architectures: $ARCHS_TO_BUILD"
echo "==================================="
echo

# Function to build a library
build_preload_musl() {
    local lib="$1"
    local arch="$2"
    local output_dir="/build/output-preload/musl/$arch"
    local source="/build/preload-libs/${lib}.c"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check if already built
    if [ -f "$output_dir/${lib}.so" ]; then
        local size=$(ls -lh "$output_dir/${lib}.so" 2>/dev/null | awk '{print $5}')
        echo "[$arch] Already built: ${lib}.so ($size)"
        return 0
    fi
    
    # Get toolchain prefix
    local prefix=""
    case "$arch" in
        x86_64)      prefix="x86_64-linux-musl" ;;
        aarch64)     prefix="aarch64-linux-musl" ;;
        aarch64_be)  prefix="aarch64_be-linux-musl" ;;
        arm32v5le)   prefix="arm-linux-musleabi" ;;
        arm32v5lehf) prefix="arm-linux-musleabihf" ;;
        arm32v7le)   prefix="armv7l-linux-musleabihf" ;;
        arm32v7lehf) prefix="armv7l-linux-musleabihf" ;;
        armeb)       prefix="armeb-linux-musleabi" ;;
        armv6)       prefix="armv6-linux-musleabihf" ;;
        armv7m)      prefix="armv7m-linux-musleabi" ;;
        armv7r)      prefix="armv7r-linux-musleabihf" ;;
        i486)        prefix="i486-linux-musl" ;;
        ix86le)      prefix="i686-linux-musl" ;;
        m68k)        prefix="m68k-linux-musl" ;;
        microblaze)  prefix="microblaze-linux-musl" ;;
        microblazeel) prefix="microblazeel-linux-musl" ;;
        mips32v2be)  prefix="mips-linux-musl" ;;
        mips32v2le)  prefix="mipsel-linux-musl" ;;
        mips64)      prefix="mips64-linux-musl" ;;
        mips64le)    prefix="mips64el-linux-musl" ;;
        or1k)        prefix="or1k-linux-musl" ;;
        ppc32be)     prefix="powerpc-linux-musl" ;;
        powerpcle)   prefix="powerpcle-linux-musl" ;;
        powerpc64)   prefix="powerpc64-linux-musl" ;;
        ppc64le)     prefix="powerpc64le-linux-musl" ;;
        riscv32)     prefix="riscv32-linux-musl" ;;
        riscv64)     prefix="riscv64-linux-musl" ;;
        s390x)       prefix="s390x-linux-musl" ;;
        sh2)         prefix="sh2-linux-musl" ;;
        sh2eb)       prefix="sh2eb-linux-musl" ;;
        sh4)         prefix="sh4-linux-musl" ;;
        sh4eb)       prefix="sh4eb-linux-musl" ;;
        *)           echo "[$arch] Unknown architecture"; return 1 ;;
    esac
    
    # Check if toolchain exists
    local toolchain_dir="/build/toolchains/${prefix}-cross"
    if [ ! -d "$toolchain_dir" ]; then
        echo "[$arch] Toolchain not found, building it first..."
        # Build a dummy tool to create the toolchain
        cd /build
        /scripts/build-unified.sh strace "$arch" >/dev/null 2>&1 || true
        
        if [ ! -d "$toolchain_dir" ]; then
            echo "[$arch] Failed to create toolchain"
            return 1
        fi
    fi
    
    local compiler="${toolchain_dir}/bin/${prefix}-gcc"
    local strip_cmd="${toolchain_dir}/bin/${prefix}-strip"
    
    if [ ! -x "$compiler" ]; then
        echo "[$arch] Compiler not found: $compiler"
        return 1
    fi
    
    echo "[$arch] Building ${lib}.so..."
    
    # Compilation flags
    local cflags="-fPIC -O2 -Wall -D_GNU_SOURCE -fno-strict-aliasing"
    local ldflags="-shared -Wl,-soname,${lib}.so"
    
    # Create temp directory
    local build_dir="/tmp/build-${lib}-${arch}-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Compile
    if $compiler $cflags -c "$source" -o "${lib}.o" 2>&1; then
        # Link
        if $compiler $ldflags -o "${lib}.so" "${lib}.o" -ldl 2>&1; then
            # Strip
            $strip_cmd "${lib}.so" 2>/dev/null || true
            
            # Copy to output
            cp "${lib}.so" "$output_dir/" || {
                echo "[$arch] Failed to copy library"
                cd /
                rm -rf "$build_dir"
                return 1
            }
            
            # Show info
            local size=$(ls -lh "$output_dir/${lib}.so" 2>/dev/null | awk '{print $5}')
            echo "[$arch] Successfully built: ${lib}.so ($size)"
            
            cd /
            rm -rf "$build_dir"
            return 0
        else
            echo "[$arch] Link failed"
        fi
    else
        echo "[$arch] Compilation failed"
    fi
    
    cd /
    rm -rf "$build_dir"
    return 1
}

# Build each library for each architecture
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

echo "==================================="
echo "Build Summary"
echo "==================================="
echo "Total: $TOTAL"
echo "Successful: $SUCCESS"
echo "Failed: $FAILED"

exit $FAILED