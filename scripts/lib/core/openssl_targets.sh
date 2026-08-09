#!/bin/bash

# Central arch -> OpenSSL Configure mapping.
#
# Single source of truth shared by both consumers:
#   - scripts/lib/dependency_builder.sh   (openssl built as a library dep)
#   - scripts/static/tools/build-openssl.sh (the standalone openssl CLI)
# Keeping this in one place avoids the drift that previously left the two
# copies disagreeing (e.g. s390x) and both missing BSD targets for several
# freebsd arches.

[[ -n "${_OPENSSL_TARGETS_LOADED:-}" ]] && return 0
_OPENSSL_TARGETS_LOADED=1

# Map an arch name to OpenSSL's Configure target.
#
# BSD arches must use a BSD-* target, never a linux-* one: the linux profiles
# compile the AF_ALG engine (crypto/engine/e_afalg.c -> <linux/version.h>,
# <linux/if_alg.h>), Linux-kernel headers that don't exist in a BSD sysroot,
# so a linux target fails to build under `zig cc -target *-freebsd`.
get_openssl_target() {
    local arch=$1

    # Zig cross-platform targets (Darwin / BSD / Windows).
    case $arch in
        x86_64_macos)        echo "darwin64-x86_64-cc"; return ;;
        aarch64_macos)       echo "darwin64-arm64-cc";  return ;;
        x86_64_freebsd|x86_64_openbsd|x86_64_netbsd)     echo "BSD-x86_64";     return ;;
        x86_freebsd|x86_openbsd|x86_netbsd)              echo "BSD-x86";        return ;;
        aarch64_freebsd|aarch64_openbsd|aarch64_netbsd)  echo "BSD-generic64";  return ;;
        arm_freebsd|arm_openbsd|arm_netbsd)              echo "BSD-generic32";  return ;;
        riscv64_freebsd|riscv64_openbsd)                 echo "BSD-generic64";  return ;;
        # No BSD-ppc* target exists in OpenSSL 1.1.1; use the endian-agnostic,
        # asm-free generic64 (valid BSD targets: generic32/64, x86, x86_64,
        # aarch64, riscv64, sparc*, ia64).
        powerpc64_freebsd|powerpc64le_freebsd)           echo "BSD-generic64";  return ;;
        x86_64_windows|aarch64_windows) echo "mingw64"; return ;;
    esac

    # Native Linux GCC arches.
    local t
    case $arch in
        x86_64) t="linux-x86_64" ;;
        ix86le|i486) t="linux-x86" ;;
        armv7m|armv7r) t="linux-generic32" ;;   # Thumb-only, no ARM asm
        arm*)
            if [[ "$arch" == *"v7"* ]]; then t="linux-armv4"; else t="linux-generic32"; fi
            ;;
        aarch64*) t="linux-aarch64" ;;
        mips64n32*) t="linux-mips64" ;;
        mips64*) t="linux64-mips64" ;;
        mips*) t="linux-mips32" ;;
        ppc64*) t="linux-ppc64le" ;;
        ppc32*) t="linux-ppc" ;;
        riscv64) t="linux-generic64" ;;
        riscv32) t="linux-generic32" ;;
        loongarch64) t="linux-generic64" ;;   # 64-bit; no loongarch asm target in 1.1.1w
        sparc64) t="linux-generic64" ;;        # 64-bit; avoid the 32-bit default
        s390x) t="linux64-s390x" ;;
        sh*) t="linux-generic32" ;;
        *) t="linux-generic32" ;;
    esac
    echo "$t"
}

# Disable OpenSSL assembly where the Configure target's asm doesn't fit the arch:
# Thumb-only ARM profiles, and aarch64/thumb Windows (which use the x86_64-asm
# mingw64 target).
get_openssl_asm_opt() {
    case "$1" in
        armv7m|armv7r) echo "no-asm" ;;
        aarch64_windows|thumb_windows) echo "no-asm" ;;
        # OpenSSL's 32-bit x86 BSD perlasm (aesni-x86.s, bf-586.s, ...) emits
        # .align directives Zig's LLVM assembler rejects ("alignment must be a
        # power of 2"); build these without asm.
        x86_freebsd|x86_openbsd|x86_netbsd) echo "no-asm" ;;
        *) echo "" ;;
    esac
}

# riscv32 lacks the legacy __NR_io_getevents syscall (time64-only), so the
# AF_ALG engine won't compile there even on Linux.
get_openssl_afalg_opt() {
    case "$1" in
        riscv32) echo "no-afalgeng" ;;
        *) echo "" ;;
    esac
}

# The devcrypto engine needs Linux's /dev/crypto headers (crypto/cryptodev.h),
# absent on Darwin/BSD Zig sysroots.
get_openssl_devcrypto_opt() {
    case "$1" in
        *_macos|*_freebsd|*_openbsd|*_netbsd|*_dragonfly) echo "no-devcryptoeng" ;;
        *) echo "" ;;
    esac
}

export -f get_openssl_target
export -f get_openssl_asm_opt
export -f get_openssl_afalg_opt
export -f get_openssl_devcrypto_opt
