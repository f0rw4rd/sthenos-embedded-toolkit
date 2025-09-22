#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"

get_version() {
    echo "1.0"
}

get_source_url() {
    echo "local"
}

build_shell_static() {
    local arch="$1"
    log "Building shell static tools for $arch"
    
    setup_toolchain_for_arch "$arch"
    
    local cflags=$(get_compile_flags "$arch" "static" "shell")
    local ldflags=$(get_link_flags "$arch" "static")
    
    local tools="shell-bind shell-env shell-helper shell-reverse shell-fifo shell-loader"
    
    local output_dir="/build/output/$arch/shell"
    mkdir -p "$output_dir"
    
    local build_dir="/tmp/build-shell-$arch-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    local built=0
    for tool in $tools; do
        local source="/build/shared-libs/${tool}.c"
        local output="$output_dir/$tool"
        
        if [ -f "$output" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
            log "Skipping $tool (already exists)"
            built=$((built + 1))
            continue
        fi
        
        if [ ! -f "$source" ]; then
            log_error "Source not found: $source"
            continue
        fi
        
        log "Building $tool..."
        
        if ! $CC $cflags -DENABLE_MAIN -c "$source" -o "${tool}.o" 2>&1; then
            log_error "Failed to compile $tool"
            continue
        fi
        
        if ! $CC $ldflags -o "$tool" "${tool}.o" 2>&1; then
            log_error "Failed to link $tool"
            continue
        fi
        
        $STRIP "$tool" 2>&1 || true
        
        cp "$tool" "$output"
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
