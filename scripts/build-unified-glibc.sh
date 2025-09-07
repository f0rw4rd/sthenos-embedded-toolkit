#!/bin/bash
set -e

GLIBC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$GLIBC_SCRIPT_DIR/.." && pwd)"

if [ -f "$GLIBC_SCRIPT_DIR/lib/logging.sh" ]; then
    source "$GLIBC_SCRIPT_DIR/lib/logging.sh"
fi

if [ -f "$GLIBC_SCRIPT_DIR/lib/build_flags_glibc.sh" ]; then
    source "$GLIBC_SCRIPT_DIR/lib/build_flags_glibc.sh"
fi

if [ -f "$GLIBC_SCRIPT_DIR/lib/arch_map.sh" ]; then
    source "$GLIBC_SCRIPT_DIR/lib/arch_map.sh"
else
    log() { log_tool "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
    log_error() { log_tool "$(date '+%Y-%m-%d %H:%M:%S')" "ERROR: $*" >&2; }
fi

if [ -f "$GLIBC_SCRIPT_DIR/lib/common.sh" ]; then
    source "$GLIBC_SCRIPT_DIR/lib/common.sh"
elif [ -f "$GLIBC_SCRIPT_DIR/preload/lib/common.sh" ]; then
    source "$GLIBC_SCRIPT_DIR/preload/lib/common.sh"
fi

TOOLCHAINS_DIR="/build/toolchains-preload"
OUTPUT_DIR="/build/output"
BUILD_DIR="/build/tmp/build-glibc-static"
SOURCES_DIR="/build/sources"
DEPS_PREFIX="/build/deps-glibc-static"
LOGS_DIR="/build/logs-glibc-static"

mkdir -p "$BUILD_DIR" "$SOURCES_DIR" "$DEPS_PREFIX" "$LOGS_DIR" "$OUTPUT_DIR"

TOOL="${1:-all}"
ARCH="${2:-all}"
DEBUG="${DEBUG:-}"

get_glibc_tools() {
    echo "ltrace custom-glibc"
}

map_arch_to_musl() {
    # Use unified architecture mapping
    if type map_arch_name >/dev/null 2>&1; then
        map_arch_name "$1"
    else
        # Fallback if arch_map.sh not loaded
        local arch="$1"
        case "$arch" in
            arm32v7le)   echo "arm32v7le" ;;
            armv5)       echo "arm32v5le" ;;
            armv6)       echo "armv6" ;;
            ppc32)       echo "ppc32be" ;;
            ppc64le)     echo "ppc64le" ;;
            i486)        echo "i486" ;;
            mips32)      echo "mips32v2be" ;;
            mips32el)    echo "mips32v2le" ;;
            openrisc)    echo "or1k" ;;
            powerpc64)   echo "powerpc64" ;;
            aarch64be)   echo "aarch64_be" ;;
            *)           echo "$arch" ;;
        esac
    fi
}

setup_arch_glibc() {
    local canonical_arch="$1"
    local arch="$canonical_arch"
    
    # Map canonical names to glibc/Bootlin names for toolchain lookup
    case "$canonical_arch" in
        arm32v5le)   arch="armv5" ;;
        arm32v7le)   arch="arm32v7le" ;;
        ppc32be)     arch="ppc32" ;;
        mips32v2be)  arch="mips32" ;;
        mips32v2le)  arch="mips32el" ;;
        or1k)        arch="openrisc" ;;
        aarch64_be)  arch="aarch64be" ;;
    esac
    
    case "$arch" in
        x86_64)      TOOLCHAIN_PREFIX="x86_64" ;;
        aarch64)     TOOLCHAIN_PREFIX="aarch64" ;;
        arm32v7le)   TOOLCHAIN_PREFIX="arm-cortex_a7-linux-gnueabihf" ;;
        i486)        TOOLCHAIN_PREFIX="i486" ;;
        mips64le)    TOOLCHAIN_PREFIX="mips64el" ;;
        ppc64le)     TOOLCHAIN_PREFIX="powerpc64le" ;;
        riscv64)     TOOLCHAIN_PREFIX="riscv64" ;;
        s390x)       TOOLCHAIN_PREFIX="s390x" ;;
        aarch64be)   TOOLCHAIN_PREFIX="aarch64be" ;;
        mips64)      TOOLCHAIN_PREFIX="mips64" ;;
        armv5)       TOOLCHAIN_PREFIX="armv5" ;;
        armv6)       TOOLCHAIN_PREFIX="armv6" ;;
        ppc32)       TOOLCHAIN_PREFIX="powerpc" ;;
        sparc64)     TOOLCHAIN_PREFIX="sparc64" ;;
        sh4)         TOOLCHAIN_PREFIX="sh4" ;;
        mips32)      TOOLCHAIN_PREFIX="mips32" ;;
        mips32el)    TOOLCHAIN_PREFIX="mips32el" ;;
        riscv32)     TOOLCHAIN_PREFIX="riscv32" ;;
        microblazeel) TOOLCHAIN_PREFIX="microblazeel" ;;
        microblazebe) TOOLCHAIN_PREFIX="microblazebe" ;;
        nios2)       TOOLCHAIN_PREFIX="nios2" ;;
        openrisc)    TOOLCHAIN_PREFIX="openrisc" ;;
        arcle)       TOOLCHAIN_PREFIX="arcle" ;;
        xtensa)      TOOLCHAIN_PREFIX="xtensa" ;;
        m68k)        TOOLCHAIN_PREFIX="m68k" ;;
        *) 
            log_tool "$(date +%H:%M:%S)" "ERROR: Unsupported architecture for glibc: $arch" >&2
            return 1
            ;;
    esac
    
    case "$arch" in
        x86_64)      TOOLCHAIN_NAME="x86_64-unknown-linux-gnu" ;;
        aarch64)     TOOLCHAIN_NAME="aarch64-unknown-linux-gnu" ;;
        arm32v7le)   TOOLCHAIN_NAME="arm-cortex_a7-linux-gnueabihf" ;;
        i486)        TOOLCHAIN_NAME="i486-unknown-linux-gnu" ;;
        mips64le)    TOOLCHAIN_NAME="mips64el-unknown-linux-gnu" ;;
        ppc64le)     TOOLCHAIN_NAME="powerpc64le-unknown-linux-gnu" ;;
        riscv64)     TOOLCHAIN_NAME="riscv64-unknown-linux-gnu" ;;
        s390x)       TOOLCHAIN_NAME="s390x-unknown-linux-gnu" ;;
        aarch64be)   TOOLCHAIN_NAME="aarch64be-unknown-linux-gnu" ;;
        mips64)      TOOLCHAIN_NAME="mips64-unknown-linux-gnu" ;;
        armv5)       TOOLCHAIN_NAME="armv5-unknown-linux-gnueabi" ;;
        armv6)       TOOLCHAIN_NAME="armv6-unknown-linux-gnueabihf" ;;
        ppc32)       TOOLCHAIN_NAME="powerpc-unknown-linux-gnu" ;;
        sparc64)     TOOLCHAIN_NAME="sparc64-unknown-linux-gnu" ;;
        sh4)         TOOLCHAIN_NAME="sh4-unknown-linux-gnu" ;;
        mips32)      TOOLCHAIN_NAME="mips32-unknown-linux-gnu" ;;
        mips32el)    TOOLCHAIN_NAME="mips32el-unknown-linux-gnu" ;;
        riscv32)     TOOLCHAIN_NAME="riscv32-unknown-linux-gnu" ;;
        microblazeel) TOOLCHAIN_NAME="microblazeel-unknown-linux-gnu" ;;
        microblazebe) TOOLCHAIN_NAME="microblazebe-unknown-linux-gnu" ;;
        nios2)       TOOLCHAIN_NAME="nios2-unknown-linux-gnu" ;;
        openrisc)    TOOLCHAIN_NAME="openrisc-unknown-linux-gnu" ;;
        arcle)       TOOLCHAIN_NAME="arcle-unknown-linux-gnu" ;;
        xtensa)      TOOLCHAIN_NAME="xtensa-unknown-linux-gnu" ;;
        m68k)        TOOLCHAIN_NAME="m68k-unknown-linux-gnu" ;;
        *)           TOOLCHAIN_NAME="${arch}-unknown-linux-gnu" ;;
    esac
    
    local toolchain_dir="${TOOLCHAINS_DIR}/${TOOLCHAIN_NAME}"
    if [ ! -d "$toolchain_dir" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Toolchain not found for $arch at $toolchain_dir" >&2
        return 1
    fi
    
    export PATH="${toolchain_dir}/bin:$PATH"
    export CC="${TOOLCHAIN_NAME}-gcc"
    export CXX="${TOOLCHAIN_NAME}-g++"
    export AR="${TOOLCHAIN_NAME}-ar"
    export STRIP="${TOOLCHAIN_NAME}-strip"
    export TOOLCHAIN_PREFIX
    
    # Set common build flags using centralized configuration
    export CFLAGS=$(get_glibc_compile_flags "$arch" "")
    export CXXFLAGS=$(get_glibc_cxx_flags "$arch" "")
    export LDFLAGS=$(get_glibc_link_flags "$arch")
    
    export GLIBC_SCRIPT_DIR TOOLCHAINS_DIR OUTPUT_DIR BUILD_DIR SOURCES_DIR DEPS_PREFIX LOGS_DIR
}

build_glibc_tool() {
    local tool="$1"
    local canonical_arch="$2"  # Use canonical architecture name throughout
    
    local musl_arch=$(map_arch_to_musl "$canonical_arch")
    
    local arch_output="${OUTPUT_DIR}/${musl_arch}"
    mkdir -p "$arch_output"
    
    if ! setup_arch_glibc "$canonical_arch"; then
        return 1
    fi
    
    export DEPS_PREFIX="${DEPS_PREFIX}/${canonical_arch}"
    mkdir -p "${DEPS_PREFIX}/lib" "${DEPS_PREFIX}/include"
    
    local build_script="${GLIBC_SCRIPT_DIR}/tools/build-${tool}.sh"
    if [ ! -f "$build_script" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Build script not found: $build_script" >&2
        return 1
    fi
    
    source "$build_script"
    
    if main "$canonical_arch"; then
        return 0
    else
        return 1
    fi
}

main() {
    echo "Embedded Toolkit Build Pipeline (Glibc Static)"
    echo "Start time: $(date)"
    echo ""
    echo -n "Tools: "
    
    if [ "$TOOL" = "all" ]; then
        TOOLS_TO_BUILD=$(get_glibc_tools)
    else
        TOOLS_TO_BUILD="$TOOL"
    fi
    echo "$TOOLS_TO_BUILD"
    
    if [ "$ARCH" = "all" ]; then
        ARCHS_TO_BUILD="x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el riscv32 microblazeel microblazebe nios2 openrisc arcle xtensa m68k"
    else
        ARCHS_TO_BUILD="$ARCH"
    fi
    
    local display_archs=""
    for arch in $ARCHS_TO_BUILD; do
        local musl_arch=$(map_arch_to_musl "$arch")
        display_archs="$display_archs $musl_arch"
    done
    echo -n "Architectures:"
    echo "$display_archs"
    echo "Mode: glibc static"
    echo "Build mode: Sequential per architecture, parallel compilation"
    echo "Logging: true"
    echo ""
    
    local total=0
    local success=0
    local failed=0
    
    for tool in $TOOLS_TO_BUILD; do
        for arch in $ARCHS_TO_BUILD; do
            total=$((total + 1))
            
            local musl_arch=$(map_arch_to_musl "$arch")
            local timestamp=$(date +%Y%m%d-%H%M%S)
            local log_file="${LOGS_DIR}/build-${tool}-${musl_arch}-${timestamp}.log"
            
            # Check if binary already exists and skip if requested
            if [ "${SKIP_IF_EXISTS:-true}" = "true" ] && [ -f "${OUTPUT_DIR}/${musl_arch}/${tool}" ]; then
                echo -n "[$musl_arch] $tool already exists, skipping..."
                success=$((success + 1))
                echo ""
                log_tool "$musl_arch" "✓ $tool already exists"
            else
                echo -n "[$musl_arch] Building $tool (log: $log_file)..."
                
                if build_glibc_tool "$tool" "$arch" > "$log_file" 2>&1; then
                success=$((success + 1))
                echo ""
                log_tool "$musl_arch" "✓ $tool built successfully"
            else
                failed=$((failed + 1))
                echo ""
                log_tool "$musl_arch" "✗ $tool build failed"
                log_tool "$musl_arch" "Check log: $log_file"
                fi
            fi
        done
    done
    
    echo ""
    echo "Total builds: $total"
    echo "Successful: $success"
    log_error "Failed: $failed"
    echo ""
    echo "End time: $(date)"
    
    if [ $failed -eq 0 ]; then
        echo "✓ All builds completed successfully"
    else
        log_error "✗ Some builds failed. Check logs for details."
    fi
    
    # Show detailed output with BuildID
    echo ""
    echo "Build artifacts:"
    for arch_dir in $ARCHS_TO_BUILD; do
        local musl_arch=$(map_arch_to_musl "$arch_dir")
        if [ -d "${OUTPUT_DIR}/${musl_arch}" ] && [ -n "$(ls -A ${OUTPUT_DIR}/${musl_arch} 2>/dev/null)" ]; then
            echo "${musl_arch}:"
            for binary in ${OUTPUT_DIR}/${musl_arch}/*; do
                if [ -f "$binary" ]; then
                    local basename=$(basename "$binary")
                    local file_info=$(file "$binary" 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
                    printf "  %-20s %s\n" "${basename}:" "$file_info"
                fi
            done
        fi
    done
    
    # Clean up empty architecture directories
    log_tool "$(date +%H:%M:%S)" "Cleaning up empty directories..."
    find "${OUTPUT_DIR}" -type d -empty -delete 2>/dev/null || true
    
    return $failed
}

main