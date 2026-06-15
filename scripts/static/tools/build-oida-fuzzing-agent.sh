#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/source_versions.sh"

# Plain POSIX C11 (fork/exec, waitpid, killpg, setpgid, clock_gettime,
# getaddrinfo). The Linux /proc and *BSD/macOS sysctl paths are each guarded
# behind their own #if, and platform_win.c is fully #ifdef _WIN32, so the same
# 4-file source set builds everywhere.
SUPPORTED_OS="linux,android,freebsd,macos,windows"

build_oida_fuzzing_agent() {
    local arch=$1
    local build_dir=$(create_build_dir "oida-fuzzing-agent" "$arch")
    local TOOL_NAME="oida-fuzzing-agent"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "oida-fuzzing-agent"; then
        return 0
    fi

    setup_toolchain_for_arch "$arch" || return 1

    if ! download_and_extract "$OIDA_FUZZING_AGENT_URL" "$build_dir" 0 "$OIDA_FUZZING_AGENT_SHA512"; then
        log_tool_error "oida-fuzzing-agent" "Failed to download and extract source"
        cleanup_build_dir "$build_dir"
        return 1
    fi

    cd "$build_dir/oida-fuzzing-agent-${OIDA_FUZZING_AGENT_VERSION}"

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")

    # Windows (Zig CC -> *-windows-gnu) needs winsock2 for the socket layer and
    # advapi32 for the token RNG. POSIX targets link nothing extra.
    local extra_libs=""
    if [[ "${ZIG_TARGET:-}" == *windows* ]] || [[ "$arch" == *_windows ]]; then
        extra_libs="-lws2_32 -ladvapi32"
    fi

    log_tool "oida-fuzzing-agent" "Building oida-fuzzing-agent for $arch..."

    # No configure, no deps: one-shot compile of the 4-file source set. The
    # version is baked in via -DMA_VERSION so `--version` reports it.
    $CC $cflags $ldflags -std=c11 \
        -DMA_VERSION="\"${OIDA_FUZZING_AGENT_VERSION}\"" \
        fuzzing_agent.c config.c platform_posix.c platform_win.c \
        -o oida-fuzzing-agent $extra_libs || {
        log_tool_error "oida-fuzzing-agent" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }

    $STRIP "oida-fuzzing-agent" 2>/dev/null || true
    local output_path=$(get_output_path "$arch" "oida-fuzzing-agent")
    mkdir -p "$(dirname "$output_path")"
    cp "oida-fuzzing-agent" "$output_path"

    local size=$(get_binary_size "$output_path")
    log_tool "oida-fuzzing-agent" "Built successfully for $arch ($size)"

    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_oida_fuzzing_agent "$arch"
