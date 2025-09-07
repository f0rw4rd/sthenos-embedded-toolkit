#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/build_helpers.sh"

download_toolchain() {
    local arch=$1
    
    # This function is called to ensure toolchain exists
    # It's a no-op since toolchains are pre-downloaded in Docker image
    # The actual check happens in setup_arch
    
    return 0
}

setup_arch() {
    local arch=$1
    
    case $arch in
        arm32v5le)
            CROSS_COMPILE="arm-linux-musleabi-"
            HOST="arm-linux-musleabi"
            CFLAGS_ARCH="-march=armv5te -marm"
            CONFIG_ARCH="arm"
            ;;
        arm32v5lehf)
            CROSS_COMPILE="arm-linux-musleabihf-"
            HOST="arm-linux-musleabihf"
            CFLAGS_ARCH="-march=armv5te+fp -mfpu=vfp -mfloat-abi=hard -marm"
            CONFIG_ARCH="arm"
            ;;
        arm32v7le)
            CROSS_COMPILE="armv7l-linux-musleabihf-"
            HOST="armv7l-linux-musleabihf"
            CFLAGS_ARCH="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard"
            CONFIG_ARCH="arm"
            ;;
        arm32v7lehf)
            CROSS_COMPILE="armv7l-linux-musleabihf-"
            HOST="armv7l-linux-musleabihf"
            CFLAGS_ARCH="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard"
            CONFIG_ARCH="arm"
            ;;
        mips32v2le)
            CROSS_COMPILE="mipsel-linux-musl-"
            HOST="mipsel-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="mips"
            ;;
        mips32v2lesf)
            CROSS_COMPILE="mipsel-linux-muslsf-"
            HOST="mipsel-linux-muslsf"
            CFLAGS_ARCH=""
            CONFIG_ARCH="mips"
            ;;
        mips32v2be)
            CROSS_COMPILE="mips-linux-musl-"
            HOST="mips-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="mips"
            ;;
        mips32v2besf)
            CROSS_COMPILE="mips-linux-muslsf-"
            HOST="mips-linux-muslsf"
            CFLAGS_ARCH=""
            CONFIG_ARCH="mips"
            ;;
        ppc32be)
            CROSS_COMPILE="powerpc-linux-musl-"
            HOST="powerpc-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="powerpc"
            ;;
        ppc32besf)
            CROSS_COMPILE="powerpc-linux-muslsf-"
            HOST="powerpc-linux-muslsf"
            CFLAGS_ARCH=""
            CONFIG_ARCH="powerpc"
            ;;
        ix86le)
            CROSS_COMPILE="i686-linux-musl-"
            HOST="i686-linux-musl"
            CFLAGS_ARCH="-march=i686 -mtune=generic"
            CONFIG_ARCH="i386"
            ;;
        x86_64)
            CROSS_COMPILE="x86_64-linux-musl-"
            HOST="x86_64-linux-musl"
            CFLAGS_ARCH="-march=x86-64 -mtune=generic"
            CONFIG_ARCH="x86_64"
            ;;
        aarch64)
            CROSS_COMPILE="aarch64-linux-musl-"
            HOST="aarch64-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="aarch64"
            ;;
        mips64le)
            CROSS_COMPILE="mips64el-linux-musl-"
            HOST="mips64el-linux-musl"
            CFLAGS_ARCH="-march=mips64r2"
            CONFIG_ARCH="mips64"
            ;;
        ppc64le)
            CROSS_COMPILE="powerpc64le-linux-musl-"
            HOST="powerpc64le-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="powerpc64"
            ;;
        armeb)
            CROSS_COMPILE="armeb-linux-musleabi-"
            HOST="armeb-linux-musleabi"
            CFLAGS_ARCH="-mbig-endian"
            CONFIG_ARCH="arm"
            ;;
        armv6)
            CROSS_COMPILE="armv6-linux-musleabihf-"
            HOST="armv6-linux-musleabihf"
            CFLAGS_ARCH="-march=armv6 -mfpu=vfp -mfloat-abi=hard"
            CONFIG_ARCH="arm"
            ;;
        armv7m)
            CROSS_COMPILE="armv7m-linux-musleabi-"
            HOST="armv7m-linux-musleabi"
            CFLAGS_ARCH="-march=armv7-m -mthumb"
            CONFIG_ARCH="arm"
            ;;
        armv7r)
            CROSS_COMPILE="armv7r-linux-musleabihf-"
            HOST="armv7r-linux-musleabihf"
            # Toolchain defaults to armv5te+fp, not actual armv7-r
            CFLAGS_ARCH=""
            CONFIG_ARCH="arm"
            ;;
        mipsn32)
            CROSS_COMPILE="mips-linux-musln32sf-"
            HOST="mips-linux-musln32sf"
            # Despite the name, this toolchain uses O32 ABI by default
            CFLAGS_ARCH=""
            CONFIG_ARCH="mips"
            ;;
        mipsn32el)
            CROSS_COMPILE="mipsel-linux-musln32sf-"
            HOST="mipsel-linux-musln32sf"
            # Despite the name, this toolchain uses O32 ABI by default
            CFLAGS_ARCH=""
            CONFIG_ARCH="mips"
            ;;
        mips64n32)
            CROSS_COMPILE="mips64-linux-musln32-"
            HOST="mips64-linux-musln32"
            CFLAGS_ARCH="-mabi=n32"
            CONFIG_ARCH="mips64"
            ;;
        mips64n32el)
            CROSS_COMPILE="mips64el-linux-musln32-"
            HOST="mips64el-linux-musln32"
            CFLAGS_ARCH="-mabi=n32"
            CONFIG_ARCH="mips64"
            ;;
        powerpc64)
            CROSS_COMPILE="powerpc64-linux-musl-"
            HOST="powerpc64-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="powerpc64"
            ;;
        powerpcle)
            CROSS_COMPILE="powerpcle-linux-musl-"
            HOST="powerpcle-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="powerpc"
            ;;
        powerpclesf)
            CROSS_COMPILE="powerpcle-linux-muslsf-"
            HOST="powerpcle-linux-muslsf"
            CFLAGS_ARCH=""
            CONFIG_ARCH="powerpc"
            ;;
        microblaze)
            CROSS_COMPILE="microblaze-linux-musl-"
            HOST="microblaze-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="microblaze"
            ;;
        microblazeel)
            CROSS_COMPILE="microblazeel-linux-musl-"
            HOST="microblazeel-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="microblaze"
            ;;
        or1k)
            CROSS_COMPILE="or1k-linux-musl-"
            HOST="or1k-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="openrisc"
            ;;
        m68k)
            CROSS_COMPILE="m68k-linux-musl-"
            HOST="m68k-linux-musl"
            CFLAGS_ARCH="-mcpu=68020"
            CONFIG_ARCH="m68k"
            ;;
        sh2)
            CROSS_COMPILE="sh2-linux-musl-"
            HOST="sh2-linux-musl"
            CFLAGS_ARCH="-m2"
            CONFIG_ARCH="sh"
            ;;
        sh2eb)
            CROSS_COMPILE="sh2eb-linux-musl-"
            HOST="sh2eb-linux-musl"
            CFLAGS_ARCH="-m2 -mb"
            CONFIG_ARCH="sh"
            ;;
        sh4)
            CROSS_COMPILE="sh4-linux-musl-"
            HOST="sh4-linux-musl"
            CFLAGS_ARCH="-m4"
            CONFIG_ARCH="sh"
            ;;
        sh4eb)
            CROSS_COMPILE="sh4eb-linux-musl-"
            HOST="sh4eb-linux-musl"
            CFLAGS_ARCH="-m4 -mb"
            CONFIG_ARCH="sh"
            ;;
        s390x)
            CROSS_COMPILE="s390x-linux-musl-"
            HOST="s390x-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="s390"
            ;;
        i486)
            CROSS_COMPILE="i486-linux-musl-"
            HOST="i486-linux-musl"
            CFLAGS_ARCH="-march=i486 -mtune=generic"
            CONFIG_ARCH="i386"
            ;;
        riscv32)
            CROSS_COMPILE="riscv32-linux-musl-"
            HOST="riscv32-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="riscv"
            ;;
        riscv64)
            CROSS_COMPILE="riscv64-linux-musl-"
            HOST="riscv64-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="riscv64"
            ;;
        aarch64_be)
            CROSS_COMPILE="aarch64_be-linux-musl-"
            HOST="aarch64_be-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="aarch64"
            ;;
        mips64)
            CROSS_COMPILE="mips64-linux-musl-"
            HOST="mips64-linux-musl"
            CFLAGS_ARCH="-march=mips64r2"
            CONFIG_ARCH="mips64"
            ;;
        *)
            log_error "Unknown architecture: $arch"
            return 1
            ;;
    esac
    
    # Derive toolchain directory from CROSS_COMPILE (remove trailing dash and add -cross)
    local toolchain_dir="${CROSS_COMPILE%-}"
    toolchain_dir="${toolchain_dir}-cross"
    
    if [ ! -d "/build/toolchains/$toolchain_dir/bin" ]; then
        echo "Toolchain for $arch not found at /build/toolchains/$toolchain_dir"
        echo "Attempting to download..."
        download_toolchain "$arch" || {
            log_error "Failed to setup toolchain for $arch"
            return 1
        }
        # After download, check again
        if [ ! -d "/build/toolchains/$toolchain_dir/bin" ]; then
            log_error "Toolchain directory still not found after download: /build/toolchains/$toolchain_dir"
            return 1
        fi
    fi
    
    if [[ ":$PATH:" != *":/build/toolchains/$toolchain_dir/bin:"* ]]; then
        export PATH="/build/toolchains/$toolchain_dir/bin:$PATH"
    fi
    export HOST
    export CROSS_COMPILE
    export CONFIG_ARCH
    export_cross_compiler "$CROSS_COMPILE"
    
    if ! $CC --version >/dev/null 2>&1; then
        log_warn "Warning: Compiler $CC not found or not working for $arch"
        echo "Toolchain may need to be downloaded or is incompatible"
    fi
    
    export CFLAGS_ARCH
    
    mkdir -p /build/output/$arch
    
    return 0
}

check_binary_exists() {
    local arch=$1
    local binary=$2
    local skip_if_exists="${SKIP_IF_EXISTS:-true}"
    
    if [ "$skip_if_exists" = "true" ] && [ -f "/build/output/$arch/$binary" ]; then
        local size=$(get_binary_size "/build/output/$arch/$binary")
        log_tool "$binary" "Already built for $arch ($size), skipping..."
        return 0
    fi
    return 1
}

download_source() {
    local name=$1
    local version=$2
    local url=$3
    
    mkdir -p /build/sources
    
    local filename=$(basename "$url")
    if [ ! -f "/build/sources/$filename" ]; then
        echo "Downloading $name $version..."
        if ! wget -q --show-progress "$url" -O "/build/sources/$filename"; then
            log_error "Failed to download $name from $url"
            rm -f "/build/sources/$filename"
            return 1
        fi
    fi
    
    return 0
}