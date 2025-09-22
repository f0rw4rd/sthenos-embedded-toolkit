#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../../lib/logging.sh"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"

TOOL_NAME="ltrace"
TOOL_VERSION="0.8.1"
LTRACE_URL="https://gitlab.com/cespedes/ltrace/-/archive/0.8.1/ltrace-0.8.1.tar.gz"
LTRACE_SHA512="e508bb4640e04f8e22dc15f468ec4e84e94162fb2b6ab9d3d4e3af92970eb6b336b08a9070c1a705ea00365af6f5b077672fbf081bfd13d89be3025fff1662c4"

get_ltrace_arch() {
    local arch="$1"
    case "$arch" in
        x86_64|i*86|ix86le) echo "x86" ;;
        arm*v5*|arm*v6*|arm*v7*|armeb|armebhf|armel) echo "arm" ;;
        aarch64) echo "UNSUPPORTED" ;;  # Little-endian not supported
        aarch64_be) echo "aarch64" ;;   # Big-endian maps to aarch64
        mips*) echo "mips" ;;
        ppc*|powerpc*) echo "ppc" ;;
        s390*) echo "s390" ;;
        sparc*) echo "sparc" ;;
        riscv64*) echo "riscv64" ;;
        loongarch*) echo "loongarch" ;;
        xtensa*) echo "xtensa" ;;
        metag*) echo "metag" ;;
        alpha*) echo "alpha" ;;
        ia64*) echo "ia64" ;;
        m68k*) echo "m68k" ;;
        cris*) echo "cris" ;;
        *) echo "$arch" ;;
    esac
}

get_host_triplet() {
    local toolchain_name="${CC%-gcc}"
    
    if echo "${CC}" | grep -q "musl"; then
        case "${toolchain_name}" in
            x86_64-*) echo "x86_64-pc-linux-gnu" ;;
            i*86-*) echo "i686-pc-linux-gnu" ;;
            arm*|armv*) echo "arm-linux-gnueabi" ;;
            aarch64_be-*) echo "aarch64-linux-gnu" ;;
            aarch64-*) echo "aarch64-linux-gnu" ;;
            mips-*) echo "mips-linux-gnu" ;;
            mipsel-*) echo "mipsel-linux-gnu" ;;
            *) 
                local base="${toolchain_name%-linux-musl*}"
                echo "${base%-musl*}-linux-gnu"
                ;;
        esac
    else
        echo "${toolchain_name}"
    fi
}

build_ltrace() {
    local arch="$1"
    
    log_tool "$arch" "Starting ltrace build..."
    
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    local output_file="${OUTPUT_DIR}/${arch}/${TOOL_NAME}"
    
    if [ "${SKIP_IF_EXISTS:-true}" = "true" ] && [ -f "$output_file" ]; then
        log_tool "$arch" "ltrace already built, skipping..."
        return 0
    fi
    
    mkdir -p "$arch_build_dir"
    if ! download_and_extract "$LTRACE_URL" "$arch_build_dir" 0 "$LTRACE_SHA512"; then
        log_tool "$arch" "ERROR: Failed to download ltrace" >&2
        return 1
    fi
    
    local ltrace_arch=$(get_ltrace_arch "$arch")
    if [ "$ltrace_arch" = "UNSUPPORTED" ] || [ ! -d "$src_dir/sysdeps/linux-gnu/$ltrace_arch" ]; then
        log_tool "$arch" "ERROR: Architecture not supported by ltrace" >&2
        return 1
    fi
    
    cd "$src_dir" || {
        log_tool "$arch" "ERROR: Could not enter source directory: $src_dir" >&2
        return 1
    }
    
    local patches_dir="/build/patches/ltrace"
    if [ -d "$patches_dir" ]; then
        for patch_file in "$patches_dir"/*.patch; do
            [ -f "$patch_file" ] || continue
            log_tool "$arch" "Applying $(basename "$patch_file")..."
            patch -p1 < "$patch_file" || true
        done
    fi
    
    if [ ! -f "configure" ]; then
        log_tool "$arch" "Generating configure script..."
        mkdir -p config/m4 2>/dev/null || true
        autoreconf -fiv || {
            log_tool "$arch" "ERROR: Failed to generate configure" >&2
            return 1
        }
    fi
    
    if echo "${CC}" | grep -q "musl"; then
        log_tool "$arch" "Building musl dependencies..."
        build_musl_fts_cached "$arch" >/dev/null || return 1
        build_musl_obstack_cached "$arch" >/dev/null || return 1
        build_argp_standalone_cached "$arch" >/dev/null || return 1
    fi
    
    local elfutils_dir=$(build_libelf_cached "$arch") || return 1
    local zlib_dir=$(build_zlib_cached "$arch") || return 1
    
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    local host_triplet=$(get_host_triplet)
    
    log_tool "$arch" "Configuring ltrace..."
    cd "$src_dir" || {
        log_tool "$arch" "ERROR: Lost source directory before configure" >&2
        return 1
    }
    CFLAGS="$cflags -I${elfutils_dir}/include" \
    LDFLAGS="$ldflags -L${elfutils_dir}/lib" \
    ./configure \
        --host="${host_triplet}" \
        --prefix=/usr \
        --sysconfdir=/etc \
        --disable-werror \
        CC="${CC}" AR="${AR}" STRIP="${STRIP}" || {
        log_tool "$arch" "ERROR: Configure failed" >&2
        return 1
    }
    
    log_tool "$arch" "Building ltrace..."
    CFLAGS="$cflags -I${elfutils_dir}/include" \
    LDFLAGS="$ldflags -L${elfutils_dir}/lib" \
    make -j$(nproc) || true
    
    if [ ! -f "main.o" ] || [ ! -f ".libs/libltrace.a" ] || [ ! -f "sysdeps/.libs/libos.a" ]; then
        log_tool "$arch" "ERROR: Compilation failed" >&2
        return 1
    fi
    
    log_tool "$arch" "Linking ltrace..."
    
    local cxx_libs=""
    local toolchain_prefix="${CC%-gcc}"
    if [ -f "/build/toolchains-musl/${toolchain_prefix}-cross/${toolchain_prefix}/lib/libsupc++.a" ]; then
        cxx_libs="/build/toolchains-musl/${toolchain_prefix}-cross/${toolchain_prefix}/lib/libsupc++.a"
    elif [ -f "/build/toolchains/${toolchain_prefix}/${toolchain_prefix}/lib/libsupc++.a" ]; then
        cxx_libs="/build/toolchains/${toolchain_prefix}/${toolchain_prefix}/lib/libsupc++.a"
    fi
    
    ${CC} $cflags $ldflags -o ltrace \
        main.o \
        ./.libs/libltrace.a \
        sysdeps/.libs/libos.a \
        ${elfutils_dir}/lib/libelf.a \
        ${zlib_dir}/lib/libz.a \
        $cxx_libs \
        -lm -lpthread || {
            log_tool "$arch" "ERROR: Failed to build"
            exit 1
        }
    
    mkdir -p "${OUTPUT_DIR}/${arch}"
    ${STRIP} ltrace
    cp ltrace "$output_file"
    
    log_tool "$arch" "SUCCESS: ltrace built successfully"
    return 0
}

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

build_ltrace "$1"
