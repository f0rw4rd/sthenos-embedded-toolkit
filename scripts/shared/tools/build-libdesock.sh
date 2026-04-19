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

    # Map our arch names to libdesock upstream arch identifiers.
    # Valid upstream values (src/include/arch/*):
    #   aarch64, arm, i386, m68k, microblaze, mips, mips64, mipsn32,
    #   or1k, powerpc, powerpc64, riscv64, s390x, sh, x32, x86_64
    # Anything else should print empty so the caller can skip the arch.
    case "$arch" in
        x86_64)                         echo "x86_64" ;;
        x86_64_x32)                     echo "x32" ;;
        i486|ix86le)                    echo "i386" ;;
        aarch64|aarch64_be)             echo "aarch64" ;;
        arm*|armeb*|armel*|armv*)       echo "arm" ;;
        mips64n32|mips64n32el)          echo "mipsn32" ;;
        mips64*)                        echo "mips64" ;;
        mips32*|mips*)                  echo "mips" ;;
        ppc64*)                         echo "powerpc64" ;;
        ppc32*|ppc*)                    echo "powerpc" ;;
        s390x)                          echo "s390x" ;;
        riscv64)                        echo "riscv64" ;;
        m68k|m68k_coldfire)             echo "m68k" ;;
        microblaze|microblazeel)        echo "microblaze" ;;
        or1k)                           echo "or1k" ;;
        sh2|sh2eb|sh4|sh4eb)            echo "sh" ;;
        *)                              echo "" ;;
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

    if [ -z "$desock_arch" ]; then
        log "libdesock does not support arch $arch (no upstream syscall headers); skipping"
        return 2
    fi

    local build_dir="/tmp/build-libdesock-${arch}-${LIBC_TYPE:-musl}-$$"
    mkdir -p "$build_dir"

    log "Downloading and extracting libdesock..."
    if ! download_and_extract "$LIBDESOCK_URL" "$build_dir" 1 "$LIBDESOCK_SHA512"; then
        log_error "Failed to download and extract libdesock"
        cleanup_build_dir "$build_dir"
        return 1
    fi

    cd "$build_dir"

    # Sanity: upstream layout changed between revisions; make sure src/ exists.
    if [ ! -d "src" ] || [ ! -d "src/include/arch/$desock_arch" ]; then
        log_error "Unexpected libdesock source layout (missing src/ or arch/$desock_arch)"
        cleanup_build_dir "$build_dir"
        return 1
    fi

    # Upstream read.c/write.c declare recvmmsg/sendmmsg with `int flags`.
    # musl's sys/socket.h declares them with `unsigned int flags` (POSIX) and
    # errors on the mismatch; glibc declares `int flags` and accepts upstream
    # as-is. Only rewrite the signatures on musl so both libcs build cleanly.
    if [ "${LIBC_TYPE:-musl}" = "musl" ]; then
        sed -i \
            -e 's/int recvmmsg (int fd, struct mmsghdr\* msgvec, unsigned int vlen, int flags, struct timespec\* timeout)/int recvmmsg (int fd, struct mmsghdr* msgvec, unsigned int vlen, unsigned int flags, struct timespec* timeout)/' \
            src/read.c
        sed -i \
            -e 's/int sendmmsg (int fd, struct mmsghdr\* msgvec, unsigned int vlen, int flags)/int sendmmsg (int fd, struct mmsghdr* msgvec, unsigned int vlen, unsigned int flags)/' \
            src/write.c
    fi

    local interpreter=""
    case "$arch" in
        x86_64)                    interpreter="/lib64/ld-linux-x86-64.so.2" ;;
        x86_64_x32)                interpreter="/libx32/ld-linux-x32.so.2" ;;
        i486|ix86le)               interpreter="/lib/ld-linux.so.2" ;;
        aarch64)                   interpreter="/lib/ld-linux-aarch64.so.1" ;;
        aarch64_be)                interpreter="/lib/ld-linux-aarch64_be.so.1" ;;
        arm*|armel*|armv*)         interpreter="/lib/ld-linux-armhf.so.3" ;;
        armeb*)                    interpreter="/lib/ld-linux.so.3" ;;
        mips64n32|mips64n32el)     interpreter="/lib32/ld.so.1" ;;
        mips64*)                   interpreter="/lib64/ld.so.1" ;;
        mips*)                     interpreter="/lib/ld.so.1" ;;
        ppc64le)                   interpreter="/lib64/ld64.so.2" ;;
        ppc64*)                    interpreter="/lib64/ld64.so.1" ;;
        ppc*)                      interpreter="/lib/ld.so.1" ;;
        s390x)                     interpreter="/lib/ld64.so.1" ;;
        riscv64)                   interpreter="/lib/ld-linux-riscv64-lp64d.so.1" ;;
        m68k*)                     interpreter="/lib/ld.so.1" ;;
        microblaze*)               interpreter="/lib/ld.so.1" ;;
        or1k)                      interpreter="/lib/ld.so.1" ;;
        sh*)                       interpreter="/lib/ld-linux.so.2" ;;
        *)                         interpreter="/lib/ld-linux.so.2" ;;
    esac

    local cflags=$(get_compile_flags "$arch" "shared" "")
    local ldflags=$(get_link_flags "$arch" "shared")

    # Match meson build: include src/include and the arch-specific syscall header dir,
    # set SHARED/DESOCK_BIND, pin the interpreter path, and define DESOCKARCH so the
    # runtime can report which syscall flavor it was compiled against.
    cflags="$cflags -Isrc/include -Isrc/include/arch/$desock_arch"
    cflags="$cflags -DSHARED -DDESOCK_BIND"
    cflags="$cflags -DFD_TABLE_SIZE=128 -DMAX_CONNS=128"
    cflags="$cflags -DDESOCKARCH=\"$desock_arch\""
    cflags="$cflags -DINTERPRETER=\"$interpreter\""
    cflags="$cflags -DREQUEST_DELIMITER=\"-=^..^=-\""

    # libdesock's main.c installs __libdesock_main via -Wl,-e so the .so is also
    # runnable; it also uses pthread primitives (dependency('threads') in meson).
    ldflags="$ldflags -Wl,-e,__libdesock_main"

    local sources=(
        src/main.c src/desock.c src/stub_sockaddr.c src/syscall.c
        src/accept.c src/bind.c src/connect.c src/socket.c src/listen.c
        src/close.c src/test_helper.c src/dup.c src/getpeername.c
        src/getsockname.c src/epoll.c src/hooks.c src/multi.c
        src/peekbuffer.c src/poll.c src/read.c src/select.c
        src/sendfile.c src/shutdown.c src/sockopt.c src/write.c
    )

    log "Compiling libdesock (${#sources[@]} sources, arch=$desock_arch)..."

    local objs=()
    local s obj
    for s in "${sources[@]}"; do
        obj="${s##*/}"
        obj="${obj%.c}.o"
        if ! $CC $cflags -c "$s" -o "$obj"; then
            log_error "Compilation failed for $s"
            cleanup_build_dir "$build_dir"
            return 1
        fi
        objs+=("$obj")
    done

    log "Linking libdesock.so..."
    if ! $CC $ldflags -o libdesock.so "${objs[@]}" -lpthread -ldl; then
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