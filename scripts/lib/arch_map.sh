#!/bin/bash

#  architecture mapping
# Maps various architecture names to canonical musl names

map_arch_name() {
    local input_arch=$1
    
    case "$input_arch" in
        # Direct mappings (already canonical)
        arm32v5le|arm32v5lehf|arm32v7le|arm32v7lehf|armeb|armv6|armv7m|armv7r|\
        mips32le|mips32lesf|mips32be|mips32besf|mipsn32|mipsn32el|mips64|mips64le|mips64n32|mips64n32el|\
        ppc32be|ppc32besf|ppc32le|ppc32lesf|ppc64be|ppc64le|\
        i486|ix86le|x86_64|aarch64|aarch64_be|\
        sh2|sh2eb|sh4|sh4eb|\
        microblaze|microblazeel|or1k|m68k|s390x|\
        riscv32|riscv64)
            echo "$input_arch"
            ;;
            
        # Glibc/Bootlin names to musl names
        mips32)      echo "mips32be" ;;
        mips32el)    echo "mips32le" ;;
        armv5)       echo "arm32v5le" ;;
        ppc32)       echo "ppc32be" ;;
        powerpc)     echo "ppc32be" ;;     # Another alias for ppc32
        openrisc)    echo "or1k" ;;
        aarch64be)   echo "aarch64_be" ;;
        
        # Glibc-only architectures (not available in musl)
        sparc64|nios2|arcle|xtensa)
            echo "[glibc-only] $input_arch not available in musl"
            return 1
            ;;
        microblazebe) echo "microblaze" ;; # musl only has big-endian microblaze
        
        # Common aliases
        arm)         echo "arm32v7le" ;;  # Default ARM
        mips)        echo "mips32be" ;; # Default MIPS
        ppc)         echo "ppc32be" ;;    # Default PowerPC
        powerpc32)   echo "ppc32be" ;;    # Yet another PowerPC alias
        
        *)
            echo "$input_arch"  # Return as-is if unknown
            ;;
    esac
}

