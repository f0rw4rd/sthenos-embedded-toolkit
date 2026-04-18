#!/bin/bash
set -uo pipefail

BUILD_DIR="/build"
LOGS_DIR="${LOGS_DIR:-/build/logs}"

source "$BUILD_DIR/scripts/lib/logging.sh"
source "$BUILD_DIR/scripts/lib/config.sh"
source "$BUILD_DIR/scripts/lib/common.sh"
source "$BUILD_DIR/scripts/lib/core/architectures.sh"
source "$BUILD_DIR/scripts/lib/core/arch_helper.sh"
source "$BUILD_DIR/scripts/lib/core/compile_flags.sh"
source "$BUILD_DIR/scripts/lib/supported.sh"

# If no LIBC_TYPE specified, build for both
if [ -z "${LIBC_TYPE:-}" ]; then
    BUILD_BOTH_LIBC=true
    LIBC_TYPES=("musl" "glibc")
else
    BUILD_BOTH_LIBC=false
    LIBC_TYPES=("$LIBC_TYPE")
fi

LOG_ENABLED="${LOG_ENABLED:-true}"
DEBUG="${DEBUG:-0}"

ALL_LIBS=("${SUPPORTED_SHARED_LIBS[@]}")
ALL_ARCHS=("${SUPPORTED_ARCHS[@]}")

LIBS_TO_BUILD=""
ARCHS_TO_BUILD=""

for arg in "$@"; do
    if [[ " ${ALL_LIBS[@]} " =~ " $arg " ]] || [ "$arg" = "all" ]; then
        if [ "$arg" = "all" ] && [ -z "$LIBS_TO_BUILD" ]; then
            LIBS_TO_BUILD="${ALL_LIBS[@]}"
        elif [ "$arg" != "all" ]; then
            LIBS_TO_BUILD="$LIBS_TO_BUILD $arg"
        fi
    else
        if [ "$arg" = "all" ]; then
            ARCHS_TO_BUILD="${ALL_ARCHS[@]}"
        else
            ARCHS_TO_BUILD="$ARCHS_TO_BUILD $arg"
        fi
    fi
done

[ -z "$LIBS_TO_BUILD" ] && LIBS_TO_BUILD="${ALL_LIBS[@]}"
[ -z "$ARCHS_TO_BUILD" ] && ARCHS_TO_BUILD="${ALL_ARCHS[@]}"

setup_shared_arch() {
    local arch=$1
    
    arch=$(map_arch_name "$arch")
    
    if [ "$LIBC_TYPE" = "musl" ]; then
        local musl_name=$(get_musl_toolchain "$arch")
        if [ -z "$musl_name" ]; then
            log_debug "Skipping for $arch - no musl toolchain available"
            return 2
        fi
        
        if ! setup_arch "$arch"; then
            log_error "Failed to setup musl toolchain for $arch"
            return 1
        fi
    else
        local glibc_name=$(get_glibc_toolchain "$arch")
        if [ -z "$glibc_name" ]; then
            log_debug "Skipping for $arch - no glibc toolchain available"
            return 2
        fi
        
        local toolchain_dir="$GLIBC_TOOLCHAINS_DIR/$glibc_name"
        if [ ! -d "$toolchain_dir" ]; then
            log_error "Toolchain not found at $toolchain_dir"
            return 1
        fi
        
        export PATH="$toolchain_dir/bin:$PATH"
        export CC="${glibc_name}-gcc"
        export CXX="${glibc_name}-g++"
        export STRIP="${glibc_name}-strip"
        export CROSS_COMPILE="${glibc_name}-"
    fi
    
    export BUILD_DIR STATIC_OUTPUT_DIR LIBC_TYPE DEPS_PREFIX SOURCES_DIR GLIBC_TOOLCHAINS_DIR
    export SKIP_IF_EXISTS="${SKIP_IF_EXISTS:-true}"
    
    return 0
}

build_shared_library() {
    local lib="$1"
    local arch="$2"
    local log_enabled="${3:-true}"
    local debug="${4:-0}"
    
    if ! setup_shared_arch "$arch"; then
        return $?
    fi
    
    local script="${SHARED_LIB_SCRIPTS[$lib]}"
    if [ -z "$script" ]; then
        log_error "No build script mapping found for shared library: $lib"
        return 1
    fi
    
    if [ ! -f "$script" ]; then
        log_error "Build script not found: $script"
        return 1
    fi
    
    local log_file=""
    if [ "$log_enabled" = "true" ]; then
        log_file="${LOGS_DIR}/${lib}-${arch}-${LIBC_TYPE}-$(date +%Y%m%d-%H%M%S).log"
        log "Building $lib for $arch with $LIBC_TYPE (log: ${log_file#/build/})..."
    else
        log "Building $lib for $arch with $LIBC_TYPE..."
    fi
    
    local result
    if [ -n "$log_file" ]; then
        if [ "$debug" = "1" ]; then
            bash -x "$script" "$arch" 2>&1 | tee "$log_file"
            result=${PIPESTATUS[0]}
        else
            bash "$script" "$arch" > "$log_file" 2>&1
            result=$?
        fi
    else
        if [ "$debug" = "1" ]; then
            bash -x "$script" "$arch"
        else
            bash "$script" "$arch"
        fi
        result=$?
    fi
    
    if [ $result -eq 0 ]; then
        [ -n "$log_file" ] && rm -f "$log_file"
    elif [ $result -ne 2 ]; then
        [ -n "$log_file" ] && log_error "Build failed, check log: ${log_file#/build/}"
    fi
    
    return $result
}

TOTAL=0
FAILED=0
SKIPPED=0

for lib in $LIBS_TO_BUILD; do
    for arch in $ARCHS_TO_BUILD; do
        for libc in "${LIBC_TYPES[@]}"; do
            TOTAL=$((TOTAL + 1))
        done
    done
done

if [ "$BUILD_BOTH_LIBC" = true ]; then
    echo "Building shared libraries with both musl and glibc"
else
    echo "Building shared libraries with ${LIBC_TYPE}"
fi
echo "Libraries: $LIBS_TO_BUILD"
echo "Architectures: $ARCHS_TO_BUILD"
echo "Total builds: $TOTAL"
echo

COUNT=0
for lib in $LIBS_TO_BUILD; do
    echo "Building shared library: $lib"
    
    for arch in $ARCHS_TO_BUILD; do
        for libc_type in "${LIBC_TYPES[@]}"; do
            COUNT=$((COUNT + 1))
            
            # Export LIBC_TYPE for the build scripts
            export LIBC_TYPE="$libc_type"
            
            log_tool "$arch" "[$COUNT/$TOTAL] Building $lib with $libc_type..."
            
            build_shared_library "$lib" "$arch" "$LOG_ENABLED" "$DEBUG"
            ret=$?
            
            if [ $ret -eq 0 ]; then
                log_tool "$arch" "[$COUNT/$TOTAL] SUCCESS: Built $lib with $libc_type"
            elif [ $ret -eq 2 ]; then
                log_debug "Skipped $lib for $arch with $libc_type (unsupported)"
                SKIPPED=$((SKIPPED + 1))
            else
                log_tool "$arch" "[$COUNT/$TOTAL] ERROR: Failed to build $lib with $libc_type"
                FAILED=$((FAILED + 1))
            fi
            echo
        done
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