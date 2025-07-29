#!/bin/bash
# Download pre-built glibc toolchains for preload library builds
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Bootlin toolchain URLs
declare -A TOOLCHAIN_URLS=(
    ["x86_64"]="https://toolchains.bootlin.com/downloads/releases/toolchains/x86-64/tarballs/x86-64--glibc--stable-2024.02-1.tar.bz2"
    ["aarch64"]="https://toolchains.bootlin.com/downloads/releases/toolchains/aarch64/tarballs/aarch64--glibc--stable-2024.02-1.tar.bz2"
    ["arm32v7le"]="https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--glibc--stable-2024.02-1.tar.bz2"
    ["i486"]="https://toolchains.bootlin.com/downloads/releases/toolchains/x86-i686/tarballs/x86-i686--glibc--stable-2024.02-1.tar.bz2"
    ["mips64le"]="https://toolchains.bootlin.com/downloads/releases/toolchains/mips64el-n32/tarballs/mips64el-n32--glibc--stable-2024.02-1.tar.bz2"
    ["ppc64le"]="https://toolchains.bootlin.com/downloads/releases/toolchains/powerpc64le-power8/tarballs/powerpc64le-power8--glibc--stable-2024.02-1.tar.bz2"
    ["riscv64"]="https://toolchains.bootlin.com/downloads/releases/toolchains/riscv64-lp64d/tarballs/riscv64-lp64d--glibc--stable-2024.02-1.tar.bz2"
    ["s390x"]="https://toolchains.bootlin.com/downloads/releases/toolchains/s390x-z13/tarballs/s390x-z13--glibc--stable-2024.02-1.tar.bz2"
    ["aarch64be"]="https://toolchains.bootlin.com/downloads/releases/toolchains/aarch64be/tarballs/aarch64be--glibc--stable-2024.02-1.tar.bz2"
    ["mips64"]="https://toolchains.bootlin.com/downloads/releases/toolchains/mips64-n32/tarballs/mips64-n32--glibc--stable-2024.02-1.tar.bz2"
    ["armv5"]="https://toolchains.bootlin.com/downloads/releases/toolchains/armv5-eabi/tarballs/armv5-eabi--glibc--stable-2024.02-1.tar.bz2"
    ["armv6"]="https://toolchains.bootlin.com/downloads/releases/toolchains/armv6-eabihf/tarballs/armv6-eabihf--glibc--stable-2024.02-1.tar.bz2"
    ["ppc32"]="https://toolchains.bootlin.com/downloads/releases/toolchains/powerpc-e500mc/tarballs/powerpc-e500mc--glibc--stable-2024.02-1.tar.bz2"
    ["sparc64"]="https://toolchains.bootlin.com/downloads/releases/toolchains/sparc64/tarballs/sparc64--glibc--stable-2024.02-1.tar.bz2"
    ["sh4"]="https://toolchains.bootlin.com/downloads/releases/toolchains/sh-sh4/tarballs/sh-sh4--glibc--stable-2024.02-1.tar.bz2"
    ["mips32"]="https://toolchains.bootlin.com/downloads/releases/toolchains/mips32/tarballs/mips32--glibc--stable-2024.02-1.tar.bz2"
    ["mips32el"]="https://toolchains.bootlin.com/downloads/releases/toolchains/mips32el/tarballs/mips32el--glibc--stable-2024.02-1.tar.bz2"
    ["riscv32"]="https://toolchains.bootlin.com/downloads/releases/toolchains/riscv32-ilp32d/tarballs/riscv32-ilp32d--glibc--stable-2024.05-1.tar.xz"
    ["microblazeel"]="https://toolchains.bootlin.com/downloads/releases/toolchains/microblazeel/tarballs/microblazeel--glibc--stable-2024.02-1.tar.bz2"
    ["microblazebe"]="https://toolchains.bootlin.com/downloads/releases/toolchains/microblazebe/tarballs/microblazebe--glibc--stable-2024.02-1.tar.bz2"
    ["nios2"]="https://toolchains.bootlin.com/downloads/releases/toolchains/nios2/tarballs/nios2--glibc--stable-2024.02-1.tar.bz2"
    ["openrisc"]="https://toolchains.bootlin.com/downloads/releases/toolchains/openrisc/tarballs/openrisc--glibc--stable-2024.02-1.tar.bz2"
    ["arcle"]="https://toolchains.bootlin.com/downloads/releases/toolchains/arcle-hs38/tarballs/arcle-hs38--glibc--stable-2024.02-1.tar.bz2"
    ["m68k"]="https://toolchains.bootlin.com/downloads/releases/toolchains/m68k-68xxx/tarballs/m68k-68xxx--glibc--stable-2024.02-1.tar.bz2"
)

download_toolchain() {
    local arch="$1"
    local url="${TOOLCHAIN_URLS[$arch]}"
    
    if [ -z "$url" ]; then
        log_error "No toolchain URL defined for $arch"
        return 1
    fi
    
    local filename=$(basename "$url")
    local toolchain_dir="/build/toolchains-preload"
    local target_dir=""
    local temp_dir=""
    
    # Cleanup function
    cleanup() {
        if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
            cd /
            rm -rf "$temp_dir"
        fi
    }
    trap cleanup EXIT
    
    # Map architecture to toolchain directory name
    case "$arch" in
        x86_64)     target_dir="$toolchain_dir/x86_64-unknown-linux-gnu" ;;
        aarch64)    target_dir="$toolchain_dir/aarch64-unknown-linux-gnu" ;;
        arm32v7le)  target_dir="$toolchain_dir/arm-cortex_a7-linux-gnueabihf" ;;
        i486)       target_dir="$toolchain_dir/i486-unknown-linux-gnu" ;;
        mips64le)   target_dir="$toolchain_dir/mips64el-unknown-linux-gnu" ;;
        ppc64le)    target_dir="$toolchain_dir/powerpc64le-unknown-linux-gnu" ;;
        riscv64)    target_dir="$toolchain_dir/riscv64-unknown-linux-gnu" ;;
        s390x)      target_dir="$toolchain_dir/s390x-unknown-linux-gnu" ;;
        aarch64be)  target_dir="$toolchain_dir/aarch64be-unknown-linux-gnu" ;;
        mips64)     target_dir="$toolchain_dir/mips64-unknown-linux-gnu" ;;
        armv5)      target_dir="$toolchain_dir/armv5-unknown-linux-gnueabi" ;;
        armv6)      target_dir="$toolchain_dir/armv6-unknown-linux-gnueabihf" ;;
        ppc32)      target_dir="$toolchain_dir/powerpc-unknown-linux-gnu" ;;
        sparc64)    target_dir="$toolchain_dir/sparc64-unknown-linux-gnu" ;;
        sh4)        target_dir="$toolchain_dir/sh4-unknown-linux-gnu" ;;
        mips32)     target_dir="$toolchain_dir/mips32-unknown-linux-gnu" ;;
        mips32el)   target_dir="$toolchain_dir/mips32el-unknown-linux-gnu" ;;
        riscv32)    target_dir="$toolchain_dir/riscv32-unknown-linux-gnu" ;;
        microblazeel) target_dir="$toolchain_dir/microblazeel-unknown-linux-gnu" ;;
        microblazebe) target_dir="$toolchain_dir/microblazebe-unknown-linux-gnu" ;;
        nios2)      target_dir="$toolchain_dir/nios2-unknown-linux-gnu" ;;
        openrisc)   target_dir="$toolchain_dir/openrisc-unknown-linux-gnu" ;;
        arcle)      target_dir="$toolchain_dir/arcle-unknown-linux-gnu" ;;
        m68k)       target_dir="$toolchain_dir/m68k-unknown-linux-gnu" ;;
    esac
    
    # Check if already downloaded
    if [ -d "$target_dir/bin" ]; then
        log "Toolchain for $arch already exists"
        return 0
    fi
    
    log "Downloading toolchain for $arch..."
    
    # Create temp directory with unique name for parallel downloads
    temp_dir="/tmp/toolchain-${arch}-$$-$(date +%s%N)"
    mkdir -p "$temp_dir" || {
        log_error "Failed to create temp directory: $temp_dir"
        return 1
    }
    cd "$temp_dir" || {
        log_error "Failed to enter temp directory: $temp_dir"
        return 1
    }
    
    # Download with retries (quiet mode, no progress bar)
    local max_retries=3
    local retry_count=0
    local download_success=false
    
    while [ $retry_count -lt $max_retries ]; do
        if wget -q --tries=2 --timeout=30 "$url" -O "$filename"; then
            download_success=true
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log "Download failed for $arch, retrying ($retry_count/$max_retries)..."
                sleep 5
            fi
        fi
    done
    
    if [ "$download_success" = false ]; then
        log_error "Failed to download toolchain for $arch after $max_retries attempts"
        return 1
    fi
    
    # Verify download
    if [ ! -f "$filename" ]; then
        log_error "Downloaded file not found: $filename"
        return 1
    fi
    
    # Extract (handle both .tar.bz2 and .tar.xz)
    log "Extracting toolchain for $arch..."
    if [[ "$filename" == *.tar.xz ]]; then
        if ! tar xJf "$filename"; then
            log_error "Failed to extract toolchain for $arch"
            log_error "Current directory: $(pwd)"
            log_error "Files in directory: $(ls -la)"
            return 1
        fi
    else
        if ! tar xf "$filename"; then
            log_error "Failed to extract toolchain for $arch"
            log_error "Current directory: $(pwd)"
            log_error "Files in directory: $(ls -la)"
            return 1
        fi
    fi
    
    # Find the extracted directory
    local extracted_dir=$(find . -maxdepth 1 -type d -name "*" | grep -v "^\.$" | head -1)
    
    # Move to target location
    mkdir -p "$(dirname "$target_dir")"
    mv "$extracted_dir" "$target_dir"
    
    # Create compatibility symlinks
    cd "$target_dir/bin"
    
    # Helper function to create toolchain symlinks
    create_symlinks() {
        local src_prefix="$1"
        local dst_prefix="$2"
        local use_br_real="${3:-false}"
        
        for tool in gcc g++ ar as ld strip ranlib; do
            if [ "$use_br_real" = "true" ] && ([ "$tool" = "gcc" ] || [ "$tool" = "g++" ]); then
                if [ -f "${src_prefix}-$tool.br_real" ]; then
                    ln -sf "${src_prefix}-$tool.br_real" "${dst_prefix}-$tool.br_real"
                    ln -sf "${src_prefix}-$tool" "${dst_prefix}-$tool"
                fi
            else
                if [ -f "${src_prefix}-$tool" ]; then
                    ln -sf "${src_prefix}-$tool" "${dst_prefix}-$tool"
                fi
            fi
        done
    }
    
    # Architecture to Bootlin prefix mapping
    case "$arch" in
        x86_64)       create_symlinks "x86_64-buildroot-linux-gnu" "x86_64-unknown-linux-gnu" true ;;
        aarch64)      create_symlinks "aarch64-buildroot-linux-gnu" "aarch64-unknown-linux-gnu" true ;;
        arm32v7le)    create_symlinks "arm-buildroot-linux-gnueabihf" "arm-cortex_a7-linux-gnueabihf" true ;;
        i486)         create_symlinks "i686-buildroot-linux-gnu" "i486-unknown-linux-gnu" true ;;
        mips64le)     create_symlinks "mips64el-buildroot-linux-gnu" "mips64el-unknown-linux-gnu" true ;;
        ppc64le)      create_symlinks "powerpc64le-buildroot-linux-gnu" "powerpc64le-unknown-linux-gnu" true ;;
        riscv64)      create_symlinks "riscv64-buildroot-linux-gnu" "riscv64-unknown-linux-gnu" true ;;
        s390x)        create_symlinks "s390x-buildroot-linux-gnu" "s390x-unknown-linux-gnu" true ;;
        aarch64be)    create_symlinks "aarch64_be-buildroot-linux-gnu" "aarch64be-unknown-linux-gnu" true ;;
        mips64)       create_symlinks "mips64-buildroot-linux-gnu" "mips64-unknown-linux-gnu" true ;;
        armv5)        create_symlinks "arm-buildroot-linux-gnueabi" "armv5-unknown-linux-gnueabi" true ;;
        armv6)        create_symlinks "arm-buildroot-linux-gnueabihf" "armv6-unknown-linux-gnueabihf" true ;;
        ppc32)        create_symlinks "powerpc-buildroot-linux-gnu" "powerpc-unknown-linux-gnu" true ;;
        sparc64)      create_symlinks "sparc64-buildroot-linux-gnu" "sparc64-unknown-linux-gnu" true ;;
        sh4)          create_symlinks "sh4-buildroot-linux-gnu" "sh4-unknown-linux-gnu" true ;;
        mips32)       create_symlinks "mips-buildroot-linux-gnu" "mips32-unknown-linux-gnu" true ;;
        mips32el)     create_symlinks "mipsel-buildroot-linux-gnu" "mips32el-unknown-linux-gnu" true ;;
        riscv32)      create_symlinks "riscv32-buildroot-linux-gnu" "riscv32-unknown-linux-gnu" true ;;
        microblazeel) create_symlinks "microblazeel-buildroot-linux-gnu" "microblazeel-unknown-linux-gnu" true ;;
        microblazebe) create_symlinks "microblaze-buildroot-linux-gnu" "microblazebe-unknown-linux-gnu" true ;;
        nios2)        create_symlinks "nios2-buildroot-linux-gnu" "nios2-unknown-linux-gnu" true ;;
        openrisc)     create_symlinks "or1k-buildroot-linux-gnu" "openrisc-unknown-linux-gnu" true ;;
        arcle)        create_symlinks "arc-buildroot-linux-gnu" "arcle-unknown-linux-gnu" true ;;
        m68k)         create_symlinks "m68k-buildroot-linux-gnu" "m68k-unknown-linux-gnu" true ;;
    esac
    
    # Cleanup
    log "Toolchain for $arch installed successfully"
    return 0
}

# Main - only run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "==================================="
    echo "Downloading Preload Toolchains"
    echo "==================================="

    # Download all defined toolchains
    for arch in "${!TOOLCHAIN_URLS[@]}"; do
        download_toolchain "$arch" || {
            log_error "Failed to download toolchain for $arch"
        }
    done

    echo
    echo "Toolchain download complete!"
fi