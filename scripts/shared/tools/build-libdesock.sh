#!/bin/bash
# Build script for libdesock shared library
# Simplified to reuse central toolchain infrastructure

LIBDESOCK_URL="https://github.com/f0rw4rd/libdesock/archive/refs/heads/master.tar.gz"

# Get architecture name for libdesock
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

# Build libdesock for an architecture
build_libdesock() {
    local arch="$1"
    local log_enabled="${2:-true}"
    local debug="${3:-0}"
    
    # Map architecture name
    arch=$(map_arch_name "$arch")
    
    # Check if this architecture supports the current libc type
    if [ "$LIBC_TYPE" = "musl" ]; then
        local musl_name=$(get_musl_toolchain "$arch")
        if [ -z "$musl_name" ]; then
            log_debug "Skipping libdesock for $arch - no musl toolchain available"
            return 2  # Special return code for skipped
        fi
    else
        local glibc_name=$(get_glibc_toolchain "$arch")
        if [ -z "$glibc_name" ]; then
            log_debug "Skipping libdesock for $arch - no glibc toolchain available"
            return 2  # Special return code for skipped
        fi
    fi
    
    # Set output directory using new structure
    local output_dir="$STATIC_OUTPUT_DIR/$arch/shared/$LIBC_TYPE"
    local output_file="$output_dir/libdesock.so"
    
    # Check if already built
    if [ -f "$output_file" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
        log "libdesock.so already built for $arch ($size)"
        return 0
    fi
    
    log "Building libdesock for $arch..."
    
    # Ensure output directory exists
    mkdir -p "$output_dir"
    
    if [ "$LIBC_TYPE" = "glibc" ]; then
        # For glibc, add toolchain to PATH
        local toolchain_name=$(get_glibc_toolchain "$arch")
        if [ -z "$toolchain_name" ]; then
            log_error "No glibc toolchain for $arch (this shouldn't happen)"
            return 1
        fi
        
        local toolchain_dir="$GLIBC_TOOLCHAINS_DIR/$toolchain_name"
        if [ ! -d "$toolchain_dir" ]; then
            log_error "Toolchain not found at $toolchain_dir"
            return 1
        fi
        
        export PATH="$toolchain_dir/bin:$PATH"
        export CC="${toolchain_name}-gcc"
        export STRIP="${toolchain_name}-strip"
    else
        # For musl, setup standard environment
        if ! setup_arch "$arch"; then
            log_error "Failed to setup musl toolchain for $arch"
            return 1
        fi
    fi
    
    # Map architecture name for libdesock
    local desock_arch=$(get_desock_arch "$arch")
    
    # Create build directory
    local build_dir="/tmp/build-libdesock-${arch}-${LIBC_TYPE}-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    source "$BASE_DIR/scripts/lib/build_helpers.sh"
    log "Downloading libdesock..."
    if ! download_source "libdesock" "unknown" "$LIBDESOCK_URL"; then
        log_error "Failed to download libdesock"
        cd /
        rm -rf "$build_dir"
        return 1
    fi
    
    # Copy from central source location to build directory
    local filename=$(basename "$LIBDESOCK_URL")
    cp "/build/sources/$filename" "libdesock.tar.gz"
    
    # Extract
    if ! tar xzf libdesock.tar.gz; then
        log_error "Failed to extract libdesock"
        cd /
        rm -rf "$build_dir"
        return 1
    fi
    
    # Enter the extracted directory (GitHub uses 'main' branch now, not 'master')
    if ! cd libdesock-main 2>/dev/null && ! cd libdesock-master 2>/dev/null && ! cd libdesock-*; then
        log_error "Failed to find extracted libdesock directory"
        cd /
        rm -rf "$build_dir"
        return 1
    fi
    
    # Get the dynamic linker path for the target architecture
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
    
    # Get compile and link flags
    local cflags=$(get_compile_flags "$arch" "shared" "")
    local ldflags=$(get_link_flags "$arch" "shared")
    
    # Add libdesock-specific defines
    cflags="$cflags -DFD_TABLE_SIZE=128 -DMAX_CONNS=128 -DSHARED"
    
    # Setup architecture-specific syscall header
    local arch_dir=""
    case "$arch" in
        x86_64)     arch_dir="x86_64" ;;
        i486|ix86le) arch_dir="i386" ;;
        aarch64*)   arch_dir="aarch64" ;;
        arm*)       arch_dir="arm" ;;
        mips64*)    arch_dir="mips64" ;;
        mipsn32*)   arch_dir="mipsn32" ;;
        mips*)      arch_dir="mips" ;;
        ppc64*)     arch_dir="powerpc64" ;;
        ppc32*) arch_dir="powerpc" ;;
        s390x)      arch_dir="s390x" ;;
        riscv64)    arch_dir="riscv64" ;;
        microblaze*) arch_dir="microblaze" ;;
        or1k)       arch_dir="or1k" ;;
        m68k)       arch_dir="m68k" ;;
        sh*)        arch_dir="sh" ;;
        *)          
            log_error "Unsupported architecture for libdesock: $arch"
            cd /
            rm -rf "$build_dir"
            return 1
            ;;
    esac
    
    # Copy the architecture-specific syscall header
    if [ -f "src/include/arch/$arch_dir/syscall_arch.h" ]; then
        cp "src/include/arch/$arch_dir/syscall_arch.h" "src/include/"
    else
        log_error "Architecture header not found: src/include/arch/$arch_dir/syscall_arch.h"
        cd /
        rm -rf "$build_dir"
        return 1
    fi
    
    # Compile all source files
    log "Compiling libdesock source files..."
    local obj_files=""
    for src_file in src/*.c; do
        # Skip test_helper.c as it's for tests only
        if [[ "$src_file" == *"test_helper.c" ]]; then
            continue
        fi
        
        local obj_file="${src_file%.c}.o"
        obj_file=$(basename "$obj_file")
        
        if ! $CC $cflags -Isrc/include -c "$src_file" -o "$obj_file"; then
            log_error "Failed to compile $src_file"
            cd /
            rm -rf "$build_dir"
            return 1
        fi
        obj_files="$obj_files $obj_file"
    done
    
    # Link all object files
    log "Linking libdesock.so..."
    if ! $CC $ldflags -o libdesock.so $obj_files -ldl -lpthread; then
        log_error "Linking failed"
        cd /
        rm -rf "$build_dir"
        return 1
    fi
    
    # Strip
    $STRIP libdesock.so 2>/dev/null || true
    
    # Copy to output directory
    cp libdesock.so "$output_file"
    
    local size=$(ls -lh "$output_file" | awk '{print $5}')
    log "Successfully built libdesock.so for $arch ($size)"
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    return 0
}