#!/bin/bash

# Don't exit on errors - we want to test all binaries
set -uo pipefail

# Script to verify binaries using QEMU user-mode emulation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
OUTPUT_DIR="${OUTPUT_DIR:-output}"
ARCH_FILTER=""
TOOL_FILTER=""
VERBOSE=false

# Architecture to QEMU binary mapping
declare -A QEMU_MAP=(
    ["arm32v5le"]="qemu-arm-static"
    ["arm32v5lehf"]="qemu-arm-static"
    ["arm32v7le"]="qemu-arm-static"
    ["arm32v7lehf"]="qemu-arm-static"
    ["armeb"]="qemu-armeb-static"
    ["armv6"]="qemu-arm-static"
    ["armv7m"]="qemu-arm-static"
    ["armv7r"]="qemu-arm-static"
    ["aarch64"]="qemu-aarch64-static"
    ["i486"]="qemu-i386-static"
    ["ix86le"]="qemu-i386-static"
    ["x86_64"]="qemu-x86_64-static"
    ["mips32v2le"]="qemu-mipsel-static"
    ["mips32v2be"]="qemu-mips-static"
    ["mipsn32"]="qemu-mipsn32-static"
    ["mipsn32el"]="qemu-mipsn32el-static"
    ["mips64le"]="qemu-mips64el-static"
    ["mips64n32"]="qemu-mipsn32-static"
    ["mips64n32el"]="qemu-mipsn32el-static"
    ["ppc32be"]="qemu-ppc-static"
    ["powerpcle"]="qemu-ppcle-static"
    ["powerpc64"]="qemu-ppc64-static"
    ["ppc64le"]="qemu-ppc64le-static"
    ["sh2"]="qemu-sh4-static"
    ["sh2eb"]="qemu-sh4eb-static"
    ["sh4"]="qemu-sh4-static"
    ["sh4eb"]="qemu-sh4eb-static"
    ["microblaze"]="qemu-microblaze-static"
    ["microblazeel"]="qemu-microblazeel-static"
    ["or1k"]="qemu-or1k-static"
    ["m68k"]="qemu-m68k-static"
    ["s390x"]="qemu-s390x-static"
    ["riscv32"]="qemu-riscv32-static"
    ["riscv64"]="qemu-riscv64-static"
    ["aarch64_be"]="qemu-aarch64_be-static"
    ["mips64"]="qemu-mips64-static"
)

# Test commands for each tool
declare -A TEST_COMMANDS=(
    ["bash"]="--version"
    ["busybox"]="--help"
    ["gdb"]="--version"
    ["gdb-slim"]="--version"
    ["gdb-full"]="--version"
    ["gdbserver"]="--version"
    ["ncat"]="--version"
    ["ncat-ssl"]="--version"
    ["socat"]="-V"
    ["socat-ssl"]="-V"
    ["strace"]="-V"
    ["tcpdump"]="--version"
    ["nmap"]="--version"
    ["dropbear"]="-V"
    ["dbclient"]="-V"
    ["dropbearkey"]="-V"
    ["scp"]="-h"
)

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Verify statically compiled binaries using QEMU user-mode emulation.

Options:
    -a, --arch ARCH     Verify only binaries for specific architecture
    -t, --tool TOOL     Verify only specific tool across all architectures
    -v, --verbose       Show detailed output including test command results
    -h, --help          Show this help message

Examples:
    $0                          # Verify all binaries
    $0 --arch x86_64           # Verify only x86_64 binaries
    $0 --tool strace           # Verify only strace binaries
    $0 --arch aarch64 --verbose # Verify aarch64 binaries with verbose output

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--arch)
            ARCH_FILTER="$2"
            shift 2
            ;;
        -t|--tool)
            TOOL_FILTER="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check if QEMU is installed
check_qemu_installed() {
    local arch="$1"
    local qemu_bin="${QEMU_MAP[$arch]}"
    
    if [[ -z "$qemu_bin" ]]; then
        echo -e "${YELLOW}Warning: No QEMU mapping for architecture $arch${NC}"
        return 1
    fi
    
    if ! command -v "$qemu_bin" &> /dev/null; then
        echo -e "${YELLOW}Warning: $qemu_bin not installed for $arch${NC}"
        return 1
    fi
    
    return 0
}

# Get native architecture
get_native_arch() {
    case "$(uname -m)" in
        x86_64) echo "x86_64" ;;
        aarch64) echo "aarch64" ;;
        armv7*) echo "arm32v7le" ;;
        armv6*) echo "armv6" ;;
        i?86) echo "ix86le" ;;
        *) echo "unknown" ;;
    esac
}

# Check if binary is statically linked
check_static() {
    local binary="$1"
    
    # Follow symlinks to get the actual file
    if [[ -L "$binary" ]]; then
        binary=$(readlink -f "$binary")
    fi
    
    if file "$binary" 2>/dev/null | grep -qE "(statically linked|static-pie linked)"; then
        return 0
    else
        return 1
    fi
}

# Test binary execution
test_binary() {
    local binary="$1"
    local arch="$2"
    local tool="$3"
    local native_arch=$(get_native_arch)
    
    # Get test command for this tool
    local test_cmd="${TEST_COMMANDS[$tool]}"
    if [[ -z "$test_cmd" ]]; then
        test_cmd="--version"
    fi
    
    # Execute binary
    local output
    local exit_code
    
    if [[ "$arch" == "$native_arch" ]] || [[ "$native_arch" == "unknown" ]]; then
        # Run natively
        if $VERBOSE; then
            echo -e "${BLUE}Running natively: $binary $test_cmd${NC}"
        fi
        output=$(timeout 5 "$binary" $test_cmd 2>&1) && exit_code=$? || exit_code=$?
    else
        # Run with QEMU
        local qemu_bin="${QEMU_MAP[$arch]}"
        if [[ -z "$qemu_bin" ]] || ! command -v "$qemu_bin" &> /dev/null; then
            echo -e "${YELLOW}SKIP${NC} (QEMU not available)"
            return 2
        fi
        
        if $VERBOSE; then
            echo -e "${BLUE}Running with $qemu_bin: $binary $test_cmd${NC}"
        fi
        output=$(timeout 5 "$qemu_bin" "$binary" $test_cmd 2>&1) && exit_code=$? || exit_code=$?
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}PASS${NC}"
        if $VERBOSE && [[ -n "$output" ]]; then
            echo "$output" | head -5
        fi
        return 0
    elif [[ $exit_code -eq 124 ]]; then
        echo -e "${YELLOW}TIMEOUT${NC}"
        if $VERBOSE && [[ -n "$output" ]]; then
            echo "$output" | head -5
        fi
        return 3
    else
        echo -e "${RED}FAIL${NC} (exit code: $exit_code)"
        if $VERBOSE && [[ -n "$output" ]]; then
            echo "$output" | head -5
        fi
        return 1
    fi
}

# Main verification function
verify_binaries() {
    local total=0
    local passed=0
    local failed=0
    local skipped=0
    
    echo -e "${BLUE}=== Binary Verification with QEMU ===${NC}"
    echo -e "Native architecture: $(get_native_arch)"
    echo
    
    # Find all architectures
    local architectures=()
    if [[ -n "$ARCH_FILTER" ]]; then
        architectures=("$ARCH_FILTER")
    else
        for dir in "$OUTPUT_DIR"/*; do
            if [[ -d "$dir" ]]; then
                architectures+=("$(basename "$dir")")
            fi
        done
    fi
    
    # Verify binaries
    for arch in "${architectures[@]}"; do
        local arch_dir="$OUTPUT_DIR/$arch"
        
        if [[ ! -d "$arch_dir" ]]; then
            echo -e "${YELLOW}Warning: Directory $arch_dir not found${NC}"
            continue
        fi
        
        echo -e "${BLUE}Architecture: $arch${NC}"
        
        # Check QEMU availability for this architecture
        if [[ "$(get_native_arch)" != "$arch" ]] && ! check_qemu_installed "$arch"; then
            echo -e "${YELLOW}Skipping $arch - QEMU not available${NC}"
            echo
            continue
        fi
        
        # Find all binaries in this architecture
        for binary in "$arch_dir"/*; do
            # Skip directories but follow symlinks to check if they're executable
            if [[ -d "$binary" && ! -L "$binary" ]]; then
                continue
            fi
            
            if [[ -x "$binary" ]]; then
                local tool=$(basename "$binary")
                
                # Apply tool filter if specified
                if [[ -n "$TOOL_FILTER" ]] && [[ "$tool" != "$TOOL_FILTER" ]]; then
                    continue
                fi
                
                printf "  %-20s " "$tool:"
                total=$((total + 1))
                
                # Check if statically linked
                if ! check_static "$binary"; then
                    echo -e "${RED}FAIL${NC} (not statically linked)"
                    failed=$((failed + 1))
                    continue
                fi
                
                # Test execution
                test_binary "$binary" "$arch" "$tool"
                case $? in
                    0) passed=$((passed + 1)) ;;
                    1) failed=$((failed + 1)) ;;
                    2) skipped=$((skipped + 1)) ;;
                    3) failed=$((failed + 1)) ;;  # Timeout counts as failure
                esac
            fi
        done
        
        echo
    done
    
    # Summary
    echo -e "${BLUE}=== Summary ===${NC}"
    echo "Total binaries tested: $total"
    echo -e "Passed: ${GREEN}$passed${NC}"
    echo -e "Failed: ${RED}$failed${NC}"
    echo -e "Skipped: ${YELLOW}$skipped${NC}"
    
    if [[ $failed -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Install QEMU packages hint
show_qemu_install_hint() {
    echo -e "${YELLOW}=== QEMU Installation Hint ===${NC}"
    echo "To test all architectures, install QEMU user-mode emulation:"
    echo
    echo "Ubuntu/Debian:"
    echo "  sudo apt-get install qemu-user-static"
    echo
    echo "Fedora/RHEL:"
    echo "  sudo dnf install qemu-user-static"
    echo
    echo "Arch Linux:"
    echo "  sudo pacman -S qemu-user-static"
    echo
}

# Main execution
main() {
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        echo -e "${RED}Error: Output directory $OUTPUT_DIR not found${NC}"
        exit 1
    fi
    
    # Check if any QEMU is installed
    local qemu_found=false
    for qemu in "${QEMU_MAP[@]}"; do
        if command -v "$qemu" &> /dev/null; then
            qemu_found=true
            break
        fi
    done
    
    if ! $qemu_found; then
        echo -e "${YELLOW}Warning: No QEMU user-mode emulators found${NC}"
        show_qemu_install_hint
        echo
    fi
    
    verify_binaries
}

main "$@"