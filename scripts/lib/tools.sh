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

    if [ -z "${TOOL_SCRIPTS[$tool]}" ]; then
        echo "Unknown tool: $tool"
        return 1
    fi    
    
    local script="${TOOL_SCRIPTS[$tool]}"
    
    if [ ! -f "$script" ]; then
        echo "Build script not found for $tool: $script"
        return 1
    fi
    
    # Cap each build so a single hang (a stuck configure run-test under qemu, a
    # wedged make, a network stall) can't stall the whole matrix. On timeout the
    # build is killed and counted as a failure, and the loop moves on.
    local to="${TOOL_BUILD_TIMEOUT:-1800}"
    local rc
    if [ -n "$DEBUG" ]; then
        timeout -k 60 -s TERM "$to" bash -x "$script" "$arch"
    else
        timeout -k 60 -s TERM "$to" bash "$script" "$arch"
    fi
    rc=$?
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        echo "TIMEOUT: $tool for $arch exceeded ${to}s — killed" >&2
    fi
    return $rc
}

export -f parallel_make
export -f build_tool
