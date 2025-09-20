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

download_ltrace_source() {
    local arch="$1"
    
    log_tool "$(date +%H:%M:%S)" "Starting ltrace download for $arch..."
    
    local arch_build_dir="${BUILD_DIR}/${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    mkdir -p "$arch_build_dir"
    
    if ! download_and_extract "$LTRACE_URL" "$arch_build_dir" 0; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to download and extract ltrace source" >&2
        return 1
    fi
    
    if [ ! -d "$arch_build_dir/${TOOL_NAME}-${TOOL_VERSION}" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Expected directory ${TOOL_NAME}-${TOOL_VERSION} not found after extraction" >&2
        return 1
    fi
    
    log_tool "$(date +%H:%M:%S)" "Successfully downloaded and extracted ltrace source for $arch"
}

check_architecture_support() {
    local arch="$1"
    local src_dir="$2"
    
    log_tool "$(date +%H:%M:%S)" "Checking architecture support for $arch..."
    
    # Map architecture to ltrace sysdeps directory name
    local ltrace_arch=""
    case "$arch" in
        x86_64) ltrace_arch="x86" ;;
        i*86|ix86le) ltrace_arch="x86" ;;
        arm*v5*|arm*v7*|armeb|armv6) ltrace_arch="arm" ;;
        aarch64) 
            # ltrace 0.8.1's aarch64 directory is actually for big-endian
            # Little-endian aarch64 is not supported
            log_tool "$(date +%H:%M:%S)" "WARNING: ltrace 0.8.1 does not support little-endian aarch64" >&2
            ltrace_arch="UNSUPPORTED"
            ;;
        aarch64_be) ltrace_arch="aarch64" ;;  # aarch64 directory in ltrace is for big-endian
        mips*) ltrace_arch="mips" ;;
        ppc*|powerpc*) ltrace_arch="ppc" ;;
        s390*) ltrace_arch="s390" ;;
        sparc*) ltrace_arch="sparc" ;;
        alpha*) ltrace_arch="alpha" ;;
        ia64*) ltrace_arch="ia64" ;;
        m68k*) ltrace_arch="m68k" ;;
        cris*) ltrace_arch="cris" ;;
        riscv64*) ltrace_arch="riscv64" ;;  # Added for 0.8.1
        loongarch*) ltrace_arch="loongarch" ;;  # Added for 0.8.1
        xtensa*) ltrace_arch="xtensa" ;;  # Added for 0.8.1
        metag*) ltrace_arch="metag" ;;  # Added for 0.8.1
        *)
            log_tool "$(date +%H:%M:%S)" "WARNING: Unknown architecture mapping for $arch" >&2
            ltrace_arch="$arch"
            ;;
    esac
    
    # Check if the architecture directory exists
    if [ ! -d "$src_dir/sysdeps/linux-gnu/$ltrace_arch" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Architecture $arch (mapped to $ltrace_arch) is not supported by ltrace $TOOL_VERSION" >&2
        log_tool "$(date +%H:%M:%S)" "Available architectures in ltrace $TOOL_VERSION:" >&2
        ls -1 "$src_dir/sysdeps/linux-gnu/" 2>/dev/null | grep -v Makefile | while read -r dir; do
            [ -d "$src_dir/sysdeps/linux-gnu/$dir" ] && log_tool "$(date +%H:%M:%S)" "  - $dir" >&2
        done
        return 1
    fi
    
    log_tool "$(date +%H:%M:%S)" "Architecture $arch (mapped to $ltrace_arch) is supported"
    return 0
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
    
    # Run autoreconf to regenerate configure if configure.ac was modified by patches
    if [ -f "configure.ac" ]; then
        log_tool "$(date +%H:%M:%S)" "Running autoreconf..."
        
        # Create missing directories if needed
        mkdir -p config/m4 2>/dev/null || true
        
        # Try full autoreconf first
        if ! autoreconf -fiv 2>/dev/null; then
            # If that fails, try minimal approach
            log_tool "$(date +%H:%M:%S)" "Trying minimal autoreconf approach..."
            if ! (libtoolize --force --copy 2>/dev/null || glibtoolize --force --copy 2>/dev/null || true) && \
                 aclocal && \
                 autoheader && \
                 automake --add-missing --force-missing --copy 2>/dev/null && \
                 autoconf; then
                log_tool "$(date +%H:%M:%S)" "WARNING: autoreconf had issues, trying to continue with existing configure" >&2
                # If configure exists, we can try to continue
                if [ ! -f "configure" ]; then
                    log_tool "$(date +%H:%M:%S)" "ERROR: No configure script available" >&2
                    return 1
                fi
            fi
        fi
    fi
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
            arm-*|armv*) host_triplet="arm-linux-gnueabi" ;;  # All ARM variants including armv7l
            aarch64_be-*) host_triplet="aarch64-linux-gnu" ;;  # Big-endian aarch64 uses aarch64 triplet
            aarch64-*) host_triplet="aarch64-linux-gnu" ;;  # Little-endian (though not supported)
            mips-*) host_triplet="mips-linux-gnu" ;;
            mipsel-*) host_triplet="mipsel-linux-gnu" ;;
            *) 
                # Remove musl suffix variations and add -linux-gnu
                local base_arch="${toolchain_name%-linux-musl*}"
                base_arch="${base_arch%-musl*}"
                host_triplet="${base_arch}-linux-gnu"
                ;;
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
    make v=1 -j$(nproc) || true  # Let it fail at linking stage
    
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
    
    # Check if architecture is supported
    if ! check_architecture_support "$arch" "$src_dir"; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Skipping build - architecture not supported" >&2
        return 1
    fi
    
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