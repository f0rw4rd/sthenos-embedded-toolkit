#!/bin/bash
# Single source of truth for supported architectures and tools

# Get the script directory
SUPPORTED_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the central architecture definitions
source "$SUPPORTED_SCRIPT_DIR/core/architectures.sh"

# Source common.sh to get TOOL_SCRIPTS if not already loaded
if [ -z "${TOOL_SCRIPTS+x}" ]; then
    # Set SCRIPT_DIR for common.sh
    SCRIPT_DIR="$SUPPORTED_SCRIPT_DIR"
    source "$SUPPORTED_SCRIPT_DIR/common.sh"
fi

# All supported architectures - from architectures.sh
SUPPORTED_ARCHS=("${ALL_ARCHITECTURES[@]}")

# Static tools - from TOOL_SCRIPTS in common.sh
SUPPORTED_STATIC_TOOLS=($(printf '%s\n' "${!TOOL_SCRIPTS[@]}" | sort))

# Shared libraries (for LD_PRELOAD)
SUPPORTED_SHARED_LIBS=(
    custom-lib
    libdesock 
    shell-env shell-helper shell-bind shell-reverse shell-fifo 
    tls-noverify
)

# Export arrays for use in other scripts
export SUPPORTED_ARCHS
export SUPPORTED_STATIC_TOOLS  
export SUPPORTED_SHARED_LIBS