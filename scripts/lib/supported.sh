#!/bin/bash

SUPPORTED_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SUPPORTED_SCRIPT_DIR/core/architectures.sh"

if [ -z "${TOOL_SCRIPTS+x}" ]; then
    SCRIPT_DIR="$SUPPORTED_SCRIPT_DIR"
    source "$SUPPORTED_SCRIPT_DIR/common.sh"
fi

SUPPORTED_ARCHS=("${ALL_ARCHITECTURES[@]}")

SUPPORTED_STATIC_TOOLS=($(printf '%s\n' "${!TOOL_SCRIPTS[@]}" | sort))

SUPPORTED_SHARED_LIBS=(
    libshells
    libdesock
    libtlsnoverify
    libcustom
)

export SUPPORTED_ARCHS
export SUPPORTED_STATIC_TOOLS  
export SUPPORTED_SHARED_LIBS
