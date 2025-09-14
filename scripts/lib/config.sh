#!/bin/bash
# Build configuration

# Directory structure
CONFIG_BASE_DIR="${BASE_DIR:-/build}"
export CONFIG_BASE_DIR
export SOURCES_DIR="$CONFIG_BASE_DIR/sources"
export LOGS_DIR="$CONFIG_BASE_DIR/logs"

# Toolchain directories
export MUSL_TOOLCHAINS_DIR="$CONFIG_BASE_DIR/toolchains-musl"
export GLIBC_TOOLCHAINS_DIR="$CONFIG_BASE_DIR/toolchains-glibc"

# Output directories
export STATIC_OUTPUT_DIR="$CONFIG_BASE_DIR/output"
# Shared libraries are stored in $STATIC_OUTPUT_DIR/$arch/shared/$libc_type

# Build directories
export MUSL_BUILD_DIR="$CONFIG_BASE_DIR/tmp/build-musl-static"
export GLIBC_BUILD_DIR="$CONFIG_BASE_DIR/tmp/build-glibc-static"

# Dependencies
# Legacy deps-*-static directories no longer used - now using central cache
# Compatibility variables
export MUSL_DEPS_PREFIX="$CONFIG_BASE_DIR/deps-cache"
export GLIBC_DEPS_PREFIX="$CONFIG_BASE_DIR/deps-cache"

# Download URLs
export MUSL_BASE_URL="https://musl.cc"
export BOOTLIN_BASE_URL="https://toolchains.bootlin.com/downloads/releases/toolchains"

# Toolchain detection functions
get_musl_toolchain_dir() {
    echo "$MUSL_TOOLCHAINS_DIR"
}

get_glibc_toolchain_dir() {
    echo "$GLIBC_TOOLCHAINS_DIR"
}


# Ensure directories exist
ensure_build_dirs() {
    mkdir -p "$SOURCES_DIR" "$LOGS_DIR"
    mkdir -p "$MUSL_TOOLCHAINS_DIR" "$GLIBC_TOOLCHAINS_DIR"
    mkdir -p "$STATIC_OUTPUT_DIR"
    mkdir -p "$MUSL_BUILD_DIR" "$GLIBC_BUILD_DIR"
    # No longer needed - using Docker volume for deps-cache
}