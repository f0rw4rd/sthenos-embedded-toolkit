#!/bin/bash
# Build script for GDB - downloads pre-built static binaries from gdb-static project
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Main build function
build_gdb() {
    local arch=$1
    local mode=${2:-release}
    
    echo "[gdb] Downloading pre-built static GDB for $arch..."
    
    # Check if already built - check for the actual GDB directories
    local variant="${GDB_VARIANT:-both}"
    local has_gdb=false
    
    case "$variant" in
        slim)
            if [ -d "/build/output/$arch/gdb-slim" ] && [ -f "/build/output/$arch/gdb-slim/gdb" ]; then
                has_gdb=true
            fi
            ;;
        full)
            if [ -d "/build/output/$arch/gdb-full" ] && [ -f "/build/output/$arch/gdb-full/gdb" ]; then
                has_gdb=true
            fi
            ;;
        both)
            if [ -d "/build/output/$arch/gdb-slim" ] && [ -f "/build/output/$arch/gdb-slim/gdb" ] && \
               [ -d "/build/output/$arch/gdb-full" ] && [ -f "/build/output/$arch/gdb-full/gdb" ]; then
                has_gdb=true
            fi
            ;;
    esac
    
    if [ "$has_gdb" = "true" ]; then
        echo "[gdb] Already built for $arch (variant: $variant)"
        return 0
    fi
    
    # Use the download script
    "$SCRIPT_DIR/download-gdb-static.sh" download "$arch" "$variant" || {
        echo "[gdb] Failed to download GDB for $arch"
        return 1
    }
    
    echo "[gdb] Successfully installed GDB for $arch"
    return 0
}

# Also support downloading Python if needed
download_python() {
    local arch=$1
    
    echo "[python] Downloading static Python for $arch..."
    
    # Check if already downloaded
    if [ -f "/build/output/$arch/python3" ]; then
        echo "[python] Already downloaded for $arch"
        return 0
    fi
    
    # Use the download script
    "$SCRIPT_DIR/download-python-static.sh" download "$arch" || {
        echo "[python] Failed to download Python for $arch"
        echo "[python] Note: Python is optional for GDB functionality"
        return 0  # Don't fail the build
    }
    
    echo "[python] Successfully installed Python for $arch"
    return 0
}

# Main entry point
main() {
    local arch="${1:-}"
    local mode="${2:-release}"
    
    if [ -z "$arch" ]; then
        echo "Usage: $0 <architecture> [mode]"
        echo "Example: $0 x86_64"
        echo ""
        echo "This script downloads pre-built static GDB binaries from the gdb-static project"
        echo "Optional: Also downloads static Python for enhanced GDB functionality"
        exit 1
    fi
    
    # Download GDB
    build_gdb "$arch" "$mode" || exit 1
    
    # Optionally download Python (don't fail if it doesn't work)
    if [ "${DOWNLOAD_PYTHON:-false}" = "true" ]; then
        download_python "$arch" || true
    fi
}

main "$@"