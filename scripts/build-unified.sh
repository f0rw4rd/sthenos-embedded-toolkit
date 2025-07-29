#!/bin/bash
set -e

# Unified build script for all tools and architectures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/tools.sh"

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
  $0 strace arm32v5le              # Build strace for ARM
  $0 all ix86le                     # Build all tools for x86
  $0 gdbserver all --mode embedded # Build gdbserver for all archs with embedded optimization
  $0 busybox all                   # Build busybox for all architectures

EOF
    exit 0
}

# Default values
MODE="standard"
# Parallel builds removed - now sequential per architecture
LOG_ENABLED=false
TOOL=""
ARCH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -p|--parallel)
            # Deprecated option - ignore
            echo "Warning: --parallel option is deprecated. Builds are sequential per architecture."
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
                echo "Error: Too many arguments"
                usage
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$TOOL" ] || [ -z "$ARCH" ]; then
    echo "Error: Missing required arguments"
    usage
fi

# All architectures
ALL_ARCHS=(
    # ARM 32-bit
    arm32v5le arm32v5lehf arm32v7le arm32v7lehf armeb armv6 armv7m armv7r
    # ARM 64-bit
    aarch64 aarch64_be
    # x86
    i486 ix86le x86_64
    # MIPS
    mips32v2le mips32v2be mipsn32 mipsn32el mips64 mips64le mips64n32 mips64n32el
    # PowerPC
    ppc32be powerpcle powerpc64 ppc64le
    # SuperH
    sh2 sh2eb sh4 sh4eb
    # Others
    microblaze microblazeel or1k m68k s390x
    # RISC-V
    riscv32 riscv64
)

# All tools
ALL_TOOLS=(strace busybox busybox_nodrop bash socat socat-ssl ncat ncat-ssl tcpdump gdbserver gdb nmap dropbear)

# Determine what to build
if [ "$TOOL" = "all" ]; then
    TOOLS_TO_BUILD=("${ALL_TOOLS[@]}")
else
    TOOLS_TO_BUILD=("$TOOL")
fi

if [ "$ARCH" = "all" ]; then
    ARCHS_TO_BUILD=("${ALL_ARCHS[@]}")
else
    ARCHS_TO_BUILD=("$ARCH")
fi

# Create log directory if needed
if [ "$LOG_ENABLED" = true ]; then
    mkdir -p /build/logs
fi

# Build function
do_build() {
    local tool=$1
    local arch=$2
    
    if ! setup_arch "$arch"; then
        echo "[$arch] Failed to setup architecture"
        return 1
    fi
    
    # Debug: Show environment for troubleshooting
    if [ "${DEBUG:-}" = "1" ]; then
        echo "[$arch] DEBUG: CC=$CC, PATH=$PATH"
    fi
    
    local log_file=""
    if [ "$LOG_ENABLED" = true ]; then
        log_file="/build/logs/build-${tool}-${arch}-$(date +%Y%m%d-%H%M%S).log"
        echo "[$arch] Building $tool (log: $log_file)..."
        
        if [ "${DEBUG:-}" = "1" ]; then
            # In debug mode, output to both log file and stdout/stderr
            echo "[$arch] DEBUG: Running build with verbose output..."
            (set -x; build_tool "$tool" "$arch" "$MODE") 2>&1 | tee "$log_file"
        else
            # Normal mode - only to log file
            (set -x; build_tool "$tool" "$arch" "$MODE") > "$log_file" 2>&1
        fi
    else
        echo "[$arch] Building $tool..."
        build_tool "$tool" "$arch" "$MODE"
    fi
    
    local result=$?
    if [ $result -eq 0 ]; then
        echo "[$arch] ✓ $tool built successfully"
        # Remove logs for successful builds
        if [ "$LOG_ENABLED" = true ] && [ -n "$log_file" ]; then
            rm -f "$log_file"
            # Also remove any old logs for this successful tool/arch combination
            rm -f /build/logs/build-${tool}-${arch}-*.log
        fi
    else
        echo "[$arch] ✗ $tool build failed"
        [ -n "$log_file" ] && echo "[$arch] Check log: $log_file"
    fi
    return $result
}

# Build summary
echo "=== Build Configuration ==="
echo "Tools: ${TOOLS_TO_BUILD[@]}"
echo "Architectures: ${ARCHS_TO_BUILD[@]}"
echo "Mode: $MODE"
echo "Build mode: Sequential per architecture, parallel compilation"
echo "Logging: $LOG_ENABLED"
echo "=========================="
echo

# Build statistics
TOTAL_BUILDS=$((${#TOOLS_TO_BUILD[@]} * ${#ARCHS_TO_BUILD[@]}))
COMPLETED=0
FAILED=0
START_TIME=$(date +%s)

# Build all combinations
for tool in "${TOOLS_TO_BUILD[@]}"; do
    echo "=== Building $tool ==="
    
    # Sequential build per architecture
    for arch in "${ARCHS_TO_BUILD[@]}"; do
        # Build directly (not in background)
        # Continue on failure instead of exiting
        do_build "$tool" "$arch" || true
    done
    
    # Count results
    for arch in "${ARCHS_TO_BUILD[@]}"; do
        if [ -f "/build/output/$arch/$tool" ]; then
            COMPLETED=$((COMPLETED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done
    echo
done

# Calculate build time
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
BUILD_MINS=$((BUILD_TIME / 60))
BUILD_SECS=$((BUILD_TIME % 60))

# Final summary
echo "=== Build Summary ==="
echo "Total builds: $TOTAL_BUILDS"
echo "Completed: $COMPLETED"
echo "Failed: $FAILED"
echo "Build time: ${BUILD_MINS}m ${BUILD_SECS}s"
echo

# List all built binaries
echo "=== Built Binaries ==="
for arch in "${ARCHS_TO_BUILD[@]}"; do
    if ls /build/output/$arch/* >/dev/null 2>&1; then
        echo "$arch:"
        ls -lh /build/output/$arch/ | grep -v "^total" | awk '{print "  " $9 " (" $5 ")"}'
    fi
done

# List failed builds if any
if [ $FAILED -gt 0 ]; then
    echo
    echo "=== Failed Builds ==="
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