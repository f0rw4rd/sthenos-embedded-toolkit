#!/bin/bash
echo "Architecture passed: $1"
echo "USE_ZIG: ${USE_ZIG:-not set}"
echo "ZIG_TARGET: ${ZIG_TARGET:-not set}"
echo "CC: ${CC:-not set}"
echo "DEPS_PREFIX: ${DEPS_PREFIX:-not set}"

# Now test building
if [ "$1" = "x86_64_windows" ]; then
    echo "Testing custom build for Windows..."
    # The arch should be preserved as x86_64_windows
    mkdir -p /build/output/$1
    echo "Created directory: /build/output/$1"
    
    # Check what get_output_path would return
    source /build/scripts/lib/build_helpers.sh
    output_path=$(get_output_path "$1" "custom")
    echo "get_output_path returns: $output_path"
fi