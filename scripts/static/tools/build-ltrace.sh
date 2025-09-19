#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../../lib/logging.sh"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"

TOOL_NAME="ltrace"
TOOL_VERSION="0.7.3"
LTRACE_URL="http://www.ltrace.org/ltrace_0.7.3.orig.tar.bz2"

download_ltrace_source() {
    local arch="$1"
    
    log_tool "$(date +%H:%M:%S)" "Starting ltrace download for $arch..."
    
    source "$(dirname "${BASH_SOURCE[0]}")/../../lib/build_helpers.sh"
    
    if ! download_source "$TOOL_NAME" "$TOOL_VERSION" "$LTRACE_URL"; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to download ltrace source" >&2
        return 1
    fi
    
    log_tool "$(date +%H:%M:%S)" "Extracting ltrace source for $arch..."
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    mkdir -p "$arch_build_dir"
    cd "$arch_build_dir"
    
    tar xjf "/build/sources/ltrace_0.7.3.orig.tar.bz2"
    
    if [ ! -d "${TOOL_NAME}-${TOOL_VERSION}" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to extract ltrace source" >&2
        return 1
    fi
}

apply_patches() {
    local src_dir="$1"
    cd "$src_dir"
    
    log_tool "$(date +%H:%M:%S)" "Applying Alpine patches for musl compatibility..."
    
    local patches_dir="/build/patches/ltrace"
    if [ -d "$patches_dir" ]; then
        for patch_file in "$patches_dir"/*.patch; do
            if [ -f "$patch_file" ]; then
                patch_name=$(basename "$patch_file")
                log_tool "$(date +%H:%M:%S)" "Applying $patch_name..."
                patch -p1 < "$patch_file" || {
                    log_tool "$(date +%H:%M:%S)" "WARNING: Failed to apply $patch_name"
                }
            fi
        done
    fi
    
    # Run autoreconf to regenerate configure (following Alpine)
    log_tool "$(date +%H:%M:%S)" "Running autoreconf..."
    aclocal && autoconf && automake --add-missing --force || {
        log_tool "$(date +%H:%M:%S)" "ERROR: autoreconf failed" >&2
        return 1
    }
}

build_musl_dependencies() {
    local arch="$1"
    local toolchain_name="${CC%-gcc}"

    local cflags=$(get_compile_flags "$arch" "static" "$dep_name")
    local ldflags=$(get_link_flags "$arch" "static")
    
    log_tool "$(date +%H:%M:%S)" "Building musl dependencies for $arch..."
    
    # Build musl-fts
    export FTS_DIR=$(build_musl_fts_cached "$arch") || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build musl-fts" >&2
        return 1
    }
    
    # Build musl-obstack  
    export OBSTACK_DIR=$(build_musl_obstack_cached "$arch") || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build musl-obstack" >&2
        return 1
    }
    
    # Build argp-standalone
    export ARGP_DIR=$(build_argp_standalone_cached "$arch") || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build argp-standalone" >&2
        return 1
    }
    
    # Build zlib
    export ZLIB_DIR=$(build_zlib_cached "$arch") || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build zlib" >&2
        return 1
    }
    
    # 4. Build elfutils with musl patches - keeping inline for troubleshooting
    log_tool "$(date +%H:%M:%S)" "Building elfutils..."
    cd "$BUILD_DIR"
    
    # First try to use cached version
    export LIBELF_DIR="/build/deps-cache/$arch/elfutils-0.193"
    if [ -f "$LIBELF_DIR/lib/libelf.a" ]; then
        log_tool "$(date +%H:%M:%S)" "Using cached elfutils from $LIBELF_DIR"
    else
        # Build from source for troubleshooting
        download_source "elfutils" "0.193" "https://sourceware.org/elfutils/ftp/0.193/elfutils-0.193.tar.bz2" || return 1
        tar xf "$SOURCES_DIR/elfutils-0.193.tar.bz2"
        cd elfutils-0.193
        
        # Apply Alpine patches for musl
        if [ -d "/build/patches/elfutils" ]; then
            for patch_file in /build/patches/elfutils/*.patch; do
                if [ -f "$patch_file" ]; then
                    log_tool "$(date +%H:%M:%S)" "Applying $(basename "$patch_file")..."
                    patch -p1 < "$patch_file" || true
                fi
            done
        fi

        # Get host triplet
        local host_triplet
        host_triplet=$(${CC} -dumpmachine) || host_triplet="${toolchain_name}"
        
        # Get proper compile and link flags
        local cflags=$(get_compile_flags "$arch" "static" "elfutils")
        local ldflags=$(get_link_flags "$arch" "static")
        
        # Configure elfutils with minimal dependencies to avoid issues
        CC="${CC}" \
        CFLAGS="$cflags -I${FTS_DIR}/include -I${OBSTACK_DIR}/include -I${ARGP_DIR}/include -I${ZLIB_DIR}/include" \
        CPPFLAGS="-I${FTS_DIR}/include -I${OBSTACK_DIR}/include -I${ARGP_DIR}/include -I${ZLIB_DIR}/include" \
        LDFLAGS="$ldflags -L${FTS_DIR}/lib -L${OBSTACK_DIR}/lib -L${ARGP_DIR}/lib -L${ZLIB_DIR}/lib" \
        ./configure \
            --prefix="${LIBELF_DIR}" \
            --disable-debuginfod \
            --disable-libdebuginfod \
            --disable-symbol-versioning \
            --disable-nls \
            --without-bzlib \
            --without-lzma \
            --without-zstd \
            --disable-demangler \
            --program-prefix="" \
            --host="${host_triplet}" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Configure failed" >&2       
        cat config.log 
        return 1
    }
        
        # Build and install only what we need with the required libs
        make -C lib -j$(nproc) LIBS="-largp -lfts -lobstack -lz" || true
        make -C libelf -j$(nproc) LIBS="-largp -lfts -lobstack -lz"
        
        # Install to cache directory
        mkdir -p "${LIBELF_DIR}/lib" "${LIBELF_DIR}/include"
        make -C libelf install
    fi
    
    # Check if libelf.a was created
    if [ -f "${LIBELF_DIR}/lib/libelf.a" ]; then
        log_tool "$(date +%H:%M:%S)" "libelf.a successfully created at ${LIBELF_DIR}/lib/libelf.a"
        ls -la "${LIBELF_DIR}/lib/libelf.a"
    else
        log_tool "$(date +%H:%M:%S)" "ERROR: libelf.a not created!"
        echo "Looking for libelf.a in build directory..."
        find . -name "libelf.a" -type f 2>/dev/null
        echo "Checking what's in ${LIBELF_DIR}/lib/:"
        ls -la "${LIBELF_DIR}/lib/"
        # Exit here to debug elfutils
        exit 1
    fi
    
    log_tool "$(date +%H:%M:%S)" "Dependencies built successfully"
}


configure_build() {
    local arch="$1"
    local build_dir="$2"
    
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    cd "$src_dir"
    
    local toolchain_name="${CC%-gcc}"
    
    # Determine host triplet - use generic linux-gnu for musl to avoid config.sub issues
    local host_triplet
    if echo "${CC}" | grep -q "musl"; then
        case "${toolchain_name}" in
            x86_64-*) host_triplet="x86_64-pc-linux-gnu" ;;
            i*86-*) host_triplet="i686-pc-linux-gnu" ;;
            arm-*) host_triplet="arm-linux-gnueabi" ;;
            aarch64-*) host_triplet="aarch64-linux-gnu" ;;
            *) host_triplet="${toolchain_name%-musl}-linux-gnu" ;;
        esac
    else
        host_triplet="${toolchain_name}"
    fi
    
    # Get proper compile and link flags
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    # Alpine only needs elfutils - try minimal dependencies first
    local include_dirs="-I${LIBELF_DIR}/include"
    local lib_dirs="-L${LIBELF_DIR}/lib"
    
    # Configure ltrace with minimal flags (Alpine-style)
    CFLAGS="$cflags $include_dirs" \
    LDFLAGS="$ldflags $lib_dirs" \
    ./configure \
        --host="${host_triplet}" \
        --prefix=/usr \
        --sysconfdir=/etc \
        --disable-werror \
        CC="${CC}" \
        AR="${AR}" \
        STRIP="${STRIP}" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Configure failed" >&2       
        cat config.log 
        return 1
    }
}

perform_build() {
    local arch="$1"
    local output_file="$2"
    
    log_tool "$(date +%H:%M:%S)" "Building ltrace for $arch..."
    
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    cd "$src_dir"
    
    # Get dependency paths
    local elfutils_dir="/build/deps-cache/$arch/elfutils-0.193"
    local zlib_dir="/build/deps-cache/$arch/zlib-1.3.1"

    CFLAGS="$cflags $include_dirs" \
    LDFLAGS="$ldflags $lib_dirs" \   
    make -j$(nproc) || {
        # Standard build failed - try manual linking to avoid libtool issues
        log_tool "$(date +%H:%M:%S)" "Standard build failed, attempting manual link..."
        
        # Check if required files exist
        if [ ! -f "main.o" ] || [ ! -f ".libs/libltrace.a" ]; then
            log_tool "$(date +%H:%M:%S)" "ERROR: Required object files not found" >&2
            return 1
        fi
        
        # Manual link with full paths to static libraries
        # Include -no-pie to match the compilation flags
        # Note: Order matters! libltrace needs libelf, libelf needs libz
        ${CC} -static -no-pie -o ltrace main.o \
            ./.libs/libltrace.a \
            sysdeps/.libs/libos.a \
            ${elfutils_dir}/lib/libelf.a \
            ${zlib_dir}/lib/libz.a \
            -lstdc++ -lm -lpthread || {
            
            # If that fails, try without C++ demangling support
            log_tool "$(date +%H:%M:%S)" "Trying without C++ demangling..."
            ${CC} -static -no-pie -o ltrace main.o \
                ./.libs/libltrace.a \
                sysdeps/.libs/libos.a \
                ${elfutils_dir}/lib/libelf.a \
                ${zlib_dir}/lib/libz.a \
                -lm -lpthread || {
                log_tool "$(date +%H:%M:%S)" "ERROR: Manual linking failed" >&2
                return 1
            }
        }
    }
    
    # Strip and copy binary
    ${STRIP} ltrace
    cp ltrace "$output_file"
    
    # Verify it's actually static
    if ! file ltrace | grep -q "statically linked"; then
        log_tool "$(date +%H:%M:%S)" "WARNING: Binary may not be fully static"
        ldd ltrace || true
    fi
    
    log_tool "$(date +%H:%M:%S)" "ltrace built successfully for $arch"
}

# Main build function
build_ltrace() {
    local arch="$1"
    
    log_tool "$(date +%H:%M:%S)" "Starting ltrace build for $arch..."
    
    # Check if we're building with musl
    local is_musl=false
    if echo "${CC}" | grep -q "musl"; then
        is_musl=true
    fi
    
    # Download and extract source
    if ! download_ltrace_source "$arch"; then
        return 1
    fi
    
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local src_dir="${arch_build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    # Apply patches
    if ! apply_patches "$src_dir"; then
        return 1
    fi
    
    # Build dependencies for musl
    if [ "$is_musl" = "true" ]; then
        if ! build_musl_dependencies "$arch"; then
            log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build dependencies" >&2
            return 1
        fi
    fi
    
    # Configure
    if ! configure_build "$arch" "$arch_build_dir"; then
        return 1
    fi
    
    # Build
    local output_file="${OUTPUT_DIR}/${arch}/${TOOL_NAME}"
    mkdir -p "${OUTPUT_DIR}/${arch}"
    
    if ! perform_build "$arch" "$output_file"; then
        return 1
    fi
    
    return 0
}

# Entry point
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <architecture> [test-deps]"
    exit 1
fi

# Add test mode for debugging dependencies
if [ "$2" = "test-deps" ] || [ "${TEST_DEPS_ONLY:-}" = "1" ]; then
    echo "=== Test mode: Building dependencies only ==="
    arch="$1"
    
    # Check environment
    echo "Environment:"
    echo "  CC: ${CC}"
    echo "  AR: ${AR}"
    echo "  BUILD_DIR: ${BUILD_DIR}"
    echo "  SOURCES_DIR: ${SOURCES_DIR}"
    echo "  DEPS_PREFIX: ${DEPS_PREFIX}"
    
    # Test compiler
    echo ""
    echo "Testing compiler..."
    echo 'int main(){return 0;}' > /tmp/test.c
    if ${CC} /tmp/test.c -o /tmp/test; then
        echo "  ✓ Compiler works: ${CC}"
    else
        echo "  ✗ Compiler failed!"
        exit 1
    fi
    
    # Build only dependencies
    if build_musl_dependencies "$arch"; then
        echo ""
        echo "=== Dependencies built successfully! ==="
        echo "Checking installed files:"
        echo ""
        echo "Libraries in ${DEPS_PREFIX}/${arch}/lib:"
        ls -la "${DEPS_PREFIX}/${arch}/lib/" 2>/dev/null || echo "No lib directory"
        echo ""
        echo "Headers in ${DEPS_PREFIX}/${arch}/include:"
        ls -la "${DEPS_PREFIX}/${arch}/include/" | head -20
    else
        echo "=== Dependency build failed ==="
        exit 1
    fi
    exit 0
fi

build_ltrace "$1"