#!/bin/bash
# Build script for libdesock preload library
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/toolchain.sh"

LIBDESOCK_VERSION="${LIBDESOCK_VERSION:-main}"
LIBDESOCK_URL="https://github.com/f0rw4rd/libdesock/archive/refs/heads/${LIBDESOCK_VERSION}.tar.gz"

# Map our architecture names to libdesock arch names
get_desock_arch() {
    local arch="$1"
    
    case "$arch" in
        x86_64)     echo "x86_64" ;;
        aarch64*)   echo "aarch64" ;;
        arm*)       echo "arm" ;;
        i486)       echo "i386" ;;
        mips64*)    echo "mips64" ;;
        mips32*)    echo "mips" ;;
        mipsn32*)   echo "mipsn32" ;;
        ppc64le)    echo "powerpc64" ;;
        ppc32*|powerpc*) echo "powerpc" ;;
        riscv64)    echo "riscv64" ;;
        s390x)      echo "s390x" ;;
        sh4)        echo "sh" ;;
        microblaze*) echo "microblaze" ;;
        nios2|openrisc) echo "or1k" ;;
        arcle)      echo "or1k" ;;  # Closest match
        m68k)       echo "m68k" ;;
        sparc64)    echo "powerpc64" ;; # Closest match
        riscv32)    echo "riscv64" ;;   # Use riscv64 for riscv32
        *)          echo "x86_64" ;;     # Default fallback
    esac
}

build_libdesock() {
    local arch="$1"
    local output_dir="/build/output-preload/glibc/$arch"
    local build_dir="/tmp/libdesock-build-${arch}-$$"
    
    # Check if already built
    if [ -f "$output_dir/libdesock.so" ]; then
        log "libdesock.so already built for $arch"
        return 0
    fi
    
    log "Building libdesock for $arch..."
    
    # Ensure toolchain exists
    ensure_toolchain "$arch" || {
        log_error "Toolchain not available for $arch"
        return 1
    }
    
    # Setup toolchain paths
    local toolchain_dir=$(get_toolchain_dir "$arch")
    local cross_compile=$(get_toolchain_prefix "$arch")
    local CC="${toolchain_dir}/bin/${cross_compile}-gcc"
    
    # Check if gcc exists, if not try to find the actual binary
    if [ ! -x "$CC" ]; then
        # Try to find any gcc in the toolchain bin directory
        local actual_gcc=$(find "${toolchain_dir}/bin" -name "*-gcc" -type f -executable | grep -v ".br_real" | head -1)
        if [ -n "$actual_gcc" ]; then
            CC="$actual_gcc"
            log_debug "Using gcc: $CC"
        else
            log_error "No gcc found in ${toolchain_dir}/bin"
            return 1
        fi
    fi
    
    # Download source if needed
    local source_dir="/build/sources"
    mkdir -p "$source_dir"
    
    # Use a different filename for the fork to avoid cache conflicts
    local source_file="$source_dir/libdesock-f0rw4rd-${LIBDESOCK_VERSION}.tar.gz"
    if [ ! -f "$source_file" ]; then
        log "Downloading libdesock source from f0rw4rd fork..."
        wget -q "$LIBDESOCK_URL" -O "$source_file" || {
            log_error "Failed to download libdesock"
            return 1
        }
    fi
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Extract source
    tar xzf "$source_file"
    # Handle both tag (v2.0) and branch (main) naming
    if [ -d "libdesock-${LIBDESOCK_VERSION}" ]; then
        cd "libdesock-${LIBDESOCK_VERSION}"
    else
        cd "libdesock-main"
    fi
    
    # No need to apply patch when using the fixed fork branch
    
    # Get architecture for libdesock
    local desock_arch=$(get_desock_arch "$arch")
    
    # Get interpreter path for glibc
    local interpreter="/lib/ld-linux-x86-64.so.2"  # Default for x86_64
    case "$arch" in
        x86_64)     interpreter="/lib64/ld-linux-x86-64.so.2" ;;
        i486)       interpreter="/lib/ld-linux.so.2" ;;
        aarch64*)   interpreter="/lib/ld-linux-aarch64.so.1" ;;
        arm*)       interpreter="/lib/ld-linux-armhf.so.3" ;;
        mips64*)    interpreter="/lib64/ld.so.1" ;;
        mips*)      interpreter="/lib/ld.so.1" ;;
        ppc64le)    interpreter="/lib64/ld64.so.2" ;;
        ppc32*)     interpreter="/lib/ld.so.1" ;;
        riscv64)    interpreter="/lib/ld-linux-riscv64-lp64d.so.1" ;;
        riscv32)    interpreter="/lib32/ld-linux-riscv32-ilp32d.so.1" ;;
        s390x)      interpreter="/lib/ld64.so.1" ;;
        *)          interpreter="/lib/ld.so.1" ;;  # Generic fallback
    esac
    
    # Build flags from meson.build
    local CFLAGS="-fPIC -O2 -fomit-frame-pointer -fno-stack-protector -Wall -Wextra -fvisibility=hidden"
    CFLAGS="$CFLAGS -DDESOCKARCH=\"$desock_arch\""
    CFLAGS="$CFLAGS -DFD_TABLE_SIZE=128"
    CFLAGS="$CFLAGS -DINTERPRETER=\"$interpreter\""
    CFLAGS="$CFLAGS -DDESOCK_CONNECT -DDESOCK_BIND"
    CFLAGS="$CFLAGS -DMULTI_REQUEST"
    CFLAGS="$CFLAGS -DMAX_CONNS=16"
    CFLAGS="$CFLAGS -DREQUEST_DELIMITER=\"-=^..^=-\""
    CFLAGS="$CFLAGS -DSHARED"
    CFLAGS="$CFLAGS -Isrc/include -Isrc/include/arch/$desock_arch"
    
    # Add architecture-specific compatibility flags
    case "$arch" in
        s390x|riscv*|nios2|openrisc|arcle|sparc64)
            # These architectures might not have old syscalls
            CFLAGS="$CFLAGS -D_GNU_SOURCE"
            ;;
    esac
    
    local LDFLAGS="-shared -Wl,-e,__libdesock_main -lpthread"
    
    # Source files
    local sources="src/main.c src/desock.c src/stub_sockaddr.c src/syscall.c \
                   src/accept.c src/bind.c src/connect.c src/socket.c \
                   src/listen.c src/close.c src/test_helper.c src/dup.c \
                   src/getpeername.c src/getsockname.c src/epoll.c src/hooks.c \
                   src/multi.c src/peekbuffer.c src/poll.c src/read.c \
                   src/select.c src/sendfile.c src/shutdown.c src/sockopt.c \
                   src/write.c"
    
    # Compile all sources into one command
    log "Compiling libdesock..."
    $CC $CFLAGS $sources $LDFLAGS -o libdesock.so || {
        log_error "Compilation failed"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Copy library
    mkdir -p "$output_dir"
    cp libdesock.so "$output_dir/"
    
    # Strip if possible
    local strip_cmd="${toolchain_dir}/bin/${cross_compile}-strip"
    if [ ! -x "$strip_cmd" ]; then
        # Try to find strip command
        strip_cmd=$(find "${toolchain_dir}/bin" -name "*-strip" -type f -executable | head -1)
    fi
    if [ -x "$strip_cmd" ]; then
        $strip_cmd "$output_dir/libdesock.so" 2>/dev/null || true
    fi
    
    # Get size
    local size=$(ls -lh "$output_dir/libdesock.so" | awk '{print $5}')
    log "Successfully built libdesock.so for $arch ($size)"
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    return 0
}

# Main
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <architecture|all>"
        echo "Architectures: x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x"
        echo "             aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el"
        echo "             riscv32 microblazeel microblazebe nios2 openrisc arcle m68k"
        exit 1
    fi
    
    arch="$1"
    
    if [ "$arch" = "all" ]; then
        # Build for all architectures
        for a in x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x \
                 aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el \
                 riscv32 microblazeel microblazebe nios2 openrisc arcle m68k; do
            build_libdesock "$a" || echo "Failed to build for $a"
        done
    else
        build_libdesock "$arch"
    fi
fi