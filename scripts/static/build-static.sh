#!/bin/bash
# Static build functions - sourced by ./build script
# Functions for building static binaries with musl and glibc

# Source common.sh which sets up BASE_DIR, STATIC_SCRIPT_DIR, SCRIPT_DIR and loads all libs
if [ -z "$BASE_DIR" ]; then
    # Fallback if not already set
    STATIC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BASE_DIR="$(cd "$STATIC_SCRIPT_DIR/../.." && pwd)"
fi

source "$BASE_DIR/scripts/lib/config.sh"
source "$BASE_DIR/scripts/lib/common.sh"
source "$BASE_DIR/scripts/lib/supported.sh"
source "$BASE_DIR/scripts/lib/arch_map.sh"
source "$BASE_DIR/scripts/lib/core/arch_helper.sh"
source "$BASE_DIR/scripts/lib/logging.sh"
source "$BASE_DIR/scripts/lib/core/compile_flags.sh"
source "$BASE_DIR/scripts/lib/tools.sh"

# Setup architecture for glibc builds
setup_arch_glibc() {
    local canonical_arch="$1"
    
    TOOLCHAIN_NAME=$(get_glibc_toolchain "$canonical_arch")
    if [ -z "$TOOLCHAIN_NAME" ]; then
        log_error "No glibc toolchain configured for architecture: $canonical_arch"
        return 1
    fi
    
    local toolchain_dir="${TOOLCHAINS_DIR}/${TOOLCHAIN_NAME}"
    if [ ! -d "$toolchain_dir" ]; then
        log_error "Toolchain not found for $canonical_arch at $toolchain_dir"
        return 1
    fi
    
    export PATH="${toolchain_dir}/bin:$PATH"
    export CC="${TOOLCHAIN_NAME}-gcc"
    export CXX="${TOOLCHAIN_NAME}-g++"
    export AR="${TOOLCHAIN_NAME}-ar"
    export STRIP="${TOOLCHAIN_NAME}-strip"
    export TOOLCHAIN_PREFIX
    
    # Set glibc build flags if available
    if type get_glibc_compile_flags >/dev/null 2>&1; then
        export CFLAGS=$(get_glibc_compile_flags "$canonical_arch" "")
        export CXXFLAGS=$(get_glibc_cxx_flags "$canonical_arch" "")
        export LDFLAGS=$(get_glibc_link_flags "$canonical_arch")
    fi
    
    export STATIC_SCRIPT_DIR TOOLCHAINS_DIR OUTPUT_DIR BUILD_DIR SOURCES_DIR DEPS_PREFIX LOGS_DIR
}

# Build tool for glibc
build_glibc_tool() {
    local tool="$1"
    local canonical_arch="$2"
    
    local arch_output="${OUTPUT_DIR}/${canonical_arch}"
    mkdir -p "$arch_output"
    
    # Check if already exists
    if [ "${SKIP_IF_EXISTS:-true}" = "true" ] && [ -f "${arch_output}/${tool}" ]; then
        log_tool "$canonical_arch" "$tool already exists, skipping..."
        return 0
    fi
    
    # Ensure TOOLCHAINS_DIR is set for glibc builds
    TOOLCHAINS_DIR="${GLIBC_TOOLCHAINS_DIR:-/build/toolchains-glibc}"
    export TOOLCHAINS_DIR
    
    if ! setup_arch_glibc "$canonical_arch"; then
        return 1
    fi
    
    export DEPS_PREFIX="${DEPS_PREFIX}/${canonical_arch}"
    mkdir -p "${DEPS_PREFIX}/lib" "${DEPS_PREFIX}/include"
    
    local build_script="${TOOL_SCRIPTS[$tool]}"
    if [ -z "$build_script" ]; then
        log_error "No build script mapping found for tool: $tool"
        return 1
    fi
    
    if [ ! -f "$build_script" ]; then
        log_error "Build script not found: $build_script"
        return 1
    fi
    
    # Execute the script directly, just like musl does
    # Pass libc type as environment variable so scripts can set up correctly
    # Scripts are already executable in the repo, no need to chmod
    if LIBC_TYPE="glibc" "$build_script" "$canonical_arch"; then
        return 0
    else
        return 1
    fi
}

# Main build function for a single tool/arch combination
do_static_build() {
    local tool="$1"
    local arch="$2"
    local libc="${3:-musl}"
    local mode="${4:-standard}"
    local log_enabled="${5:-false}"
    local debug="${6:-}"
    
    # Map architecture to canonical name
    local canonical_arch=$(map_arch_name "$arch")
    
    # Handle glibc-only architectures
    if [[ "$canonical_arch" == *"[glibc-only]"* ]]; then
        # Extract the actual architecture name from the glibc-only message
        canonical_arch=$(echo "$canonical_arch" | sed 's/.*\[glibc-only\] \([^ ]*\) .*/\1/')
    fi
    
    # Auto-switch to glibc for architectures that don't support musl
    if [ "$libc" = "musl" ]; then
        # Check if this architecture has musl support        
        if ! arch_supports_musl "$arch"; then
            if arch_supports_glibc "$arch"; then
                # Switch to glibc for this architecture since musl is not available
                log_tool "$arch" "No musl support, switching to glibc for $tool..."
                libc="glibc"
            else
                log_tool_warn "$arch" "Architecture $arch not supported by either musl or glibc"
                return 1
            fi
        fi
    fi
    
    if [ "$libc" = "glibc" ]; then
        local log_file=""
        if [ "$log_enabled" = "true" ]; then
            log_file="${LOGS_DIR}/build-${tool}-${canonical_arch}-$(date +%Y%m%d-%H%M%S).log"
            log_display="${log_file#/build/}"
            log_tool "$canonical_arch" "Building $tool with glibc (log: $log_display)..."
            
            if [ "$debug" = "1" ]; then
                (set -x; build_glibc_tool "$tool" "$canonical_arch") 2>&1 | tee "$log_file"
            else
                (build_glibc_tool "$tool" "$canonical_arch") > "$log_file" 2>&1
            fi
        else
            log_tool "$canonical_arch" "Building $tool with glibc..."
            build_glibc_tool "$tool" "$canonical_arch"
        fi
        
        local result=$?
        if [ $result -eq 0 ]; then
            log_tool "$canonical_arch" "SUCCESS: $tool built successfully"
            [ -n "$log_file" ] && rm -f "$log_file"
        else
            log_tool "$canonical_arch" "ERROR: $tool build failed"
            [ -n "$log_file" ] && log_tool "$canonical_arch" "Check log: ${log_file#/build/}"
        fi
        return $result
    else
        if ! setup_arch "$canonical_arch"; then
            log_error "Failed to setup architecture"
            return 1
        fi
        
        if [ "$debug" = "1" ]; then
            log_tool "$canonical_arch" "DEBUG: CC=$CC, PATH=$PATH"
        fi
        
        local log_file=""
        if [ "$log_enabled" = "true" ]; then
            log_file="${LOGS_DIR}/build-${tool}-${canonical_arch}-$(date +%Y%m%d-%H%M%S).log"
            log_display="${log_file#/build/}"
            log_tool "$canonical_arch" "Building $tool with musl (log: $log_display)..."
            
            if [ "$debug" = "1" ]; then
                (set -x; build_tool "$tool" "$canonical_arch" "$mode") 2>&1 | tee "$log_file"
            else
                (build_tool "$tool" "$canonical_arch" "$mode") > "$log_file" 2>&1
            fi
        else
            log_tool "$canonical_arch" "Building $tool with musl..."
            build_tool "$tool" "$canonical_arch" "$mode"
        fi
        
        local result=$?
        if [ $result -eq 0 ]; then
            log_tool "$canonical_arch" "SUCCESS: $tool built successfully"
            [ -n "$log_file" ] && rm -f "$log_file"
        else
            log_tool "$canonical_arch" "ERROR: $tool build failed"
            [ -n "$log_file" ] && log_tool "$canonical_arch" "Check log: ${log_file#/build/}"
        fi
        return $result
    fi
}

# Configure environment based on libc choice
configure_static_build_env() {
    local libc="${1:-musl}"
    
    if [ "$libc" = "glibc" ]; then
        # Glibc configuration - using centralized config
        TOOLCHAINS_DIR="$GLIBC_TOOLCHAINS_DIR"
        OUTPUT_DIR="$STATIC_OUTPUT_DIR"
        BUILD_DIR="$GLIBC_BUILD_DIR"
        SOURCES_DIR="$SOURCES_DIR"
        DEPS_PREFIX="$GLIBC_DEPS_PREFIX"
        LOGS_DIR="$LOGS_DIR"
        # All tools can be built with glibc (most tools support both musl and glibc)
        # Get supported tools from TOOL_SCRIPTS array keys
        SUPPORTED_STATIC_TOOLS=($(printf '%s\n' "${!TOOL_SCRIPTS[@]}" | sort))
        
        # Glibc supported architectures
        SUPPORTED_STATIC_ARCHS=(x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x 
                                aarch64_be mips64 arm32v5le armv6 ppc32be sparc64 sparcv8 sh4 
                                mips32be mips32le riscv32 microblazeel microblaze 
                                nios2 or1k arcle arcle_hs38 xtensa xtensa_lx60 bfin m68k m68k_coldfire)
    else
        # Musl configuration - using centralized config
        TOOLCHAINS_DIR="$MUSL_TOOLCHAINS_DIR"
        OUTPUT_DIR="$STATIC_OUTPUT_DIR"
        BUILD_DIR="$MUSL_BUILD_DIR"
        SOURCES_DIR="$SOURCES_DIR"
        DEPS_PREFIX="$MUSL_DEPS_PREFIX"
        LOGS_DIR="$LOGS_DIR"
        
        # Get supported tools from TOOL_SCRIPTS array keys
        SUPPORTED_STATIC_TOOLS=($(printf '%s\n' "${!TOOL_SCRIPTS[@]}" | sort))
        
        # Use musl architectures from supported.sh
        SUPPORTED_STATIC_ARCHS=("${SUPPORTED_ARCHS[@]}")
    fi
    
    # Create necessary directories
    mkdir -p "$BUILD_DIR" "$SOURCES_DIR" "$DEPS_PREFIX" "$LOGS_DIR" "$OUTPUT_DIR"
    
    # Export for use by other functions
    export TOOLCHAINS_DIR OUTPUT_DIR BUILD_DIR SOURCES_DIR DEPS_PREFIX LOGS_DIR
    export SUPPORTED_STATIC_TOOLS SUPPORTED_STATIC_ARCHS
}

# Main static build orchestrator
run_static_builds() {
    local tools="$1"
    local architectures="$2"
    local libc="${3:-musl}"
    local mode="${4:-standard}"
    local log_enabled="${5:-false}"
    local debug="${6:-}"
    
    configure_static_build_env "$libc"
    
    # Determine tools to build
    local TOOLS_TO_BUILD=()
    if [ "$tools" = "all" ]; then
        TOOLS_TO_BUILD=("${SUPPORTED_STATIC_TOOLS[@]}")
    else
        TOOLS_TO_BUILD=("$tools")
    fi
    
    # Validate tools
    for tool in "${TOOLS_TO_BUILD[@]}"; do
        local valid=false
        for supported in "${SUPPORTED_STATIC_TOOLS[@]}"; do
            if [ "$tool" = "$supported" ]; then
                valid=true
                break
            fi
        done
        if [ "$valid" = false ]; then
            log_error "Tool '$tool' is not supported with $libc"
            echo "Supported $libc tools: ${SUPPORTED_STATIC_TOOLS[@]}"
            return 1
        fi
    done
    
    # Determine architectures to build
    local ARCHS_TO_BUILD=()
    if [ "$architectures" = "all" ]; then
        ARCHS_TO_BUILD=("${SUPPORTED_STATIC_ARCHS[@]}")
    else
        # Map architecture name to canonical form
        local canonical_arch=$(map_arch_name "$architectures")
        
        # Handle glibc-only architectures
        if [[ "$canonical_arch" == *"[glibc-only]"* ]]; then
            # Extract the actual architecture name from the glibc-only message
            canonical_arch=$(echo "$canonical_arch" | sed 's/.*\[glibc-only\] \([^ ]*\) .*/\1/')
        fi
        ARCHS_TO_BUILD=("$canonical_arch")
    fi
    
    # Validate architectures
    for arch in "${ARCHS_TO_BUILD[@]}"; do
        local valid=false
        for supported in "${SUPPORTED_STATIC_ARCHS[@]}"; do
            if [ "$arch" = "$supported" ]; then
                valid=true
                break
            fi
        done
        if [ "$valid" = false ]; then
            log_error "Architecture '$arch' is not supported with $libc"
            return 1
        fi
    done
    
    echo "Static Build System"
    echo "C Library: $libc"
    echo "Tools: ${TOOLS_TO_BUILD[@]}"
    echo "Architectures: ${ARCHS_TO_BUILD[@]}"
    echo "Mode: $mode"
    echo "Build mode: Sequential (parallel compilation within each build)"
    echo "Logging: $log_enabled"
    echo ""
    
    # Ensure all required toolchains are available (on-demand download)
    echo "Checking toolchain availability for architectures: ${ARCHS_TO_BUILD[@]}"
    if ! ensure_toolchains "${ARCHS_TO_BUILD[@]}"; then
        log_error "Failed to ensure toolchains are available"
        return 1
    fi
    echo ""
    
    local TOTAL_BUILDS=$((${#TOOLS_TO_BUILD[@]} * ${#ARCHS_TO_BUILD[@]}))
    local COMPLETED=0
    local FAILED=0
    local START_TIME=$(date +%s)
    
    for tool in "${TOOLS_TO_BUILD[@]}"; do
        for arch in "${ARCHS_TO_BUILD[@]}"; do
            do_static_build "$tool" "$arch" "$libc" "$mode" "$log_enabled" "$debug" || true
            
            # Check result
            local canonical_arch=$(map_arch_name "$arch")
            
            # Handle glibc-only architectures
            if [[ "$canonical_arch" == *"[glibc-only]"* ]]; then
                # Extract the actual architecture name from the glibc-only message
                canonical_arch=$(echo "$canonical_arch" | sed 's/.*\[glibc-only\] \([^ ]*\) .*/\1/')
            fi
            if [ "$tool" = "shell" ]; then
                if [ -d "${OUTPUT_DIR}/${canonical_arch}/shell" ] && [ -n "$(ls -A ${OUTPUT_DIR}/${canonical_arch}/shell 2>/dev/null)" ]; then
                    COMPLETED=$((COMPLETED + 1))
                else
                    FAILED=$((FAILED + 1))
                fi
            elif [ -f "${OUTPUT_DIR}/${canonical_arch}/${tool}" ]; then
                COMPLETED=$((COMPLETED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
        done
        echo
    done
    
    # Summary
    local END_TIME=$(date +%s)
    local BUILD_TIME=$((END_TIME - START_TIME))
    local BUILD_MINS=$((BUILD_TIME / 60))
    local BUILD_SECS=$((BUILD_TIME % 60))
    
    echo "Total builds: $TOTAL_BUILDS"
    echo "Completed: $COMPLETED"
    if [ $FAILED -gt 0 ]; then
        log_error "Failed: $FAILED"
    else
        echo "Failed: $FAILED"
    fi
    echo "Build time: ${BUILD_MINS}m ${BUILD_SECS}s"
    echo ""
    
    # List failures if any
    if [ $FAILED -gt 0 ]; then
        echo ""
        echo "Failed builds:"
        for tool in "${TOOLS_TO_BUILD[@]}"; do
            for arch in "${ARCHS_TO_BUILD[@]}"; do
                local canonical_arch=$(map_arch_name "$arch")
                
                # Handle glibc-only architectures
                if [[ "$canonical_arch" == *"[glibc-only]"* ]]; then
                    # Extract the actual architecture name from the glibc-only message
                    canonical_arch=$(echo "$canonical_arch" | sed 's/.*\[glibc-only\] \([^ ]*\) .*/\1/')
                fi
                if [ ! -f "${OUTPUT_DIR}/${canonical_arch}/${tool}" ]; then
                    echo "  - $tool for ${canonical_arch}"
                    if [ "$log_enabled" = "true" ]; then
                        local log_file=$(ls -t ${LOGS_DIR}/build-${tool}-${canonical_arch}-*.log 2>/dev/null | head -1)
                        [ -n "$log_file" ] && echo "    Log: ${log_file#/build/}"
                    fi
                fi
            done
        done
    fi
    
    # Clean up empty directories
    log_info "Cleaning up empty directories..."
    find ${OUTPUT_DIR} -type d -empty -delete 2>/dev/null || true
    
    if [ $FAILED -eq 0 ]; then
        echo "SUCCESS: All builds completed successfully"
        return 0
    else
        log_error "Some builds failed. Check logs for details."
        return 1
    fi
}