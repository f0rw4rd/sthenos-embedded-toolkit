#!/bin/bash


ARCH_MAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ARCH_MAP_DIR/core/architectures.sh"

is_canonical_arch() {
    local arch="$1"
    for canonical in "${ALL_ARCHITECTURES[@]}"; do
        if [ "$arch" = "$canonical" ]; then
            return 0
        fi
    done
    return 1
}

map_arch_name() {
    local input_arch=$1
    
    if is_canonical_arch "$input_arch"; then
        echo "$input_arch"
        return 0
    fi
    
    case "$input_arch" in
            
        mips32)      echo "mips32be" ;;
        mips32el)    echo "mips32le" ;;
        armv5)       echo "arm32v5le" ;;
        armv6)       echo "armv6" ;;
        ppc32)       echo "ppc32be" ;;
        powerpc)     echo "ppc32be" ;;
        powerpc32)   echo "ppc32be" ;;
        powerpc64)   echo "ppc64be" ;;
        powerpcle)   echo "ppc32le" ;;
        powerpclesf) echo "ppc32lesf" ;;
        openrisc)    echo "or1k" ;;
        aarch64be)   echo "aarch64_be" ;;
        
        mips32-sf)   echo "mips32besf" ;;
        mips32el-sf) echo "mips32lesf" ;;
        powerpc-sf)  echo "ppc32besf" ;;
        powerpcle-sf) echo "ppc32lesf" ;;
        ppc32-sf)    echo "ppc32besf" ;;
        ppc32le-sf)  echo "ppc32lesf" ;;
        
        microblazebe) echo "microblaze" ;; # musl only has big-endian microblaze
        
        arm)         echo "arm32v7le" ;;  # Default ARM
        mips)        echo "mips32be" ;; # Default MIPS
        ppc)         echo "ppc32be" ;;    # Default PowerPC
        
        *)
            echo "$input_arch"  # Return as-is if unknown
            ;;
    esac
}

