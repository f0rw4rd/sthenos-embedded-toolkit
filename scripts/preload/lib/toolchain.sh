#!/bin/bash
# Toolchain management for preload library builds

# Get toolchain directory
get_toolchain_dir() {
    local arch="$1"
    local prefix=$(get_toolchain_prefix "$arch")
    echo "/build/toolchains-preload/${prefix}"
}

# Check if toolchain exists
toolchain_exists() {
    local arch="$1"
    local toolchain_dir=$(get_toolchain_dir "$arch")
    local prefix=$(get_toolchain_prefix "$arch")
    
    # Check for the gcc binary
    [ -x "${toolchain_dir}/bin/${prefix}-gcc" ]
}

# Get compiler for architecture
get_compiler() {
    local arch="$1"
    local toolchain_dir=$(get_toolchain_dir "$arch")
    local prefix=$(get_toolchain_prefix "$arch")
    
    echo "${toolchain_dir}/bin/${prefix}-gcc"
}

# Get strip command for architecture
get_strip() {
    local arch="$1"
    local toolchain_dir=$(get_toolchain_dir "$arch")
    local prefix=$(get_toolchain_prefix "$arch")
    
    echo "${toolchain_dir}/bin/${prefix}-strip"
}

# Setup environment for cross-compilation
setup_cross_env() {
    local arch="$1"
    local toolchain_dir=$(get_toolchain_dir "$arch")
    local prefix=$(get_toolchain_prefix "$arch")
    
    # Export environment variables
    export PATH="${toolchain_dir}/bin:$PATH"
    export CC="${prefix}-gcc"
    export CXX="${prefix}-g++"
    export AR="${prefix}-ar"
    export AS="${prefix}-as"
    export LD="${prefix}-ld"
    export STRIP="${prefix}-strip"
    export RANLIB="${prefix}-ranlib"
    
    # Architecture-specific flags
    case "$arch" in
        i486)
            export CFLAGS="-m32 -march=i486"
            export LDFLAGS="-m32"
            ;;
        arm32v7le)
            export CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard"
            export LDFLAGS=""
            ;;
        *)
            export CFLAGS=""
            export LDFLAGS=""
            ;;
    esac
    
    log_debug "Cross-compilation environment set for $arch"
    log_debug "CC=$CC"
    log_debug "CFLAGS=$CFLAGS"
}

# Ensure toolchain exists (fail if missing)
ensure_toolchain() {
    local arch="$1"
    
    if toolchain_exists "$arch"; then
        log_debug "Toolchain for $arch found"
        return 0
    fi
    
    # Toolchain missing - fail immediately
    local toolchain_dir=$(get_toolchain_dir "$arch")
    log_error "Toolchain not found for $arch"
    log_error "Expected toolchain directory: $toolchain_dir"
    log_error "Toolchains should be pre-downloaded during Docker image build"
    log_error "Rebuild the Docker image to fix this issue"
    return 1
}

