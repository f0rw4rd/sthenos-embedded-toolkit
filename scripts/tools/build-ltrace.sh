#!/bin/bash
# Build script for ltrace (glibc static build)
# Note: This is the first glibc-based static tool in the toolkit
set -e

# Load common functions - handle both musl and glibc environments
if [ -f "${SCRIPT_DIR}/lib/common.sh" ]; then
    source "${SCRIPT_DIR}/lib/common.sh"
elif [ -f "${SCRIPT_DIR}/preload/lib/common.sh" ]; then
    source "${SCRIPT_DIR}/preload/lib/common.sh"
else
    # Basic logging if common.sh not found
    log() { echo "[$(date +%H:%M:%S)] $*"; }
    log_error() { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; }
fi

TOOL_NAME="ltrace"
TOOL_VERSION="0.7.3-git"  # Using git version for latest fixes

# Tool-specific functions
download_source() {
    local arch="$1"
    
    if [ ! -f "sources/${TOOL_NAME}-${TOOL_VERSION}.tar.gz" ]; then
        echo "[$(date +%H:%M:%S)] Downloading ltrace source..."
        
        # Clone from git for latest version with fixes
        cd sources
        if [ ! -d "ltrace" ]; then
            git clone https://gitlab.com/cespedes/ltrace.git
        fi
        cd ltrace
        git fetch --all
        git checkout master
        git pull
        
        # Create tarball with correct directory name
        cd ..
        mv ltrace "${TOOL_NAME}-${TOOL_VERSION}"
        tar czf "${TOOL_NAME}-${TOOL_VERSION}.tar.gz" "${TOOL_NAME}-${TOOL_VERSION}"/
        mv "${TOOL_NAME}-${TOOL_VERSION}" ltrace
        cd ..
    fi
    
    # Extract to architecture-specific directory
    echo "[$(date +%H:%M:%S)] Extracting ltrace source for $arch..."
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    mkdir -p "$arch_build_dir"
    cd "$arch_build_dir"
    
    # Extract the tarball
    tar xzf "$SOURCES_DIR/${TOOL_NAME}-${TOOL_VERSION}.tar.gz"
    
    # The tarball might extract to different directory names
    if [ -d "ltrace-temp" ]; then
        mv ltrace-temp "${TOOL_NAME}-${TOOL_VERSION}"
    elif [ -d "ltrace" ]; then
        mv ltrace "${TOOL_NAME}-${TOOL_VERSION}"
    elif [ ! -d "${TOOL_NAME}-${TOOL_VERSION}" ]; then
        echo "[$(date +%H:%M:%S)] ERROR: Failed to extract ltrace source" >&2
        echo "[$(date +%H:%M:%S)] Looking for extracted directory..." >&2
        ls -la | grep -E "^d" >&2
        return 1
    fi
}

configure_build() {
    local arch="$1"
    local build_dir="$2"
    
    # The source was extracted to architecture-specific subdirectory
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    if [ ! -d "$src_dir" ]; then
        echo "[$(date +%H:%M:%S)] ERROR: Source directory not found: $src_dir" >&2
        echo "[$(date +%H:%M:%S)] Contents of arch build dir:" >&2
        ls -la "$arch_build_dir" >&2
        return 1
    fi
    
    cd "$src_dir"
    
    # Ensure we're in the right directory
    if [ ! -f "configure.ac" ] && [ ! -f "autogen.sh" ]; then
        echo "[$(date +%H:%M:%S)] ERROR: Not in ltrace source directory" >&2
        echo "[$(date +%H:%M:%S)] Current directory: $(pwd)" >&2
        echo "[$(date +%H:%M:%S)] Contents:" >&2
        ls -la >&2
        return 1
    fi
    
    # Run autogen if needed
    if [ ! -f "configure" ]; then
        echo "[$(date +%H:%M:%S)] Running autogen.sh..."
        # Use system autotools, not the ones from toolchain
        PATH="/usr/bin:/bin:$PATH" bash ./autogen.sh || {
            echo "[$(date +%H:%M:%S)] ERROR: autogen.sh failed" >&2
            return 1
        }
    fi
    
    # Get toolchain paths
    local toolchain_name="${CC%-gcc}"
    local toolchain_dir="/build/toolchains-preload/${toolchain_name}"
    local sysroot="${toolchain_dir}/sysroot"
    
    # Build static dependencies first if needed
    build_static_deps "$arch"
    
    # Return to ltrace source directory after building deps
    cd "$src_dir"
    
    # Configure for static build
    # Note: We disable libunwind to simplify the build
    CFLAGS="-static -O2 -g -I${DEPS_PREFIX}/include -I${sysroot}/usr/include" \
    LDFLAGS="-static -L${DEPS_PREFIX}/lib -L${sysroot}/usr/lib" \
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
        echo "[$(date +%H:%M:%S)] ERROR: Configure failed" >&2
        return 1
    }
}

build_static_deps() {
    local arch="$1"
    
    # Check if we already built deps
    if [ -f "${DEPS_PREFIX}/lib/libelf.a" ] && [ -f "${DEPS_PREFIX}/lib/libz.a" ]; then
        echo "[$(date +%H:%M:%S)] Static dependencies already built"
        return 0
    fi
    
    echo "[$(date +%H:%M:%S)] Building static libelf..."
    
    # Build zlib first
    cd "$BUILD_DIR"
    if [ ! -f "$SOURCES_DIR/zlib-1.3.tar.gz" ]; then
        wget -O "$SOURCES_DIR/zlib-1.3.1.tar.gz" \
            "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"
    fi
    
    tar xf "$SOURCES_DIR/zlib-1.3.1.tar.gz"
    cd zlib-1.3.1
    
    # Configure and build zlib
    CC="${CC}" CFLAGS="-O2 -g" ./configure --prefix="${DEPS_PREFIX}" --static || {
        echo "[$(date +%H:%M:%S)] ERROR: zlib configure failed" >&2
        return 1
    }
    make -j$(nproc)
    make install
    
    # Download and build libelf
    cd "$BUILD_DIR"
    if [ ! -f "$SOURCES_DIR/elfutils-0.189.tar.bz2" ]; then
        wget -O "$SOURCES_DIR/elfutils-0.189.tar.bz2" \
            "https://sourceware.org/elfutils/ftp/0.189/elfutils-0.189.tar.bz2"
    fi
    
    tar xf "$SOURCES_DIR/elfutils-0.189.tar.bz2"
    cd elfutils-0.189
    
    # Configure elfutils for static build with zlib
    CFLAGS="-O2 -g -I${DEPS_PREFIX}/include" \
    LDFLAGS="-L${DEPS_PREFIX}/lib" \
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
        echo "[$(date +%H:%M:%S)] ERROR: elfutils configure failed" >&2
        return 1
    }
    
    # Build only libelf
    make -C lib
    make -C libelf
    make -C libelf install
    
    cd "$BUILD_DIR"
    rm -rf elfutils-0.189
}

build_tool() {
    local arch="$1"
    local build_dir="$2"
    
    # Use architecture-specific directory
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    cd "$src_dir"
    
    # Build everything first with verbose output
    make V=1 -j$(nproc) || true  # Allow it to fail at linking stage
    
    # Check if we have the necessary files
    if [ ! -f "main.o" ] || [ ! -f ".libs/libltrace.a" ]; then
        echo "[$(date +%H:%M:%S)] ERROR: Required object files not built" >&2
        return 1
    fi
    
    # Create a stub demangle.c that provides dummy functions
    cat > demangle_stub.c << 'EOF'
/* Stub implementation to avoid C++ dependency */
#include <stdlib.h>
#include <string.h>

char *my_demangle(const char *function_name) {
    /* Just return a copy of the original name without demangling */
    if (!function_name) return NULL;
    return strdup(function_name);
}
EOF
    
    # Compile the stub
    ${CC} -c demangle_stub.c -o demangle_stub.o
    
    # Remove original demangle.o and add our stub
    ${AR} d .libs/libltrace.a demangle.o 2>/dev/null || true
    ${AR} r .libs/libltrace.a demangle_stub.o
    
    # Manually link ltrace statically without C++ dependencies
    echo "[$(date +%H:%M:%S)] Attempting static link..."
    ${CC} -static -o ltrace main.o .libs/libltrace.a sysdeps/.libs/libos.a \
        -L${DEPS_PREFIX}/lib -lelf -lz -lpthread -lm || {
        echo "[$(date +%H:%M:%S)] ERROR: Manual linking failed" >&2
        return 1
    }
}

install_tool() {
    local arch="$1"
    local build_dir="$2"
    local install_dir="$3"
    
    # Use architecture-specific directory
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    cd "$src_dir"
    
    # Install the binary
    install -D -m 755 ltrace "$install_dir/ltrace"
    
    # Verify it's static
    if ! file "$install_dir/ltrace" | grep -q "statically linked"; then
        echo "[$(date +%H:%M:%S)] ERROR: Binary is not statically linked!" >&2
        # Show what it's linked against
        ldd "$install_dir/ltrace" || true
        return 1
    fi
    
    # Strip the binary
    "${STRIP}" "$install_dir/ltrace" || true
}

# Main build function
main() {
    local arch="$1"
    
    # Create build directory
    local build_name="${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    rm -rf "${BUILD_DIR}/${build_name}"
    mkdir -p "${BUILD_DIR}/${build_name}"
    
    # Download source
    download_source "$arch"
    
    # Configure
    echo "[$(date +%H:%M:%S)] Configuring ${TOOL_NAME} for ${arch}..."
    if ! configure_build "$arch" "${BUILD_DIR}/${build_name}"; then
        echo "[$(date +%H:%M:%S)] ERROR: Configuration failed" >&2
        return 1
    fi
    
    # Build
    echo "[$(date +%H:%M:%S)] Building ${TOOL_NAME} for ${arch}..."
    if ! build_tool "$arch" "${BUILD_DIR}/${build_name}"; then
        echo "[$(date +%H:%M:%S)] ERROR: Build failed" >&2
        return 1
    fi
    
    # Install
    echo "[$(date +%H:%M:%S)] Installing ${TOOL_NAME} for ${arch}..."
    if ! install_tool "$arch" "${BUILD_DIR}/${build_name}" "${OUTPUT_DIR}/${arch}"; then
        echo "[$(date +%H:%M:%S)] ERROR: Installation failed" >&2
        return 1
    fi
    
    echo "[$(date +%H:%M:%S)] ${TOOL_NAME} built successfully for ${arch}"
    return 0
}