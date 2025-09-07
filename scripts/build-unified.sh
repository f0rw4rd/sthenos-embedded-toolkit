#!/bin/bash
set -e

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BUILD_SCRIPT_DIR/lib/tools.sh"
source "$BUILD_SCRIPT_DIR/lib/logging.sh"
source "$BUILD_SCRIPT_DIR/lib/arch_map.sh"

usage() {
    cat << EOF
Usage: $0 [OPTIONS] <tool|all> <architecture|all>

Build static binaries for embedded systems.

Tools:
  strace      System call tracer
  busybox     Multi-call binary with Unix utilities
  bash        Bourne Again Shell
  socat       Socket relay tool
  ncat        Network utility
  tcpdump     Network packet analyzer
  gdbserver   Remote debugging server
  all         Build all tools

Architectures:
  arm32v5le   ARM 32-bit v5 Little Endian
  arm32v5lehf ARM 32-bit v5 Little Endian Hard Float
  arm32v7le   ARM 32-bit v7 Little Endian
  arm32v7lehf ARM 32-bit v7 Little Endian Hard Float
  mips32v2le  MIPS 32-bit v2 Little Endian
  mips32v2be  MIPS 32-bit v2 Big Endian
  ppc32be     PowerPC 32-bit Big Endian
  ix86le      x86 32-bit Little Endian
  all         Build for all architectures

Options:
  -m, --mode MODE    Build mode: standard (default), embedded, minimal
  -l, --log          Enable detailed logging
  -h, --help         Show this help message

Examples:
  $0 strace arm32v5le
  $0 all ix86le
  $0 gdbserver all --mode embedded
  $0 busybox all

EOF
    exit 0
}

MODE="standard"
LOG_ENABLED=false
TOOL=""
ARCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -l|--log)
            LOG_ENABLED=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$TOOL" ]; then
                TOOL="$1"
            elif [ -z "$ARCH" ]; then
                ARCH="$1"
            else
                log_error "Too many arguments"
                usage
            fi
            shift
            ;;
    esac
done

if [ -z "$TOOL" ] || [ -z "$ARCH" ]; then
    log_error "Missing required arguments"
    usage
fi

ALL_ARCHS=(
    arm32v5le arm32v5lehf arm32v7le arm32v7lehf armeb armv6 armv7m armv7r
    aarch64 aarch64_be
    i486 ix86le x86_64
    mips32v2le mips32v2lesf mips32v2be mips32v2besf mipsn32 mipsn32el mips64 mips64le mips64n32 mips64n32el
    ppc32be ppc32besf powerpcle powerpclesf powerpc64 ppc64le
    sh2 sh2eb sh4 sh4eb
    microblaze microblazeel or1k m68k s390x
    riscv32 riscv64
)

ALL_TOOLS=(strace busybox busybox_nodrop bash socat socat-ssl ncat ncat-ssl tcpdump gdbserver nmap dropbear ply can-utils)

if [ "$TOOL" = "all" ]; then
    TOOLS_TO_BUILD=("${ALL_TOOLS[@]}")
else
    TOOLS_TO_BUILD=("$TOOL")
fi

if [ "$ARCH" = "all" ]; then
    ARCHS_TO_BUILD=("${ALL_ARCHS[@]}")
else
    # Map architecture name to canonical form
    ARCH=$(map_arch_name "$ARCH")
    ARCHS_TO_BUILD=("$ARCH")
fi

if [ "$LOG_ENABLED" = true ]; then
    mkdir -p /build/logs
fi

do_build() {
    local tool=$1
    local arch=$2
    
    if ! setup_arch "$arch"; then
        log_tool "$arch" "Failed to setup architecture"
        return 1
    fi
    
    if [ "${DEBUG:-}" = "1" ]; then
        log_tool "$arch" "DEBUG: CC=$CC, PATH=$PATH"
    fi
    
    local log_file=""
    if [ "$LOG_ENABLED" = true ]; then
        log_file="/build/logs/build-${tool}-${arch}-$(date +%Y%m%d-%H%M%S).log"
        log_tool "$arch" "Building $tool (log: $log_file)..."
        
        if [ "${DEBUG:-}" = "1" ]; then
            log_tool "$arch" "DEBUG: Running build with verbose output..."
            (set -x; build_tool "$tool" "$arch" "$MODE") 2>&1 | tee "$log_file"
        else
            (set -x; build_tool "$tool" "$arch" "$MODE") > "$log_file" 2>&1
        fi
    else
        log_tool "$arch" "Building $tool..."
        build_tool "$tool" "$arch" "$MODE"
    fi
    
    local result=$?
    if [ $result -eq 0 ]; then
        log_tool "$arch" "✓ $tool built successfully"
        if [ "$LOG_ENABLED" = true ] && [ -n "$log_file" ]; then
            rm -f "$log_file"
            rm -f /build/logs/build-${tool}-${arch}-*.log
        fi
    else
        log_tool "$arch" "✗ $tool build failed"
        [ -n "$log_file" ] && log_tool "$arch" "Check log: $log_file"
    fi
    return $result
}

log_info "Tools: ${TOOLS_TO_BUILD[@]}"
log_info "Mode: $MODE"
log_info "Build mode: Sequential (parallel compilation within each build)"
log_info "Logging: $LOG_ENABLED"
echo

TOTAL_BUILDS=$((${#TOOLS_TO_BUILD[@]} * ${#ARCHS_TO_BUILD[@]}))
COMPLETED=0
FAILED=0
START_TIME=$(date +%s)

for tool in "${TOOLS_TO_BUILD[@]}"; do
    
    for arch in "${ARCHS_TO_BUILD[@]}"; do
        do_build "$tool" "$arch" || true
    done
    
    for arch in "${ARCHS_TO_BUILD[@]}"; do
        # Special case for shell-static which creates a directory of tools
        if [ "$tool" = "shell-static" ]; then
            if [ -d "/build/output/$arch/shell" ] && [ -n "$(ls -A /build/output/$arch/shell 2>/dev/null)" ]; then
                COMPLETED=$((COMPLETED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
        elif [ -f "/build/output/$arch/$tool" ]; then
            COMPLETED=$((COMPLETED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done
    echo
done

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
BUILD_MINS=$((BUILD_TIME / 60))
BUILD_SECS=$((BUILD_TIME % 60))

log_info "Total builds: $TOTAL_BUILDS"
log_info "Completed: $COMPLETED"
if [ $FAILED -gt 0 ]; then
    log_error "Failed: $FAILED"
else
    log_info "Failed: $FAILED"
fi
log_info "Build time: ${BUILD_MINS}m ${BUILD_SECS}s"
echo

for arch in "${ARCHS_TO_BUILD[@]}"; do
    if ls /build/output/$arch/* >/dev/null 2>&1; then
        echo "$arch:"
        # List regular files
        ls -lh /build/output/$arch/ | grep -v "^total" | grep -v "^d" | awk '{print "  " $9 " (" $5 ")"}'
        # Check for can-utils directory
        if [ -d "/build/output/$arch/can-utils" ] && [ "$(ls -A /build/output/$arch/can-utils 2>/dev/null)" ]; then
            count=$(ls -1 /build/output/$arch/can-utils | wc -l)
            echo "  can-utils/ ($count tools)"
        fi
    fi
done

if [ $FAILED -gt 0 ]; then
    echo
    for tool in "${TOOLS_TO_BUILD[@]}"; do
        for arch in "${ARCHS_TO_BUILD[@]}"; do
            if [ ! -f "/build/output/$arch/$tool" ]; then
                echo "  - $tool for $arch"
                if [ "$LOG_ENABLED" = true ]; then
                    log_file=$(ls -t /build/logs/build-${tool}-${arch}-*.log 2>/dev/null | head -1)
                    [ -n "$log_file" ] && echo "    Log: $log_file"
                fi
            fi
        done
    done
fi

# Clean up empty architecture directories
log_info "Cleaning up empty directories..."
find /build/output -type d -empty -delete 2>/dev/null || true