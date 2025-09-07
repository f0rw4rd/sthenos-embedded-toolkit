#!/bin/bash
set -euo pipefail

# Only set SCRIPT_DIR if not already set (e.g., when sourced)
if [ -z "${SCRIPT_DIR:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Ensure we're in the preload directory, not lib
if [[ "$SCRIPT_DIR" == */lib ]]; then
    SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"
fi

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/toolchain.sh"

LIBDESOCK_VERSION="${LIBDESOCK_VERSION:-main}"
LIBDESOCK_URL="https://github.com/f0rw4rd/libdesock/archive/refs/heads/${LIBDESOCK_VERSION}.tar.gz"

get_desock_arch() {
    local arch="$1"
    
    case "$arch" in
        x86_64)     echo "x86_64" ;;
        aarch64*)   echo "aarch64" ;;
        arm*)       echo "arm" ;;
        i486)       echo "i386" ;;
        mips64*)    echo "mips64" ;;
        mips32*|mips32v2*) echo "mips" ;;
        mipsn32*)   echo "mipsn32" ;;
        ppc64le)    echo "powerpc64" ;;
        ppc32*|powerpc*) echo "powerpc" ;;
        riscv64)    echo "riscv64" ;;
        s390x)      echo "s390x" ;;
        sh4)        echo "sh" ;;
        microblaze*) echo "microblaze" ;;
        nios2|openrisc) echo "or1k" ;;
        arcle)      echo "or1k" ;;
        m68k)       echo "m68k" ;;
        sparc64)    echo "powerpc64" ;;
        riscv32)    echo "riscv64" ;;
        *)          echo "x86_64" ;;
    esac
}

build_libdesock() {
    local arch="$1"
    local output_dir="/build/output-preload/glibc/$arch"
    local build_dir="/tmp/libdesock-build-${arch}-$$"
    
    if [ -f "$output_dir/libdesock.so" ]; then
        log "libdesock.so already built for $arch"
        return 0
    fi
    
    log "Building libdesock for $arch..."
    
    ensure_toolchain "$arch" || {
        log_error "Toolchain not available for $arch"
        return 1
    }
    
    local toolchain_dir=$(get_toolchain_dir "$arch")
    local cross_compile=$(get_toolchain_prefix "$arch")
    local CC="${toolchain_dir}/bin/${cross_compile}-gcc"
    
    if [ ! -x "$CC" ]; then
        local actual_gcc=$(find "${toolchain_dir}/bin" -name "*-gcc" -type f -executable | grep -v ".br_real" | head -1)
        if [ -n "$actual_gcc" ]; then
            CC="$actual_gcc"
            log_debug "Using gcc: $CC"
        else
            log_error "No gcc found in ${toolchain_dir}/bin"
            return 1
        fi
    fi
    
    local source_dir="/build/sources"
    mkdir -p "$source_dir"
    
    local source_file="$source_dir/libdesock-f0rw4rd-${LIBDESOCK_VERSION}.tar.gz"
    if [ ! -f "$source_file" ]; then
        log "Downloading libdesock source from f0rw4rd fork..."
        wget -q "$LIBDESOCK_URL" -O "$source_file" || {
            log_error "Failed to download libdesock"
            return 1
        }
    fi
    
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    tar xzf "$source_file"
    if [ -d "libdesock-${LIBDESOCK_VERSION}" ]; then
        cd "libdesock-${LIBDESOCK_VERSION}"
    else
        cd "libdesock-main"
    fi
    
    
    local desock_arch=$(get_desock_arch "$arch")
    
    local interpreter="/lib/ld-linux-x86-64.so.2"
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
        *)          interpreter="/lib/ld.so.1" ;;
    esac
    
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
    
    case "$arch" in
        s390x|riscv*|nios2|openrisc|arcle|sparc64)
            CFLAGS="$CFLAGS -D_GNU_SOURCE"
            ;;
    esac
    
    local LDFLAGS="-shared -Wl,-e,__libdesock_main -lpthread"
    
    local sources="src/main.c src/desock.c src/stub_sockaddr.c src/syscall.c \
                   src/accept.c src/bind.c src/connect.c src/socket.c \
                   src/listen.c src/close.c src/test_helper.c src/dup.c \
                   src/getpeername.c src/getsockname.c src/epoll.c src/hooks.c \
                   src/multi.c src/peekbuffer.c src/poll.c src/read.c \
                   src/select.c src/sendfile.c src/shutdown.c src/sockopt.c \
                   src/write.c"
    
    log "Compiling libdesock..."
    $CC $CFLAGS $sources $LDFLAGS -o libdesock.so || {
        log_error "Compilation failed"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    mkdir -p "$output_dir"
    cp libdesock.so "$output_dir/"
    
    local strip_cmd="${toolchain_dir}/bin/${cross_compile}-strip"
    if [ ! -x "$strip_cmd" ]; then
        strip_cmd=$(find "${toolchain_dir}/bin" -name "*-strip" -type f -executable | head -1)
    fi
    if [ -x "$strip_cmd" ]; then
        $strip_cmd "$output_dir/libdesock.so" 2>/dev/null || true
    fi
    
    local size=$(ls -lh "$output_dir/libdesock.so" | awk '{print $5}')
    log "Successfully built libdesock.so for $arch ($size)"
    
    cd /
    rm -rf "$build_dir"
    
    return 0
}

build_libdesock_musl() {
    local arch="$1"
    local output_dir="/build/output-preload/musl/$arch"
    local build_dir="/tmp/libdesock-musl-build-${arch}-$$"
    
    if [ -f "$output_dir/libdesock.so" ]; then
        log "libdesock.so already built for $arch (musl)"
        return 0
    fi
    
    log "Building libdesock for $arch with musl..."
    
    # Source logging functions if not already sourced
    if ! type log >/dev/null 2>&1; then
        source "/build/scripts/lib/logging.sh"
    fi
    
    # Get musl toolchain prefix
    local prefix=""
    case "$arch" in
        x86_64)      prefix="x86_64-linux-musl" ;;
        aarch64)     prefix="aarch64-linux-musl" ;;
        aarch64be|aarch64_be) prefix="aarch64_be-linux-musl" ;;
        arm32v7le)   prefix="armv7l-linux-musleabihf" ;;
        i486)        prefix="i486-linux-musl" ;;
        ix86le)      prefix="i686-linux-musl" ;;
        mips32v2le)  prefix="mipsel-linux-musl" ;;
        mips32v2be)  prefix="mips-linux-musl" ;;
        mips32v2lesf) prefix="mipsel-linux-muslsf" ;;
        mips32v2besf) prefix="mips-linux-muslsf" ;;
        ppc32be)     prefix="powerpc-linux-musl" ;;
        ppc32besf)   prefix="powerpc-linux-muslsf" ;;
        powerpcle)   prefix="powerpcle-linux-musl" ;;
        powerpclesf) prefix="powerpcle-linux-muslsf" ;;
        mips64le)    prefix="mips64el-linux-musl" ;;
        ppc64le)     prefix="powerpc64le-linux-musl" ;;
        riscv64)     prefix="riscv64-linux-musl" ;;
        s390x)       prefix="s390x-linux-musl" ;;
        mips64)      prefix="mips64-linux-musl" ;;
        armv5)       prefix="arm-linux-musleabi" ;;
        armv6)       prefix="armv6-linux-musleabihf" ;;
        sparc64)     prefix="sparc64-linux-musl" ;;
        sh4)         prefix="sh4-linux-musl" ;;
        mips32)      prefix="mips-linux-musl" ;;
        mips32el)    prefix="mipsel-linux-musl" ;;
        riscv32)     prefix="riscv32-linux-musl" ;;
        microblazeel) prefix="microblazeel-linux-musl" ;;
        microblazebe) prefix="microblaze-linux-musl" ;;
        nios2)       prefix="nios2-linux-musl" ;;
        openrisc)    prefix="or1k-linux-musl" ;;
        arcle)       prefix="arc-linux-musl" ;;
        m68k)        prefix="m68k-linux-musl" ;;
        *)           log "Unknown architecture: $arch"; return 1 ;;
    esac
    
    local toolchain_dir="/build/toolchains/${prefix}-cross"
    if [ ! -d "$toolchain_dir" ]; then
        log_error "Musl toolchain not found for $arch"
        return 1
    fi
    
    local CC="${toolchain_dir}/bin/${prefix}-gcc"
    
    if [ ! -x "$CC" ]; then
        log_error "Compiler not found: $CC"
        return 1
    fi
    
    local export_str="export CC='$CC' PATH='${toolchain_dir}/bin:$PATH'"
    eval "$export_str"
    
    mkdir -p "$output_dir"
    
    # Download source if needed
    local source_dir="/build/sources"
    mkdir -p "$source_dir"
    
    local source_file="$source_dir/libdesock-f0rw4rd-${LIBDESOCK_VERSION}.tar.gz"
    if [ ! -f "$source_file" ]; then
        log "Downloading libdesock source from f0rw4rd fork..."
        wget -q "$LIBDESOCK_URL" -O "$source_file" || {
            log_error "Failed to download libdesock"
            return 1
        }
    fi
    
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    tar xzf "$source_file"
    if [ -d "libdesock-${LIBDESOCK_VERSION}" ]; then
        cd "libdesock-${LIBDESOCK_VERSION}"
    else
        cd "libdesock-main"
    fi
    
    local desock_arch=$(get_desock_arch "$arch")
    
    # Musl-specific flags - include the include directory and architecture-specific headers
    local CFLAGS="-fPIC -O2 -Wall -DDESOCK_ARCH_$desock_arch -DTRANSPARENT"
    CFLAGS="$CFLAGS -I./src/include -I./src/include/arch/$desock_arch"
    # Add required defines
    CFLAGS="$CFLAGS -DMAX_CONNS=16 -DFD_TABLE_SIZE=1024"
    # Add desock client/server defines - need both for musl build
    CFLAGS="$CFLAGS -D'desock_client=1' -D'desock_server=1'"
    # Add musl-specific defines to fix type conflicts
    CFLAGS="$CFLAGS -D_GNU_SOURCE"
    local LDFLAGS="-shared -Wl,-e,__libdesock_main -lpthread -static-libgcc"
    
    local sources="src/main.c src/desock.c src/stub_sockaddr.c src/syscall.c \
                   src/accept.c src/bind.c src/connect.c src/socket.c \
                   src/listen.c src/close.c src/test_helper.c src/dup.c \
                   src/getpeername.c src/getsockname.c src/epoll.c src/hooks.c \
                   src/multi.c src/peekbuffer.c src/poll.c src/read.c \
                   src/select.c src/sendfile.c src/shutdown.c src/sockopt.c \
                   src/write.c"
    
    log "Compiling libdesock with musl..."
    $CC $CFLAGS $sources $LDFLAGS -o libdesock.so || {
        log_error "Compilation failed"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    cp libdesock.so "$output_dir/"
    
    local strip_cmd="${toolchain_dir}/bin/${prefix}-strip"
    if [ -x "$strip_cmd" ]; then
        $strip_cmd "$output_dir/libdesock.so" 2>/dev/null || true
    fi
    
    local size=$(ls -lh "$output_dir/libdesock.so" | awk '{print $5}')
    log "Successfully built libdesock.so for $arch with musl ($size)"
    
    cd /
    rm -rf "$build_dir"
    
    return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <architecture|all>"
        echo "             aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el"
        echo "             riscv32 microblazeel microblazebe nios2 openrisc arcle m68k"
        exit 1
    fi
    
    arch="$1"
    
    if [ "$arch" = "all" ]; then
        for a in x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x \
                 aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el \
                 riscv32 microblazeel microblazebe nios2 openrisc arcle m68k; do
            build_libdesock "$a" || log_error "Failed to build for $a"
        done
    else
        build_libdesock "$arch"
    fi
fi