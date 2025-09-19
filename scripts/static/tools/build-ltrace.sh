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
    
    log_tool "$(date +%H:%M:%S)" "Building musl-specific dependencies for $arch..."
    
    # Build musl-fts (needed by elfutils on musl)
    build_musl_fts_cached "$arch" >/dev/null || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build musl-fts" >&2
        return 1
    }
    
    # Build musl-obstack (needed by elfutils on musl)
    build_musl_obstack_cached "$arch" >/dev/null || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build musl-obstack" >&2
        return 1
    }
    
    # Build argp-standalone (needed by elfutils on musl)
    build_argp_standalone_cached "$arch" >/dev/null || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build argp-standalone" >&2
        return 1
    }
    
    log_tool "$(date +%H:%M:%S)" "Musl dependencies built successfully"
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
    
    # Build dependencies to get proper paths
    local libelf_dir=$(build_libelf_cached "$arch") || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build elfutils for configure" >&2
        return 1
    }
    local zlib_dir=$(build_zlib_cached "$arch") || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to build zlib for configure" >&2
        return 1
    }
    
    # Set include and lib paths from cached builds
    local include_dirs="-I${libelf_dir}/include"
    local lib_dirs="-L${libelf_dir}/lib"
    
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
    cd "$src_dir"
    
    # Get proper compile and link flags
    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    # Get dependency paths from cached builds
    local elfutils_dir=$(build_libelf_cached "$arch") || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to get elfutils path" >&2
        return 1
    }
    local zlib_dir=$(build_zlib_cached "$arch") || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to get zlib path" >&2
        return 1
    }
    
    # Set include and lib paths
    local include_dirs="-I${elfutils_dir}/include"
    local lib_dirs="-L${elfutils_dir}/lib"
    
    # Build everything but let libtool linking fail, then do manual linking
    log_tool "$(date +%H:%M:%S)" "Compiling with CFLAGS: $cflags $include_dirs"
    CFLAGS="$cflags $include_dirs" \
    LDFLAGS="$ldflags $lib_dirs" \
    make -j$(nproc) || true  # Let it fail at linking stage
    
    # Check if compilation succeeded (even if linking failed)
    if [ ! -f "main.o" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: main.o not compiled" >&2
        return 1
    fi
    
    # Verify object files were built
    if [ ! -f "main.o" ] || [ ! -f ".libs/libltrace.a" ] || [ ! -f "sysdeps/.libs/libos.a" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Required object files not found" >&2
        return 1
    fi
    
    # Manual static linking with correct library order
    # Libraries must be in dependency order: app → ltrace → os → elf → z → system
    log_tool "$(date +%H:%M:%S)" "Performing manual static link..."
    ${CC} $cflags $ldflags -o ltrace \
        main.o \
        ./.libs/libltrace.a \
        sysdeps/.libs/libos.a \
        ${elfutils_dir}/lib/libelf.a \
        ${zlib_dir}/lib/libz.a \
        -lstdc++ -lm -lpthread || {
        
        # Retry without C++ demangling if libstdc++ is not available
        log_tool "$(date +%H:%M:%S)" "Retrying without C++ demangling support..."
        ${CC} $cflags $ldflags -o ltrace \
            main.o \
            ./.libs/libltrace.a \
            sysdeps/.libs/libos.a \
            ${elfutils_dir}/lib/libelf.a \
            ${zlib_dir}/lib/libz.a \
            -lm -lpthread || {
            log_tool "$(date +%H:%M:%S)" "ERROR: Static linking failed" >&2
            return 1
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