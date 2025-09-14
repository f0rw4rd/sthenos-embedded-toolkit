#!/bin/bash
set -uo pipefail

# Simplified shared library build script
# Reuses central toolchain and compilation infrastructure

BUILD_DIR="/build"
LOGS_DIR="${LOGS_DIR:-/build/logs}"

# Source central libraries
source "$BUILD_DIR/scripts/lib/logging.sh"
source "$BUILD_DIR/scripts/lib/config.sh"
source "$BUILD_DIR/scripts/lib/common.sh"
source "$BUILD_DIR/scripts/lib/core/architectures.sh"
source "$BUILD_DIR/scripts/lib/core/arch_helper.sh"
source "$BUILD_DIR/scripts/lib/core/compile_flags.sh"
source "$BUILD_DIR/scripts/lib/supported.sh"

# LIBC_TYPE should be set via environment variable from Docker
LIBC_TYPE="${LIBC_TYPE:-glibc}"

# Logging settings from environment
LOG_ENABLED="${LOG_ENABLED:-true}"
DEBUG="${DEBUG:-0}"

# Get all supported libraries and architectures
ALL_LIBS=("${SUPPORTED_SHARED_LIBS[@]}")
ALL_ARCHS=("${SUPPORTED_ARCHS[@]}")

# Parse arguments - everything before first architecture is a library
LIBS_TO_BUILD=""
ARCHS_TO_BUILD=""

for arg in "$@"; do
    # Check if it's a known library
    if [[ " ${ALL_LIBS[@]} " =~ " $arg " ]] || [ "$arg" = "all" ]; then
        if [ "$arg" = "all" ] && [ -z "$LIBS_TO_BUILD" ]; then
            LIBS_TO_BUILD="${ALL_LIBS[@]}"
        elif [ "$arg" != "all" ]; then
            LIBS_TO_BUILD="$LIBS_TO_BUILD $arg"
        fi
    # Otherwise assume it's an architecture
    else
        if [ "$arg" = "all" ]; then
            ARCHS_TO_BUILD="${ALL_ARCHS[@]}"
        else
            ARCHS_TO_BUILD="$ARCHS_TO_BUILD $arg"
        fi
    fi
done

# Default to all if not specified
[ -z "$LIBS_TO_BUILD" ] && LIBS_TO_BUILD="${ALL_LIBS[@]}"
[ -z "$ARCHS_TO_BUILD" ] && ARCHS_TO_BUILD="${ALL_ARCHS[@]}"

build_shared_library() {
    local lib="$1"
    local arch="$2"
    local log_enabled="${3:-true}"
    local debug="${4:-0}"
    
    # Map architecture name
    arch=$(map_arch_name "$arch")
    
    # Check if this architecture supports the current libc type
    if [ "$LIBC_TYPE" = "musl" ]; then
        local musl_name=$(get_musl_toolchain "$arch")
        if [ -z "$musl_name" ]; then
            log_debug "Skipping $lib for $arch - no musl toolchain available"
            return 2  # Special return code for skipped
        fi
    else
        local glibc_name=$(get_glibc_toolchain "$arch")
        if [ -z "$glibc_name" ]; then
            log_debug "Skipping $lib for $arch - no glibc toolchain available"
            return 2  # Special return code for skipped
        fi
    fi
    
    # Set output directory using new structure
    local output_dir="$STATIC_OUTPUT_DIR/$arch/shared/$LIBC_TYPE"
    local output_file="$output_dir/${lib}.so"
    
    # Check if already built
    if [ -f "$output_file" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
        local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
        log "Already built: $output_file ($size)"
        return 0
    fi
    
    local log_file=""
    if [ "$log_enabled" = "true" ]; then
        log_file="${LOGS_DIR}/${lib}-${arch}-${LIBC_TYPE}-$(date +%Y%m%d-%H%M%S).log"
        log "Building $lib for $arch with $LIBC_TYPE (log: ${log_file#/build/})..."
    else
        log "Building $lib for $arch with $LIBC_TYPE..."
    fi
    
    # Ensure output directory exists
    mkdir -p "$output_dir"
    
    if [ "$LIBC_TYPE" = "glibc" ]; then
        # For glibc, add toolchain to PATH
        local toolchain_name=$(get_glibc_toolchain "$arch")
        local toolchain_dir="$GLIBC_TOOLCHAINS_DIR/$toolchain_name"
        if [ ! -d "$toolchain_dir" ]; then
            log_error "Toolchain not found at $toolchain_dir"
            return 1
        fi
        
        export PATH="$toolchain_dir/bin:$PATH"
        export CC="${toolchain_name}-gcc"
        export STRIP="${toolchain_name}-strip"
        export CROSS_COMPILE="${toolchain_name}-"
    else
        # For musl, setup standard environment
        if ! setup_arch "$arch"; then
            log_error "Failed to setup musl toolchain for $arch"
            return 1
        fi
    fi
    
    # Get compile and link flags for shared libraries
    local cflags=$(get_compile_flags "$arch" "shared" "")
    local ldflags=$(get_link_flags "$arch" "shared")
    
    # Get source file - check multiple locations
    local source_file=""
    if [ -f "$BUILD_DIR/example-custom-lib/${lib}.c" ]; then
        source_file="$BUILD_DIR/example-custom-lib/${lib}.c"
    elif [ -f "$BUILD_DIR/shared-libs/${lib}.c" ]; then
        source_file="$BUILD_DIR/shared-libs/${lib}.c"
    else
        log_error "Source file not found for ${lib}"
        return 1
    fi
    
    # Create temporary build directory
    local build_dir="/tmp/build-${lib}-${arch}-${LIBC_TYPE}-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Function to run the actual build
    _do_build() {
        log_debug "Compiling $lib for $arch with $LIBC_TYPE"
        log_debug "CC=$CC"
        log_debug "CFLAGS=$cflags"
        log_debug "LDFLAGS=$ldflags"
        
        # Compile to object file
        if ! $CC $cflags -c "$source_file" -o "${lib}.o" 2>&1; then
            log_error "Compilation failed for $lib/$arch"
            cd /
            rm -rf "$build_dir"
            return 1
        fi
        
        # Link to shared library
        if ! $CC $ldflags -o "${lib}.so" "${lib}.o" -ldl 2>&1; then
            log_error "Linking failed for $lib/$arch"
            cd /
            rm -rf "$build_dir"
            return 1
        fi
    }
    
    # Run build with or without logging
    local result
    if [ -n "$log_file" ]; then
        if [ "$debug" = "1" ]; then
            (_do_build) 2>&1 | tee "$log_file"
            result=${PIPESTATUS[0]}
        else
            (_do_build) > "$log_file" 2>&1
            result=$?
        fi
    else
        _do_build
        result=$?
    fi
    
    if [ $result -ne 0 ]; then
        [ -n "$log_file" ] && log_error "Build failed, check log: ${log_file#/build/}"
        cd /
        rm -rf "$build_dir"
        return 1
    fi
    
    # Strip the library
    $STRIP "${lib}.so" 2>/dev/null || true
    
    # Copy to output directory
    cp "${lib}.so" "$output_file"
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    # Report success
    local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
    log "Successfully built: $output_file ($size)"
    [ -n "$log_file" ] && rm -f "$log_file"  # Remove log on success
    
    return 0
}

# Initialize counters
TOTAL=0
FAILED=0
SKIPPED=0

# Count total builds
for lib in $LIBS_TO_BUILD; do
    for arch in $ARCHS_TO_BUILD; do
        TOTAL=$((TOTAL + 1))
    done
done

echo "Building shared libraries with ${LIBC_TYPE}"
echo "Libraries: $LIBS_TO_BUILD"
echo "Architectures: $ARCHS_TO_BUILD"
echo "Total builds: $TOTAL"
echo

COUNT=0
for lib in $LIBS_TO_BUILD; do
    echo "Building shared library: $lib"
    
    for arch in $ARCHS_TO_BUILD; do
        COUNT=$((COUNT + 1))
        log_tool "[$COUNT/$TOTAL]" "Building $lib for $arch..."
        
        # Special handling for libraries with dedicated build scripts
        if [ "$lib" = "tls-noverify" ] || [ "$lib" = "libdesock" ]; then
            # Source the specific build script
            source "$BUILD_DIR/scripts/shared/tools/build-${lib}.sh"
            
            if [ "$lib" = "tls-noverify" ]; then
                build_tls_noverify "$arch" "$LOG_ENABLED" "$DEBUG"
                ret=$?
                if [ $ret -eq 0 ]; then
                    log_tool "$COUNT/$TOTAL" "SUCCESS: Built $lib for $arch with ${LIBC_TYPE}"
                elif [ $ret -eq 2 ]; then
                    # Skipped - architecture doesn't support this libc
                    log_debug "Skipped $lib for $arch with ${LIBC_TYPE} (unsupported)"
                    SKIPPED=$((SKIPPED + 1))
                else
                    log_tool "$COUNT/$TOTAL" "ERROR: Failed to build $lib for $arch with ${LIBC_TYPE}"
                    FAILED=$((FAILED + 1))
                fi
            elif [ "$lib" = "libdesock" ]; then
                build_libdesock "$arch" "$LOG_ENABLED" "$DEBUG"
                ret=$?
                if [ $ret -eq 0 ]; then
                    log_tool "$COUNT/$TOTAL" "SUCCESS: Built $lib for $arch with ${LIBC_TYPE}"
                elif [ $ret -eq 2 ]; then
                    # Skipped - architecture doesn't support this libc
                    log_debug "Skipped $lib for $arch with ${LIBC_TYPE} (unsupported)"
                    SKIPPED=$((SKIPPED + 1))
                else
                    log_tool "$COUNT/$TOTAL" "ERROR: Failed to build $lib for $arch with ${LIBC_TYPE}"
                    FAILED=$((FAILED + 1))
                fi
            fi
        else
            # Regular shared libraries
            build_shared_library "$lib" "$arch" "$LOG_ENABLED" "$DEBUG"
            ret=$?
            if [ $ret -eq 0 ]; then
                log_tool "$COUNT/$TOTAL" "SUCCESS: Built $lib for $arch with ${LIBC_TYPE}"
            elif [ $ret -eq 2 ]; then
                # Skipped - architecture doesn't support this libc
                log_debug "Skipped $lib for $arch with ${LIBC_TYPE} (unsupported)"
                SKIPPED=$((SKIPPED + 1))
            else
                log_tool "$COUNT/$TOTAL" "ERROR: Failed to build $lib for $arch with ${LIBC_TYPE}"
                FAILED=$((FAILED + 1))
            fi
        fi
        echo
    done
done

echo "Build Summary"
echo "Total: $TOTAL"
echo "Successful: $((TOTAL - FAILED - SKIPPED))"
echo "Skipped (unsupported arch/libc): $SKIPPED"
if [ $FAILED -gt 0 ]; then
    log_error "Failed: $FAILED"
fi

exit $FAILED