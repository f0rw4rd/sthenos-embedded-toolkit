#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/shared_lib_helpers.sh"

TOOL_NAME="libdesock"
LIBDESOCK_URL="https://github.com/f0rw4rd/libdesock/archive/refs/heads/master.tar.gz"
LIBDESOCK_SHA512="4668cb5697bad73747cb972f0b3ba8742eb71133c24e1b6022aa35476d057e6010d594ec45ce50d5e0deb2c9c323801ddd2a88e740a7f11951903b89611eb3c9"

get_desock_arch() {
    local arch="$1"
    
    case "$arch" in
        x86_64)     echo "x86_64" ;;
        i486|ix86le) echo "i386" ;;
        aarch64*)   echo "aarch64" ;;
        arm*)       echo "arm" ;;
        mips64*)    echo "mips64" ;;
        mips*)      echo "mips" ;;
        ppc64*)     echo "ppc64" ;;
        ppc*)       echo "ppc" ;;
        s390x)      echo "s390x" ;;
        riscv64)    echo "riscv64" ;;
        riscv32)    echo "riscv32" ;;
        *)          echo "$arch" ;;
    esac
}

# Main execution when called as script
main() {
    local arch="${1:-}"
    
    if [ -z "$arch" ]; then
        echo "Usage: $0 <arch>"
        exit 1
    fi
    
    arch=$(map_arch_name "$arch")
    
    # Check if toolchain is available
    if ! check_toolchain_availability "$arch"; then
        return 2
    fi
    
    # Check if already built
    if check_shared_library_exists "$arch" "libdesock"; then
        return 0
    fi
    
    log "Building libdesock for $arch..."
    
    local output_dir="${STATIC_OUTPUT_DIR:-/build/output}/$arch/shared/${LIBC_TYPE:-musl}"
    local output_file="$output_dir/libdesock.so"
    mkdir -p "$output_dir"
    
    # Setup toolchain
    if ! setup_shared_toolchain "$arch"; then
        return 1
    fi
    
    local desock_arch=$(get_desock_arch "$arch")
    
    local build_dir="/tmp/build-libdesock-${arch}-${LIBC_TYPE:-musl}-$$"
    mkdir -p "$build_dir"
    
    log "Downloading and extracting libdesock..."
    if ! download_and_extract "$LIBDESOCK_URL" "$build_dir" 1 "$LIBDESOCK_SHA512"; then
        log_error "Failed to download and extract libdesock"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    cd "$build_dir"
    
    local interpreter=""
    case "$arch" in
        x86_64)     interpreter="/lib64/ld-linux-x86-64.so.2" ;;
        i486|ix86le) interpreter="/lib/ld-linux.so.2" ;;
        aarch64*)   interpreter="/lib/ld-linux-aarch64.so.1" ;;
        arm*)       interpreter="/lib/ld-linux-armhf.so.3" ;;
        mips64*)    interpreter="/lib64/ld.so.1" ;;
        mips*)      interpreter="/lib/ld.so.1" ;;
        ppc64*)     interpreter="/lib64/ld64.so.2" ;;
        ppc*)       interpreter="/lib/ld.so.1" ;;
        s390x)      interpreter="/lib/ld64.so.1" ;;
        riscv64)    interpreter="/lib/ld-linux-riscv64-lp64d.so.1" ;;
        riscv32)    interpreter="/lib/ld-linux-riscv32-ilp32d.so.1" ;;
        *)          interpreter="/lib/ld-linux.so.2" ;;
    esac
    
    local cflags=$(get_compile_flags "$arch" "shared" "")
    local ldflags=$(get_link_flags "$arch" "shared")
    
    cflags="$cflags -DFD_TABLE_SIZE=128 -DMAX_CONNS=128 -DSHARED"
    
    local arch_dir=""
    case "$arch" in
        x86_64)     arch_dir="x86_64" ;;
        i486|ix86le) arch_dir="i386" ;;
        aarch64*)   arch_dir="aarch64" ;;
        arm*)       arch_dir="arm" ;;
        mips64*)    arch_dir="mips64" ;;
        mipsn32*)   arch_dir="mipsn32" ;;
        mips*)      arch_dir="mips" ;;
        ppc64*)     arch_dir="ppc64" ;;
        ppc*)       arch_dir="ppc" ;;
        s390x)      arch_dir="s390x" ;;
        riscv64)    arch_dir="riscv64" ;;
        riscv32)    arch_dir="riscv32" ;;
        *)          arch_dir="generic" ;;
    esac
    
    # Check if there's an architecture-specific source file
    local source_file="src/libdesock.c"
    if [ -f "arch/$arch_dir/libdesock.c" ]; then
        source_file="arch/$arch_dir/libdesock.c"
        log "Using architecture-specific source for $arch_dir"
    fi
    
    log "Compiling libdesock..."
    
    if ! $CC $cflags -DINTERP_PATH=\"$interpreter\" -c "$source_file" -o libdesock.o 2>&1; then
        log_error "Compilation failed"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    log "Linking libdesock.so..."
    if ! $CC $ldflags -o libdesock.so libdesock.o -ldl 2>&1; then
        log_error "Linking failed"
        cleanup_build_dir "$build_dir"
        return 1
    fi
    
    log "Stripping libdesock.so..."
    $STRIP libdesock.so 2>/dev/null || true
    
    log "Copying to output directory..."
    cp libdesock.so "$output_file"
    
    cleanup_build_dir "$build_dir"
    
    local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
    log "Successfully built: $output_file ($size)"
    
    return 0
}

# Execute main function with all arguments
main "$@"