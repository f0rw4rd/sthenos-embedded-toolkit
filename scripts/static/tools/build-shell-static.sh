#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"

SUPPORTED_OS="linux,android,freebsd,openbsd,netbsd,macos,windows"
TOOL_NAME="shell"

get_version() {
    echo "1.0"
}

get_source_url() {
    echo "local"
}

build_shell_static() {
    local arch="$1"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    log "Building shell static tools for $arch"

    setup_toolchain_for_arch "$arch"
    
    local cflags=$(get_compile_flags "$arch" "static" "shell")
    local ldflags=$(get_link_flags "$arch" "static")

    local extra_libs=""
    local bin_ext=""
    if [[ "${ZIG_TARGET:-}" == *"windows"* ]] || [[ "$arch" == *_windows ]]; then
        extra_libs="-lws2_32 -ladvapi32"
        bin_ext=".exe"
    fi

    local tools="shell-bind shell-env shell-helper shell-reverse shell-fifo shell-loader"

    local output_dir=$(get_output_dir "$arch" "shell")
    mkdir -p "$output_dir"

    local build_dir="/tmp/build-shell-$arch-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"

    local built=0
    for tool in $tools; do
        local source="/build/shared-libs/${tool}.c"
        local output="$output_dir/${tool}${bin_ext}"
        
        if [ -s "$output" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
            log "Skipping $tool (already exists)"
            built=$((built + 1))
            continue
        fi
        [ -f "$output" ] && [ ! -s "$output" ] && rm -f "$output"
        
        if [ ! -f "$source" ]; then
            log_error "Source not found: $source"
            continue
        fi
        
        log "Building $tool..."

        local link_target="${tool}${bin_ext}"

        if ! $CC $cflags -DENABLE_MAIN -c "$source" -o "${tool}.o" 2>&1; then
            log_error "Failed to compile $tool"
            continue
        fi

        if ! $CC $ldflags -o "$link_target" "${tool}.o" $extra_libs 2>&1; then
            log_error "Failed to link $tool"
            continue
        fi

        $STRIP "$link_target" 2>&1 || true

        if [ ! -s "$link_target" ]; then
            log_error "Strip produced empty binary: $link_target"
            continue
        fi

        # Re-create output_dir: when the path contains a ".zig" segment,
        # `zig cc -static` mistakes it for a zig build artifact and removes it
        # during linking, so we recreate the directory right before copying.
        mkdir -p "$output_dir"
        cp "$link_target" "$output"
        chmod +x "$output"
        
        local size=$(ls -lh "$output" 2>/dev/null | awk '{print $5}')
        log "Built: $output ($size)"
        
        built=$((built + 1))
    done
    
    cd /
    rm -rf "$build_dir"
    
    if [ $built -eq 0 ]; then
        log_error "No shell tools were built"
        return 1
    fi
    
    log "Successfully built $built shell tools"
    return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    arch="$1"
    if [ -z "$arch" ]; then
        log_error "Usage: $0 <architecture>"
        exit 1
    fi
    build_shell_static "$arch"
fi
