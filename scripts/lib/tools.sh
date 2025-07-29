#!/bin/bash
# Tool dispatcher - routes to individual tool build scripts

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Parallel make helper
parallel_make() {
    make -j$(nproc) "$@"
}

# Tool registry - maps tool names to their build scripts
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
    # GDB disabled from default builds due to static linking complexities
    # To build manually: ./build gdb --arch x86_64
    ["gdb"]="$SCRIPT_DIR/../tools/build-gdb.sh"
    ["nmap"]="$SCRIPT_DIR/../tools/build-nmap.sh"
    ["dropbear"]="$SCRIPT_DIR/../tools/build-dropbear.sh"
)

# Build dispatcher
build_tool() {
    local tool=$1
    local arch=$2
    
    # Check if tool has a build script
    if [ -z "${TOOL_SCRIPTS[$tool]}" ]; then
        echo "Unknown tool: $tool"
        return 1
    fi
    
    local script="${TOOL_SCRIPTS[$tool]}"
    
    # Check if script exists
    if [ ! -f "$script" ]; then
        echo "Build script not found for $tool: $script"
        return 1
    fi
    
    # Make sure script is executable
    chmod +x "$script"
    
    # Execute the build script
    # Special handling for busybox_nodrop
    if [ "$tool" = "busybox_nodrop" ]; then
        "$script" "$arch" "nodrop"
    else
        "$script" "$arch"
    fi
}

# Export functions
export -f parallel_make
export -f build_tool