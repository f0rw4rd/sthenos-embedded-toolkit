#!/bin/bash

# Operating System target definitions and mappings

# Source guard: prevent errors from re-declaring readonly variables
[[ -n "${_OS_TARGETS_LOADED:-}" ]] && return 0
_OS_TARGETS_LOADED=1

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

# Extract OS family from the current ZIG_TARGET
# Returns the OS family (e.g., "darwin", "bsd", "unix", "windows")
get_os_family_from_target() {
    local target="${ZIG_TARGET:-}"
    if [[ "$target" == *"macos"* ]] || [[ "$target" == *"darwin"* ]] || \
       [[ "$target" == *"ios"* ]] || [[ "$target" == *"tvos"* ]] || \
       [[ "$target" == *"watchos"* ]] || [[ "$target" == *"visionos"* ]]; then
        echo "darwin"
    elif [[ "$target" == *"bsd"* ]] || [[ "$target" == *"dragonfly"* ]]; then
        echo "bsd"
    elif [[ "$target" == *"windows"* ]]; then
        echo "windows"
    elif [[ "$target" == *"wasi"* ]]; then
        echo "wasm"
    else
        echo "unix"
    fi
}

# Whether the current Zig target platform supports -static linking.
# Returns 0 (true) for Linux/Android/Windows/WASI, 1 (false) for Darwin/BSDs.
platform_supports_static() {
    if [ "${USE_ZIG:-0}" != "1" ]; then
        return 0
    fi
    local target="${ZIG_TARGET:-}"
    if [[ "$target" == *"macos"* ]] || [[ "$target" == *"darwin"* ]] || \
       [[ "$target" == *"bsd"* ]] || [[ "$target" == *"dragonfly"* ]]; then
        return 1
    fi
    return 0
}

# Whether Zig 0.16.0 ships a libc for the given target triple.
# Without a bundled libc, system headers (stdio.h, etc.) are unavailable.
# List extracted from `zig targets` .libc section.
zig_has_libc() {
    local triple="$1"
    case "$triple" in
        aarch64-freebsd-none|aarch64-freebsd) return 0 ;;
        aarch64-linux-gnu|aarch64-linux-musl) return 0 ;;
        aarch64-macos-none|aarch64-macos) return 0 ;;
        aarch64-netbsd-none|aarch64-netbsd) return 0 ;;
        aarch64-openbsd-none|aarch64-openbsd) return 0 ;;
        aarch64-windows-gnu) return 0 ;;
        aarch64_be-linux-gnu|aarch64_be-linux-musl) return 0 ;;
        aarch64_be-netbsd-none) return 0 ;;
        arm-freebsd-eabihf) return 0 ;;
        arm-linux-gnueabi|arm-linux-gnueabihf) return 0 ;;
        arm-linux-musleabi|arm-linux-musleabihf) return 0 ;;
        arm-netbsd-eabi|arm-netbsd-eabihf) return 0 ;;
        armeb-linux-gnueabi|armeb-linux-gnueabihf) return 0 ;;
        armeb-linux-musleabi|armeb-linux-musleabihf) return 0 ;;
        armeb-netbsd-eabi|armeb-netbsd-eabihf) return 0 ;;
        loongarch64-linux-gnu|loongarch64-linux-gnusf) return 0 ;;
        loongarch64-linux-musl|loongarch64-linux-muslsf) return 0 ;;
        m68k-linux-gnu|m68k-linux-musl) return 0 ;;
        m68k-netbsd-none) return 0 ;;
        mips-linux-gnueabi|mips-linux-gnueabihf) return 0 ;;
        mips-linux-musleabi|mips-linux-musleabihf) return 0 ;;
        mips-netbsd-eabi|mips-netbsd-eabihf) return 0 ;;
        mipsel-linux-gnueabi|mipsel-linux-gnueabihf) return 0 ;;
        mipsel-linux-musleabi|mipsel-linux-musleabihf) return 0 ;;
        mipsel-netbsd-eabi|mipsel-netbsd-eabihf) return 0 ;;
        mips64-linux-gnuabi64|mips64-linux-gnuabin32) return 0 ;;
        mips64-linux-muslabi64|mips64-linux-muslabin32) return 0 ;;
        mips64el-linux-gnuabi64|mips64el-linux-gnuabin32) return 0 ;;
        mips64el-linux-muslabi64|mips64el-linux-muslabin32) return 0 ;;
        powerpc-freebsd-eabihf) return 0 ;;
        powerpc-linux-gnueabi|powerpc-linux-gnueabihf) return 0 ;;
        powerpc-linux-musleabi|powerpc-linux-musleabihf) return 0 ;;
        powerpc-netbsd-eabi|powerpc-netbsd-eabihf) return 0 ;;
        powerpc64-freebsd-none) return 0 ;;
        powerpc64-linux-gnu|powerpc64-linux-musl) return 0 ;;
        powerpc64le-freebsd-none) return 0 ;;
        powerpc64le-linux-gnu|powerpc64le-linux-musl) return 0 ;;
        riscv32-linux-gnu|riscv32-linux-musl) return 0 ;;
        riscv64-freebsd-none) return 0 ;;
        riscv64-linux-gnu|riscv64-linux-musl) return 0 ;;
        s390x-linux-gnu|s390x-linux-musl) return 0 ;;
        sparc-linux-gnu) return 0 ;;
        sparc-netbsd-none) return 0 ;;
        sparc64-linux-gnu) return 0 ;;
        sparc64-netbsd-none) return 0 ;;
        thumb-linux-musleabi|thumb-linux-musleabihf) return 0 ;;
        thumb-windows-gnu) return 0 ;;
        thumbeb-linux-musleabi|thumbeb-linux-musleabihf) return 0 ;;
        wasm32-wasi-musl|wasm32-wasi) return 0 ;;
        x86-freebsd-none) return 0 ;;
        x86-linux-gnu|x86-linux-musl) return 0 ;;
        x86-netbsd-none) return 0 ;;
        x86-windows-gnu) return 0 ;;
        x86_64-freebsd-none|x86_64-freebsd) return 0 ;;
        x86_64-linux-gnu|x86_64-linux-gnux32) return 0 ;;
        x86_64-linux-musl|x86_64-linux-muslx32) return 0 ;;
        x86_64-macos-none|x86_64-macos) return 0 ;;
        x86_64-netbsd-none|x86_64-netbsd) return 0 ;;
        x86_64-openbsd-none|x86_64-openbsd) return 0 ;;
        x86_64-windows-gnu) return 0 ;;
        *) return 1 ;;
    esac
}

export -f is_supported_os
export -f is_primary_os
export -f get_os_family
export -f get_os_family_from_target
export -f tool_supports_os_family
export -f print_os_info
export -f validate_zig_os
export -f get_default_abi
export -f platform_supports_static
export -f zig_has_libc