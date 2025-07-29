#!/bin/bash
# Optimized build flags for embedded systems

# Get architecture family
get_arch_family() {
    local arch=$1
    case "$arch" in
        arm*|aarch64*) echo "arm" ;;
        x86_64|i*86*) echo "x86" ;;
        mips*) echo "mips" ;;
        ppc*|power*) echo "ppc" ;;
        sh*) echo "sh" ;;
        s390*) echo "s390" ;;
        microblaze*) echo "microblaze" ;;
        or1k) echo "or1k" ;;
        m68k) echo "m68k" ;;
        riscv*) echo "riscv" ;;
        *) echo "generic" ;;
    esac
}

# Get optimized compiler flags for architecture
get_compile_flags() {
    local arch=$1
    local tool=$2
    local arch_family=$(get_arch_family "$arch")
    
    # Base flags for all architectures
    local base_flags="-static -ffunction-sections -fdata-sections"
    
    # Size optimization flags (more aggressive)
    base_flags="$base_flags -Os -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables"
    
    # Security hardening (balanced for embedded)
    base_flags="$base_flags -D_FORTIFY_SOURCE=1 -fstack-protector-strong"
    
    
    # Strip unnecessary symbols
    base_flags="$base_flags -fvisibility=hidden"
    
    # Reduce binary size
    base_flags="$base_flags -fno-ident -fmerge-all-constants"
    
    # Architecture-specific optimizations
    case "$arch" in
        # ARM architectures
        arm32v5le)
            base_flags="$base_flags -march=armv5te -mtune=arm926ej-s -marm"
            base_flags="$base_flags -mno-unaligned-access"
            ;;
        arm32v5lehf)
            base_flags="$base_flags -march=armv5te+fp -mtune=arm926ej-s -mfpu=vfp -mfloat-abi=hard -marm"
            ;;
        arm32v7le|arm32v7lehf)
            base_flags="$base_flags -march=armv7-a -mtune=cortex-a8 -mfpu=neon-vfpv3 -mfloat-abi=hard"
            base_flags="$base_flags -mthumb -mthumb-interwork"
            ;;
        armv6)
            base_flags="$base_flags -march=armv6k -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard"
            base_flags="$base_flags -marm"
            ;;
        armv7m)
            base_flags="$base_flags -march=armv7-m -mtune=cortex-m3 -mthumb -mfloat-abi=soft"
            base_flags="$base_flags -mno-unaligned-access"
            ;;
        armv7r)
            # ARMv7-R with minimal FPU settings for compatibility
            base_flags="$base_flags -march=armv7-r -mtune=cortex-r4 -mthumb"
            # Use vfpv3-d16 which is the minimal FPU for ARMv7-R cores
            # Changed to hard float to match toolchain ABI
            base_flags="$base_flags -mfpu=vfpv3-d16 -mfloat-abi=hard"
            ;;
        aarch64)
            base_flags="$base_flags -march=armv8-a -mtune=cortex-a53"
            base_flags="$base_flags -fomit-frame-pointer"
            ;;
        armeb)
            base_flags="$base_flags -march=armv5te -mbig-endian -marm"
            ;;
            
        # x86 architectures
        i486)
            base_flags="$base_flags -march=i486 -mtune=i486"
            base_flags="$base_flags -mno-sse -mno-sse2 -m32"
            ;;
        ix86le)
            base_flags="$base_flags -march=i686 -mtune=generic"
            base_flags="$base_flags -mno-sse2 -m32"
            ;;
        x86_64)
            base_flags="$base_flags -march=x86-64 -mtune=generic"
            base_flags="$base_flags -m64"
            ;;
            
        # MIPS architectures
        mips32v2le)
            base_flags="$base_flags -march=mips32r2 -mtune=24kc -mabi=32"
            base_flags="$base_flags -mno-shared -mno-plt"
            ;;
        mips32v2be)
            base_flags="$base_flags -march=mips32r2 -mtune=24kc -mabi=32"
            base_flags="$base_flags -EB -mno-shared -mno-plt"
            ;;
        mips64le)
            base_flags="$base_flags -march=mips64r2 -mtune=octeon -mabi=64"
            base_flags="$base_flags -mno-shared -mno-plt"
            ;;
        mipsn32|mipsn32el|mips64n32|mips64n32el)
            base_flags="$base_flags -march=mips64r2"
            base_flags="$base_flags -mno-shared -mno-plt"
            ;;
            
        # PowerPC architectures
        ppc32be)
            base_flags="$base_flags -mcpu=powerpc -mtune=powerpc"
            base_flags="$base_flags -mhard-float -msecure-plt"
            ;;
        ppc64le)
            base_flags="$base_flags -mcpu=power8 -mtune=power8"
            base_flags="$base_flags -mhard-float"
            ;;
        powerpc64)
            base_flags="$base_flags -mcpu=power7 -mtune=power7"
            base_flags="$base_flags -mhard-float"
            ;;
        powerpcle)
            base_flags="$base_flags -mcpu=powerpc -mtune=powerpc"
            base_flags="$base_flags -mlittle-endian -mhard-float"
            ;;
            
        # Other architectures
        m68k)
            base_flags="$base_flags -mcpu=68020 -mtune=68020"
            ;;
        sh2)
            base_flags="$base_flags -m2 -ml"
            ;;
        sh2eb)
            base_flags="$base_flags -m2 -mb"
            ;;
        sh4)
            base_flags="$base_flags -m4 -ml"
            ;;
        sh4eb)
            base_flags="$base_flags -m4 -mb"
            ;;
        s390x)
            base_flags="$base_flags -march=z196 -mtune=z196"
            base_flags="$base_flags -m64 -mzarch"
            ;;
        microblaze|microblazeel)
            base_flags="$base_flags -mcpu=v8.30.a"
            ;;
        or1k)
            base_flags="$base_flags -mhard-mul -mhard-div"
            ;;
        riscv32)
            base_flags="$base_flags -march=rv32gc -mabi=ilp32d"
            base_flags="$base_flags -mcmodel=medlow"
            ;;
        riscv64)
            base_flags="$base_flags -march=rv64gc -mabi=lp64d"
            base_flags="$base_flags -mcmodel=medlow"
            ;;
        aarch64_be)
            base_flags="$base_flags -march=armv8-a -mtune=cortex-a53"
            base_flags="$base_flags -mbig-endian -fomit-frame-pointer"
            ;;
        mips64)
            base_flags="$base_flags -march=mips64r2 -mtune=octeon -mabi=64"
            base_flags="$base_flags -EB -mno-shared -mno-plt"
            ;;
    esac
    
    # Add architecture-specific flags from environment
    if [ -n "${CFLAGS_ARCH:-}" ]; then
        base_flags="$base_flags $CFLAGS_ARCH"
    fi
    
    # PIE handling (architecture-specific)
    case "$arch" in
        # Architectures that don't support PIE well
        sh2|sh2eb|sh4|sh4eb|microblaze|microblazeel|or1k|mipsn32|mipsn32el)
            base_flags="$base_flags -fno-pie -no-pie"
            ;;
        # ARM hard-float architectures with PIE issues
        arm32v5lehf|arm32v7le|arm32v7lehf|armv6|armv7r)
            # Skip PIE flags
            ;;
        *)
            # Most architectures can use PIE
            base_flags="$base_flags -fPIE"
            ;;
    esac
    
    # Tool-specific optimizations
    case "$tool" in
        busybox)
            # BusyBox benefits from loop optimizations
            base_flags="$base_flags -fno-strict-aliasing"
            ;;
        gdb|gdbserver)
            # Debuggers need accurate debugging info
            base_flags="$base_flags -fno-omit-frame-pointer"
            ;;
        strace)
            # Strace needs to preserve some debugging capability
            base_flags="$base_flags -fno-inline-functions"
            ;;
    esac
    
    # Add reproducible build seed
    base_flags="$base_flags -frandom-seed=${tool}-${arch}"
    
    # Debugging support (minimal for embedded)
    if [ "${DEBUG:-}" = "1" ]; then
        base_flags="$base_flags -g1"
    fi
    
    echo "$base_flags"
}

# Get appropriate linker flags for an architecture
get_link_flags() {
    local arch=$1
    local base_flags="-static -Wl,--gc-sections"
    
    # Apply -no-pie and --build-id=sha1 flags universally for all architectures
    # Skip -no-pie for ARM hard-float architectures due to compiler incompatibility
    case "$arch" in
        arm32v5lehf|arm32v7le|arm32v7lehf|armv6|armv7r)
            # ARM hard-float architectures can't handle -no-pie with their specific flags
            base_flags="$base_flags -Wl,--build-id=sha1"
            ;;
        *)
            base_flags="$base_flags -no-pie -Wl,--build-id=sha1"
            ;;
    esac
    
    echo "$base_flags"
}

# Get C++ specific flags (in addition to C flags)
get_cxx_flags() {
    local arch=$1
    local tool=$2
    
    # Get base C flags
    local base_flags=$(get_compile_flags "$arch" "$tool")
    
    # Add C++-specific optimizations
    base_flags="$base_flags -fvisibility-inlines-hidden"
    
    # C++-specific optimizations for smaller binaries
    base_flags="$base_flags -fno-rtti"  # Disable RTTI
    base_flags="$base_flags -fno-exceptions"  # Disable exceptions
    
    echo "$base_flags"
}

# Export functions
export -f get_compile_flags
export -f get_cxx_flags
export -f get_link_flags
export -f get_arch_family