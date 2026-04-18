#!/bin/bash

if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/common.sh"
fi


parallel_make() {
    make -j$(nproc) "$@"
}


build_tool() {
    local tool=$1
    local arch=$2

    echo "test: $TOOL_SCRIPTS"
    
    if [ -z "${TOOL_SCRIPTS[$tool]}" ]; then
        echo "Unknown tool: $tool"
        return 1
    fi    
    
    local script="${TOOL_SCRIPTS[$tool]}"
    
    if [ ! -f "$script" ]; then
        echo "Build script not found for $tool: $script"
        return 1
    fi
    
    if [ -n "$DEBUG" ]; then
        bash -x "$script" "$arch"
    else
        bash "$script" "$arch"
    fi   
}

export -f parallel_make
export -f build_tool
