#!/bin/bash

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

get_compile_flags() {
    local arch=$1
    local tool=$2
    local arch_family=$(get_arch_family "$arch")
    
    local base_flags="-static -ffunction-sections -fdata-sections"
    
    base_flags="$base_flags -Os -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables"
    
    base_flags="$base_flags -D_FORTIFY_SOURCE=1 -fstack-protector-strong"
    
    # Maximum compatibility flags
    base_flags="$base_flags -D_GNU_SOURCE -fno-strict-aliasing"
    
    
    base_flags="$base_flags -fvisibility=hidden"
    
    base_flags="$base_flags -fno-ident -fmerge-all-constants"
    
    case "$arch" in
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
            base_flags="$base_flags -march=armv7-r -mtune=cortex-r4 -mthumb"
            base_flags="$base_flags -mfpu=vfpv3-d16 -mfloat-abi=hard"
            ;;
        aarch64)
            base_flags="$base_flags -march=armv8-a -mtune=cortex-a53"
            base_flags="$base_flags -fomit-frame-pointer"
            ;;
        armeb)
            base_flags="$base_flags -march=armv5te -mbig-endian -marm"
            ;;
            
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
            
        mips32v2le)
            base_flags="$base_flags -march=mips32r2 -mabi=32"
            base_flags="$base_flags -mno-shared -mno-plt"
            ;;
        mips32v2lesf)
            base_flags="$base_flags -march=mips32 -msoft-float -mabi=32"
            base_flags="$base_flags -mno-shared -mno-plt"
            ;;
        mips32v2be)
            base_flags="$base_flags -march=mips32r2 -mabi=32"
            base_flags="$base_flags -EB -mno-shared -mno-plt"
            ;;
        mips32v2besf)
            base_flags="$base_flags -march=mips32 -msoft-float -mabi=32"
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
            
        ppc32be)
            base_flags="$base_flags -mcpu=powerpc -mtune=powerpc"
            base_flags="$base_flags -mhard-float -msecure-plt"
            ;;
        ppc32besf)
            base_flags="$base_flags -mcpu=powerpc -mtune=powerpc"
            base_flags="$base_flags -msoft-float -msecure-plt"
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
        powerpclesf)
            base_flags="$base_flags -mcpu=powerpc -mtune=powerpc"
            base_flags="$base_flags -mlittle-endian -msoft-float"
            ;;
            
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
    
    if [ -n "${CFLAGS_ARCH:-}" ]; then
        base_flags="$base_flags $CFLAGS_ARCH"
    fi
    
    # Disable PIE/PIC for all architectures for maximum compatibility
    base_flags="$base_flags -fno-pic -fno-PIC -fno-pie -fno-PIE"
    
    case "$tool" in
        busybox)
            base_flags="$base_flags -fno-strict-aliasing"
            ;;
        gdb|gdbserver)
            base_flags="$base_flags -fno-omit-frame-pointer"
            ;;
        strace)
            base_flags="$base_flags -fno-inline-functions"
            ;;
    esac
    
    base_flags="$base_flags -frandom-seed=${tool}-${arch}"
    
    if [ "${DEBUG:-}" = "1" ]; then
        base_flags="$base_flags -g1"
    fi
    
    echo "$base_flags"
}

get_link_flags() {
    local arch=$1
    local base_flags="-static -Wl,--gc-sections"
    
    # Maximum compatibility: support both old and new hash styles
    base_flags="$base_flags -Wl,--hash-style=both"
    
    # Always disable PIE for all architectures
    base_flags="$base_flags -no-pie -Wl,--build-id=sha1"
    
    echo "$base_flags"
}

get_cxx_flags() {
    local arch=$1
    local tool=$2
    
    local base_flags=$(get_compile_flags "$arch" "$tool")
    
    base_flags="$base_flags -fvisibility-inlines-hidden"
    
    base_flags="$base_flags -fno-rtti"
    base_flags="$base_flags -fno-exceptions"
    
    echo "$base_flags"
}

export -f get_compile_flags
export -f get_cxx_flags
export -f get_link_flags
export -f get_arch_family