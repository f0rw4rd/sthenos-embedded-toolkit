#!/bin/bash
# Common functions and variables for all build scripts

# Ensure toolchain exists (fail if missing)
download_toolchain() {
    local arch=$1
    local toolchain_dir="/build/toolchains/$arch"
    
    # Check if toolchain exists
    if [ -d "$toolchain_dir/bin" ]; then
        return 0
    fi
    
    # Toolchain missing - fail immediately
    echo "ERROR: Toolchain not found for $arch"
    echo "Expected toolchain directory: $toolchain_dir"
    echo "Toolchains should be pre-downloaded during Docker image build"
    echo "Please rebuild the Docker image with: docker build -t stheno-toolkit ."
    return 1
}

# Set architecture variables
setup_arch() {
    local arch=$1
    
    # Set variables based on architecture
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
            # ARMv5TE with VFP for hard-float
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
        mips32v2be)
            CROSS_COMPILE="mips-linux-musl-"
            HOST="mips-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="mips"
            ;;
        ppc32be)
            CROSS_COMPILE="powerpc-linux-musl-"
            HOST="powerpc-linux-musl"
            CFLAGS_ARCH=""
            CONFIG_ARCH="powerpc"
            ;;
        ix86le)
            CROSS_COMPILE="i686-linux-musl-"
            HOST="i686-linux-musl"
            CFLAGS_ARCH="-march=i686 -mtune=generic"
            CONFIG_ARCH="i386"
            ;;
        # 64-bit architectures
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
        # Additional ARM variants
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
            CFLAGS_ARCH="-march=armv7-r"
            CONFIG_ARCH="arm"
            ;;
        # Additional MIPS variants
        mipsn32)
            CROSS_COMPILE="mips-linux-musln32sf-"
            HOST="mips-linux-musln32sf"
            CFLAGS_ARCH="-mabi=n32"
            CONFIG_ARCH="mips"
            ;;
        mipsn32el)
            CROSS_COMPILE="mipsel-linux-musln32sf-"
            HOST="mipsel-linux-musln32sf"
            CFLAGS_ARCH="-mabi=n32"
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
        # PowerPC variants
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
        # Other architectures
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
        # x86 variants
        i486)
            CROSS_COMPILE="i486-linux-musl-"
            HOST="i486-linux-musl"
            CFLAGS_ARCH="-march=i486 -mtune=generic"
            CONFIG_ARCH="i386"
            ;;
        # RISC-V
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
        # Additional architectures
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
            echo "Unknown architecture: $arch"
            return 1
            ;;
    esac
    
    # Use architecture name directly for toolchain directory
    local toolchain_dir="$arch"
    
    # Check if toolchain exists, download if needed
    if [ ! -d "/build/toolchains/$toolchain_dir/bin" ]; then
        echo "Toolchain for $arch not found, downloading..."
        download_toolchain "$arch" || {
            echo "Failed to download toolchain for $arch"
            return 1
        }
    fi
    
    # Export minimal toolchain variables only (don't export CFLAGS/LDFLAGS here)
    # Only add to PATH if not already there
    if [[ ":$PATH:" != *":/build/toolchains/$toolchain_dir/bin:"* ]]; then
        export PATH="/build/toolchains/$toolchain_dir/bin:$PATH"
    fi
    export HOST
    export CROSS_COMPILE
    export CONFIG_ARCH
    # Export individual tool variables but NOT CFLAGS/LDFLAGS
    export CC="${CROSS_COMPILE}gcc"
    export CXX="${CROSS_COMPILE}g++"
    export AR="${CROSS_COMPILE}ar"
    export STRIP="${CROSS_COMPILE}strip"
    export RANLIB="${CROSS_COMPILE}ranlib"
    export LD="${CROSS_COMPILE}ld"
    
    # Test if the compiler works
    if ! $CC --version >/dev/null 2>&1; then
        echo "Warning: Compiler $CC not found or not working for $arch"
        echo "Toolchain may need to be downloaded or is incompatible"
    fi
    
    # Export architecture-specific flags separately (not in CFLAGS)
    export CFLAGS_ARCH
    
    # Create output directory
    mkdir -p /build/output/$arch
    
    return 0
}

# Check if binary already exists
check_binary_exists() {
    local arch=$1
    local binary=$2
    local skip_if_exists="${SKIP_IF_EXISTS:-true}"
    
    if [ "$skip_if_exists" = "true" ] && [ -f "/build/output/$arch/$binary" ]; then
        local size=$(ls -lh "/build/output/$arch/$binary" | awk '{print $5}')
        echo "[$binary] Already built for $arch ($size), skipping..."
        return 0
    fi
    return 1
}

# Download and extract source
download_source() {
    local name=$1
    local version=$2
    local url=$3
    
    # Ensure sources directory exists
    mkdir -p /build/sources
    
    # Download if needed
    local filename=$(basename "$url")
    if [ ! -f "/build/sources/$filename" ]; then
        echo "Downloading $name $version..."
        if ! wget -q --show-progress "$url" -O "/build/sources/$filename"; then
            echo "Failed to download $name from $url"
            rm -f "/build/sources/$filename"
            return 1
        fi
    fi
    
    # Return success
    # The caller is responsible for extracting in their build directory
    return 0
}

# Common build flags - optimized for embedded systems
# This function returns flags as separate variables to avoid shell expansion issues
get_build_flags() {
    # Base optimization flags
    BASE_CFLAGS="-Os ${CFLAGS_ARCH:-}"
    BASE_LDFLAGS="-static -Wl,--build-id=sha1"
    
    # Extended flags for full static builds
    FULL_CFLAGS="-static -Os -fomit-frame-pointer ${CFLAGS_ARCH:-}"
    FULL_LDFLAGS="-static -Wl,--gc-sections -Wl,--build-id=sha1"
    
    # Export as individual variables to avoid eval
    export BASE_CFLAGS
    export BASE_LDFLAGS
    export FULL_CFLAGS
    export FULL_LDFLAGS
}

# Build and install binary
install_binary() {
    local binary=$1
    local arch=$2
    local source_path=${3:-$binary}
    
    if [ -f "$source_path" ]; then
        $STRIP "$source_path"
        cp "$source_path" "/build/output/$arch/"
        local size=$(ls -lh "/build/output/$arch/$binary" | awk '{print $5}')
        echo "$binary built successfully for $arch ($size)"
        return 0
    else
        echo "Failed to build $binary for $arch"
        return 1
    fi
}

# Clean build directory
clean_build() {
    make clean 2>/dev/null || true
    make distclean 2>/dev/null || true
    rm -rf build 2>/dev/null || true
}

# Parallel make with proper job count
parallel_make() {
    make -j$(nproc) "$@"
}