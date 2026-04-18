#ifndef CUSTOM_SHARED_H
#define CUSTOM_SHARED_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static inline void print_ascii_art(const char *title, const char *subtitle) {
    printf("            )           \\     /          (\n");
    printf("          /|\\          ) \\___/ (         /|\\\n");
    printf("        /  |  \\       ( /\\   /\\ )      /  |  \\\n");
    printf("      /    |    \\      \\ x | O /     /    |    \\\n");
    printf("+----/-----|-----O------\\  |  /----O------|------\\---+\n");
    printf("|                 '^`      V     '^`                 |\n");
    printf("|                STHENOS EMBEDDED TOOLKIT            |\n");
    printf("|                  %-33s |\n", title);
    printf("|          %-41s |\n", subtitle);
    printf("+----------------------------------------------------+\n");
    printf("  l     /\\     /         \\\\             \\     /\\     l\n");
    printf("  l  /     \\ /            ))              \\ /     \\  l\n");
    printf("   I/       V            //                V       \\I\n");
    printf("                         V\n");
}

static inline const char* get_architecture() {
    #if defined(__x86_64__) || defined(__amd64__)
        #ifdef __ILP32__ 
            return "x86_64 (x32 ABI)";
        #else
            return "x86_64";
        #endif
    #elif defined(__i386__) || defined(__i486__) || defined(__i586__) || defined(__i686__)
        return "x86 (32-bit)";
    #elif defined(__aarch64__)
        #if defined(__AARCH64EB__) || defined(__ARM_BIG_ENDIAN)
            return "ARM64 BE (aarch64_be)";
        #else
            return "ARM64 (aarch64)";
        #endif
    #elif defined(__ARM_ARCH_7A__) || defined(__ARM_ARCH_7__) || defined(__ARM_ARCH_7M__) || defined(__ARM_ARCH_7R__)
        #if defined(__ARM_ARCH_7M__)
            return "ARMv7-M (Cortex-M)";
        #elif defined(__ARM_ARCH_7R__)
            return "ARMv7-R (Cortex-R)";
        #elif defined(__ARM_PCS_VFP) || defined(__ARM_NEON__)
            #if defined(__ARM_NEON__)
                return "ARMv7 (NEON)";
            #else
                return "ARMv7 (hard-float)";
            #endif
        #else
            return "ARMv7";
        #endif
    #elif defined(__ARM_ARCH_6__) || defined(__ARM_ARCH_6K__) || defined(__ARM_ARCH_6T2__)
        #if defined(__ARM_PCS_VFP)
            return "ARMv6 (hard-float)";
        #else
            return "ARMv6 (soft-float)";
        #endif
    #elif defined(__ARM_ARCH_5TE__) || defined(__ARM_ARCH_5T__) || defined(__ARM_ARCH_5__)
        #if defined(__ARM_PCS_VFP)
            return "ARMv5 (hard-float)";
        #else
            return "ARMv5";
        #endif
    #elif defined(__arm__) || defined(__ARM__)
        #if defined(__ARMEB__) || defined(__ARM_BIG_ENDIAN)
            return "ARM (big-endian)";
        #else
            return "ARM (32-bit)";
        #endif
    #elif defined(__mips64)
        #if defined(__mips_n32)
            #if defined(__MIPSEL__) || defined(_MIPSEL)
                return "MIPS64 N32 LE";
            #else
                return "MIPS64 N32 BE";
            #endif
        #else
            #if defined(__MIPSEL__) || defined(_MIPSEL)
                return "MIPS64 LE";
            #else
                return "MIPS64 BE";
            #endif
        #endif
    #elif defined(__mips__)
        #if defined(__mips_soft_float)
            #if defined(__MIPSEL__) || defined(_MIPSEL)
                return "MIPS32 LE (soft-float)";
            #else
                return "MIPS32 BE (soft-float)";
            #endif
        #else
            #if defined(__MIPSEL__) || defined(_MIPSEL)
                return "MIPS32 LE";
            #else
                return "MIPS32 BE";
            #endif
        #endif
    #elif defined(__powerpc64__) || defined(__PPC64__)
        #if defined(__LITTLE_ENDIAN__) || defined(__ARMEL__)
            return "PowerPC64 LE";
        #else
            return "PowerPC64 BE";
        #endif
    #elif defined(__powerpc__) || defined(__PPC__)
        #if defined(__NO_FPRS__) || defined(__SPE__)
            #if defined(__LITTLE_ENDIAN__) || defined(__ARMEL__)
                return "PowerPC32 LE (soft-float)";
            #else
                return "PowerPC32 BE (soft-float)";
            #endif
        #else
            #if defined(__LITTLE_ENDIAN__) || defined(__ARMEL__)
                return "PowerPC32 LE";
            #else
                return "PowerPC32 BE";
            #endif
        #endif
    #elif defined(__riscv)
        #if __riscv_xlen == 64
            return "RISC-V 64";
        #elif __riscv_xlen == 32
            return "RISC-V 32";
        #else
            return "RISC-V";
        #endif
    #elif defined(__s390x__)
        return "s390x (z/Architecture)";
    #elif defined(__or1k__) || defined(__or32__)
        return "OpenRISC (or1k)";
    #elif defined(__microblaze__)
        #if defined(__MICROBLAZEEL__)
            return "MicroBlaze LE";
        #else
            return "MicroBlaze BE";
        #endif
    #elif defined(__sh4__)
        return "SuperH SH4";
    #elif defined(__sh2__) || defined(__SH2__)
        return "SuperH SH2";
    #elif defined(__m68k__)
        #if defined(__mcoldfire__)
            return "m68k ColdFire";
        #else
            return "m68k";
        #endif
    #else
        return "Unknown";
    #endif
}

static inline const char* get_endianness() {
    #if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
        return "Big-endian";
    #elif defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        return "Little-endian";
    #elif defined(__BIG_ENDIAN__) || defined(__ARMEB__) || defined(__MIPSEB__)
        return "Big-endian";
    #else
        return "Little-endian";
    #endif
}

static inline const char* get_c_library() {
    #ifdef __GLIBC__
        return "GNU libc (glibc)";
    #elif defined(__musl__)
        return "musl libc";
    #else
        return "musl libc (static)";
    #endif
}

static inline void print_build_info_common(const char *info_title, const char *build_type) {
    char hostname[256];
    char buffer[64];
    
    printf("┌─────────────────────────────────────────────┐\n");
    printf("│         %-35s │\n", info_title);
    printf("├─────────────────────────────────────────────┤\n");
    
    if (gethostname(hostname, sizeof(hostname)) == 0) {
        printf("│ Hostname: %-33s │\n", hostname);
    }
    
    printf("│ Architecture: %-29s │\n", get_architecture());
    printf("│ Endianness: %-31s │\n", get_endianness());
    
    #ifdef __GNUC__
        #ifdef __GNUC_PATCHLEVEL__
            snprintf(buffer, sizeof(buffer), "GCC %d.%d.%d", 
                     __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);
        #else
            snprintf(buffer, sizeof(buffer), "GCC %d.%d", 
                     __GNUC__, __GNUC_MINOR__);
        #endif
        printf("│ Compiler: %-33s │\n", buffer);
    #endif
    
    printf("│ C Library: %-32s │\n", get_c_library());
    
    #ifdef __GLIBC__
        #ifdef __GLIBC_MINOR__
            snprintf(buffer, sizeof(buffer), "%d.%d", __GLIBC__, __GLIBC_MINOR__);
            printf("│ Version: %-34s │\n", buffer);
        #endif
    #endif
    
    snprintf(buffer, sizeof(buffer), "%zu bytes", sizeof(void*));
    printf("│ Pointer Size: %-29s │\n", buffer);
    printf("│ Build Type: %-31s │\n", build_type);
    
    printf("│ Process PID: %-30d │\n", getpid());
    
    printf("└─────────────────────────────────────────────┘\n");
}

#endif