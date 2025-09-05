#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/build_helpers.sh"

parallel_make() {
    make -j$(nproc) "$@"
}
declare -A TOOL_SCRIPTS=(
    ["strace"]="$SCRIPT_DIR/../tools/build-strace.sh"
    ["busybox"]="$SCRIPT_DIR/../tools/build-busybox.sh"
    ["busybox_nodrop"]="$SCRIPT_DIR/../tools/build-busybox.sh"
    ["bash"]="$SCRIPT_DIR/../tools/build-bash.sh"
    ["socat"]="$SCRIPT_DIR/../tools/build-socat.sh"
    ["socat-ssl"]="$SCRIPT_DIR/../tools/build-socat-ssl.sh"
    ["tcpdump"]="$SCRIPT_DIR/../tools/build-tcpdump.sh"
    ["ncat"]="$SCRIPT_DIR/../tools/build-ncat.sh"
    ["ncat-ssl"]="$SCRIPT_DIR/../tools/build-ncat-ssl.sh"
    ["gdbserver"]="$SCRIPT_DIR/../tools/build-gdbserver.sh"
    ["nmap"]="$SCRIPT_DIR/../tools/build-nmap.sh"
    ["dropbear"]="$SCRIPT_DIR/../tools/build-dropbear.sh"
    ["ltrace"]="$SCRIPT_DIR/../tools/build-ltrace.sh"
    ["ply"]="$SCRIPT_DIR/../tools/build-ply.sh"
    ["can-utils"]="$SCRIPT_DIR/../tools/build-can-utils.sh"
    ["shell-static"]="$SCRIPT_DIR/../tools/build-shell-static.sh"
    ["custom"]="$SCRIPT_DIR/../tools/build-custom.sh"
)

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
    
    chmod +x "$script"
    
    if [ "$tool" = "busybox_nodrop" ]; then
        "$script" "$arch" "nodrop"
    else
        "$script" "$arch"
    fi
}

export -f parallel_make
export -f build_tool