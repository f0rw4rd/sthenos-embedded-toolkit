#!/bin/bash

CONFIG_BASE_DIR="${BASE_DIR:-/build}"
export CONFIG_BASE_DIR
export SOURCES_DIR="$CONFIG_BASE_DIR/sources"
export LOGS_DIR="$CONFIG_BASE_DIR/logs"

export MUSL_TOOLCHAINS_DIR="$CONFIG_BASE_DIR/toolchains-musl"
export GLIBC_TOOLCHAINS_DIR="$CONFIG_BASE_DIR/toolchains-glibc"

export STATIC_OUTPUT_DIR="$CONFIG_BASE_DIR/output"

export MUSL_BUILD_DIR="$CONFIG_BASE_DIR/tmp/build-musl-static"
export GLIBC_BUILD_DIR="$CONFIG_BASE_DIR/tmp/build-glibc-static"

export MUSL_DEPS_PREFIX="$CONFIG_BASE_DIR/deps-cache"
export GLIBC_DEPS_PREFIX="$CONFIG_BASE_DIR/deps-cache"

export MUSL_BASE_URL="https://musl.cc"
export BOOTLIN_BASE_URL="https://toolchains.bootlin.com/downloads/releases/toolchains"

get_musl_toolchains_base_dir() {
    echo "$MUSL_TOOLCHAINS_DIR"
}

get_glibc_toolchains_base_dir() {
    echo "$GLIBC_TOOLCHAINS_DIR"
}


ensure_build_dirs() {
    mkdir -p "$SOURCES_DIR" "$LOGS_DIR"
    mkdir -p "$MUSL_TOOLCHAINS_DIR" "$GLIBC_TOOLCHAINS_DIR"
    mkdir -p "$STATIC_OUTPUT_DIR"
    mkdir -p "$MUSL_BUILD_DIR" "$GLIBC_BUILD_DIR"
}
