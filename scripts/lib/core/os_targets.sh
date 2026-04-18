#!/bin/bash

# Operating System target definitions and mappings

# Primary OS targets - well-tested and commonly used
readonly PRIMARY_OS_TARGETS=(
    "linux"      # Main target, most tools work here
    "windows"    # Common desktop/server OS
    "openbsd"    # Security-focused BSD
    "netbsd"     # Portable BSD variant
    "macos"      # Apple desktop/server
    "android"    # Mobile/embedded (uses Linux kernel)
)

# Secondary OS targets - supported but less commonly used
# Note: FreeBSD doesn't support static linking with Zig
readonly SECONDARY_OS_TARGETS=(
    "dragonfly"  # BSD variant with unique features
    "illumos"    # OpenSolaris derivative (SmartOS, OmniOS)
    "solaris"    # Enterprise Unix
    "aix"        # IBM enterprise Unix
    "haiku"      # BeOS successor, niche but active
    "wasi"       # WebAssembly System Interface
    "ios"        # Apple iOS
    "tvos"       # Apple tvOS
    "watchos"    # Apple watchOS
    "visionos"   # Apple visionOS
)

# All supported OS targets
readonly ALL_OS_TARGETS=("${PRIMARY_OS_TARGETS[@]}" "${SECONDARY_OS_TARGETS[@]}")

# OS family mappings for tool compatibility
declare -A OS_FAMILY
OS_FAMILY[linux]="unix"
OS_FAMILY[android]="unix"
OS_FAMILY[openbsd]="bsd"
OS_FAMILY[netbsd]="bsd"
OS_FAMILY[dragonfly]="bsd"
OS_FAMILY[macos]="darwin"
OS_FAMILY[ios]="darwin"
OS_FAMILY[tvos]="darwin"
OS_FAMILY[watchos]="darwin"
OS_FAMILY[visionos]="darwin"
OS_FAMILY[windows]="windows"
OS_FAMILY[illumos]="unix"
OS_FAMILY[solaris]="unix"
OS_FAMILY[aix]="unix"
OS_FAMILY[haiku]="haiku"
OS_FAMILY[wasi]="wasm"

# OS-specific notes for users
declare -A OS_NOTES
OS_NOTES[windows]="Requires MinGW runtime. Some POSIX features may not work."
OS_NOTES[macos]="May require code signing for certain operations."
OS_NOTES[ios]="Requires jailbroken device for most tools."
OS_NOTES[android]="Works best on rooted devices. Some tools require Termux."
OS_NOTES[wasi]="Limited syscall support. Not all tools will work."
OS_NOTES[aix]="Limited testing. May require IBM XL C runtime."
OS_NOTES[solaris]="Tested on illumos. Oracle Solaris may have differences."

# Check if an OS is supported
is_supported_os() {
    local os=$1
    for supported_os in "${ALL_OS_TARGETS[@]}"; do
        if [ "$os" = "$supported_os" ]; then
            return 0
        fi
    done
    return 1
}

# Check if an OS is a primary target
is_primary_os() {
    local os=$1
    for primary_os in "${PRIMARY_OS_TARGETS[@]}"; do
        if [ "$os" = "$primary_os" ]; then
            return 0
        fi
    done
    return 1
}

# Get OS family for compatibility checking
get_os_family() {
    local os=$1
    echo "${OS_FAMILY[$os]:-unknown}"
}

# Check if tool supports an OS family
tool_supports_os_family() {
    local tool_families=$1  # Comma-separated list
    local target_os=$2
    
    local target_family=$(get_os_family "$target_os")
    
    # Check if target family is in supported families
    local IFS=','
    for family in $tool_families; do
        if [ "$family" = "$target_family" ] || [ "$family" = "any" ]; then
            return 0
        fi
    done
    
    return 1
}

# Print OS compatibility info
print_os_info() {
    local os=$1
    
    if ! is_supported_os "$os"; then
        echo "ERROR: '$os' is not a supported OS target"
        echo "Supported targets: ${ALL_OS_TARGETS[*]}"
        return 1
    fi
    
    local family=$(get_os_family "$os")
    local category="Secondary"
    if is_primary_os "$os"; then
        category="Primary"
    fi
    
    echo "OS: $os"
    echo "Family: $family"
    echo "Category: $category target"
    
    if [ -n "${OS_NOTES[$os]}" ]; then
        echo "Note: ${OS_NOTES[$os]}"
    fi
}

# Validate OS target for Zig
validate_zig_os() {
    local os=$1
    
    # Special case: android is built as linux target
    if [ "$os" = "android" ]; then
        echo "linux"
        return 0
    fi
    
    if is_supported_os "$os"; then
        echo "$os"
        return 0
    fi
    
    return 1
}

# Get recommended ABI for OS
get_default_abi() {
    local os=$1
    
    case "$os" in
        windows)
            echo "gnu"  # MinGW for better compatibility
            ;;
        linux)
            echo "musl"  # Static linking preferred
            ;;
        openbsd|netbsd|dragonfly)
            echo ""  # BSDs use their native libc
            ;;
        macos|ios|tvos|watchos|visionos)
            echo "none"  # Darwin doesn't use GNU/musl
            ;;
        android)
            echo "android"  # Android-specific ABI
            ;;
        wasi)
            echo "musl"  # WASI uses musl
            ;;
        *)
            echo ""  # Let Zig choose default
            ;;
    esac
}

export -f is_supported_os
export -f is_primary_os
export -f get_os_family
export -f tool_supports_os_family
export -f print_os_info
export -f validate_zig_os
export -f get_default_abi