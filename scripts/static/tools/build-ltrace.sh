#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../../lib/logging.sh"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"

TOOL_NAME="ltrace"
TOOL_VERSION="0.7.3"
LTRACE_URL="http://www.ltrace.org/ltrace_0.7.3.orig.tar.bz2"

download_ltrace_source() {
    local arch="$1"
    
    log_tool "$(date +%H:%M:%S)" "Starting ltrace download for $arch..."
    
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/build_helpers.sh"
    log_tool "$(date +%H:%M:%S)" "Calling download_source with URL: $LTRACE_URL"
    
    if ! download_source "$TOOL_NAME" "$TOOL_VERSION" "$LTRACE_URL"; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to download ltrace source" >&2
        return 1
    fi
    
    log_tool "$(date +%H:%M:%S)" "Download successful, proceeding to extraction..."
    
    log_tool "$(date +%H:%M:%S)" "Extracting ltrace source for $arch..."
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    mkdir -p "$arch_build_dir"
    cd "$arch_build_dir"
    
    local source_file="/build/sources/ltrace_0.7.3.orig.tar.bz2"
    tar xjf "$source_file"
    
    # Verify extraction succeeded - tarball extracts to ltrace-0.7.3 which matches our expected name
    if [ ! -d "${TOOL_NAME}-${TOOL_VERSION}" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to extract ltrace source" >&2
        log_tool "$(date +%H:%M:%S)" "Looking for extracted directory..." >&2
        ls -la | grep -E "^d" >&2
        return 1
    fi
}

configure_build() {
    local arch="$1"
    local build_dir="$2"
    
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    if [ ! -d "$src_dir" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Source directory not found: $src_dir" >&2
        log_tool "$(date +%H:%M:%S)" "Contents of arch build dir:" >&2
        ls -la "$arch_build_dir" >&2
        return 1
    fi
    
    cd "$src_dir"
    
    if [ ! -f "configure.ac" ] && [ ! -f "autogen.sh" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Not in ltrace source directory" >&2
        log_tool "$(date +%H:%M:%S)" "Current directory: $(pwd)" >&2
        log_tool "$(date +%H:%M:%S)" "Contents:" >&2
        ls -la >&2
        return 1
    fi
    
    if [ ! -f "configure" ]; then
        log_tool "$(date +%H:%M:%S)" "Running autogen.sh..."
        PATH="/usr/bin:/bin:$PATH" bash ./autogen.sh || {
            log_tool "$(date +%H:%M:%S)" "ERROR: autogen.sh failed" >&2
            return 1
        }
    fi
    
    local toolchain_name="${CC%-gcc}"
    local toolchain_dir="$GLIBC_TOOLCHAINS_DIR/${toolchain_name}"
    local sysroot="${toolchain_dir}/sysroot"
    
    build_static_deps "$arch"
    
    cd "$src_dir"
    
    CFLAGS="${CFLAGS:-} -static -O2 -g -I${DEPS_PREFIX}/include -I${sysroot}/usr/include" \
    LDFLAGS="${LDFLAGS:-} -static -L${DEPS_PREFIX}/lib -L${sysroot}/usr/lib" \
    CPPFLAGS="-I${DEPS_PREFIX}/include -I${sysroot}/usr/include" \
    ./configure \
        --host="${toolchain_name}" \
        --prefix=/usr \
        --sysconfdir=/etc \
        --disable-shared \
        --enable-static \
        --disable-werror \
        --without-libunwind \
        --disable-demangle \
        --disable-selinux \
        CC="${CC}" \
        AR="${AR}" \
        STRIP="${STRIP}" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Configure failed" >&2
        return 1
    }
}

build_static_deps() {
    local arch="$1"
    
    if [ -f "${DEPS_PREFIX}/lib/libelf.a" ] && [ -f "${DEPS_PREFIX}/lib/libz.a" ]; then
        log_tool "$(date +%H:%M:%S)" "Static dependencies already built"
        return 0
    fi
    
    log_tool "$(date +%H:%M:%S)" "Building static libelf..."
    
    cd "$BUILD_DIR"
    download_source "zlib" "1.3.1" "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to download zlib source" >&2
        return 1
    }
    
    tar xf "$SOURCES_DIR/zlib-1.3.1.tar.gz"
    cd zlib-1.3.1
    
    CC="${CC}" CFLAGS="${CFLAGS:-} -O2 -g" ./configure --prefix="${DEPS_PREFIX}" --static || {
        log_tool "$(date +%H:%M:%S)" "ERROR: zlib configure failed" >&2
        return 1
    }
    make -j$(nproc)
    make install
    
    cd "$BUILD_DIR"
    download_source "elfutils" "0.189" "https://sourceware.org/elfutils/ftp/0.189/elfutils-0.189.tar.bz2" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to download elfutils source" >&2
        return 1
    }
    
    tar xf "$SOURCES_DIR/elfutils-0.189.tar.bz2"
    cd elfutils-0.189
    
    CFLAGS="${CFLAGS:-} -O2 -g -I${DEPS_PREFIX}/include" \
    LDFLAGS="${LDFLAGS:-} -L${DEPS_PREFIX}/lib" \
    ./configure \
        --host="${toolchain_name}" \
        --prefix="${DEPS_PREFIX}" \
        --enable-static \
        --disable-shared \
        --disable-libdebuginfod \
        --disable-debuginfod \
        --without-bzlib \
        --without-lzma \
        CC="${CC}" \
        AR="${AR}" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: elfutils configure failed" >&2
        return 1
    }
    
    make -C lib
    make -C libelf
    make -C libelf install
    
    cd "$BUILD_DIR"
    rm -rf elfutils-0.189
}

build_tool() {
    local arch="$1"
    local build_dir="$2"
    
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    cd "$src_dir"
    
    make V=1 -j$(nproc) || true
    
    if [ ! -f "main.o" ] || [ ! -f ".libs/libltrace.a" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Required object files not built" >&2
        return 1
    fi
    
    cat > demangle_stub.c << 'EOF'
/* Stub implementation to avoid C++ dependency */
#include <stddef.h>
#include <string.h>

char *my_demangle(const char *function_name) {
    /* Just return a copy of the original name without demangling */
    if (!function_name) return NULL;
    return strdup(function_name);
}
EOF
    
    ${CC} -c demangle_stub.c -o demangle_stub.o
    
    ${AR} d .libs/libltrace.a demangle.o 2>/dev/null || true
    ${AR} r .libs/libltrace.a demangle_stub.o
    
    log_tool "$(date +%H:%M:%S)" "Attempting static link..."
    ${CC} -static -o ltrace main.o .libs/libltrace.a sysdeps/.libs/libos.a \
        -L${DEPS_PREFIX}/lib -lelf -lz -lpthread -lm ${LDFLAGS:-} || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Manual linking failed" >&2
        return 1
    }
}

install_tool() {
    local arch="$1"
    local build_dir="$2"
    local install_dir="$3"
    
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    cd "$src_dir"
    
    install -D -m 755 ltrace "$install_dir/ltrace"
    
    if ! file "$install_dir/ltrace" | grep -q "statically linked"; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Binary is not statically linked!" >&2
        ldd "$install_dir/ltrace" || true
        return 1
    fi
    
    "${STRIP}" "$install_dir/ltrace" || true
}

main() {
    local arch="$1"
    
    local build_name="${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    rm -rf "${BUILD_DIR}/${build_name}"
    mkdir -p "${BUILD_DIR}/${build_name}"
    
    download_ltrace_source "$arch"
    
    log_tool "$(date +%H:%M:%S)" "Configuring ${TOOL_NAME} for ${arch}..."
    if ! configure_build "$arch" "${BUILD_DIR}/${build_name}"; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Configuration failed" >&2
        return 1
    fi
    
    log_tool "$(date +%H:%M:%S)" "Building ${TOOL_NAME} for ${arch}..."
    if ! build_tool "$arch" "${BUILD_DIR}/${build_name}"; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Build failed" >&2
        return 1
    fi
    
    log_tool "$(date +%H:%M:%S)" "Installing ${TOOL_NAME} for ${arch}..."
    if ! install_tool "$arch" "${BUILD_DIR}/${build_name}" "${OUTPUT_DIR}/${arch}"; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Installation failed" >&2
        return 1
    fi
    
    log_tool "$(date +%H:%M:%S)" "${TOOL_NAME} built successfully for ${arch}"
    return 0
}

# Script entry point
if [ $# -ne 1 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
main "$arch"