#ifndef CUSTOM_SHARED_H
#define CUSTOM_SHARED_H

// Standard headers
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// OS-specific headers and compatibility
#ifdef _WIN32
    #include <winsock2.h>
    #define NO_UNISTD_H
#elif defined(__wasi__)
    // WASI has limited POSIX support
    #define NO_HOSTNAME
    #define NO_PID
#elif defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__DragonFly__)
    #include <unistd.h>
    #include <sys/types.h>
#else
    #include <unistd.h>
#endif

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

static inline const char* get_operating_system() {
    #if defined(_WIN32)
        return "Windows";
    #elif defined(__APPLE__)
        return "macOS/Darwin";
    #elif defined(__FreeBSD__)
        return "FreeBSD";
    #elif defined(__OpenBSD__)
        return "OpenBSD";
    #elif defined(__NetBSD__)
        return "NetBSD";
    #elif defined(__DragonFly__)
        return "DragonFly BSD";
    #elif defined(__wasi__)
        return "WASI";
    #elif defined(__linux__)
        return "Linux";
    #else
        return "unknown";
    #endif
}

static inline const char* get_c_library() {
    // musl defines no identifying macro, so it is inferred: a Linux target that
    // is neither glibc nor uClibc is musl in this toolkit. Non-Linux Zig targets
    // report their platform libc.
    #ifdef __GLIBC__
        return "GNU libc (glibc)";
    #elif defined(__UCLIBC__)
        return "uClibc";
    #elif defined(__wasi__)
        return "wasi-libc";
    #elif defined(_WIN32)
        return "mingw-w64 (msvcrt)";
    #elif defined(__APPLE__)
        return "Darwin libSystem";
    #elif defined(__FreeBSD__)
        return "FreeBSD libc";
    #elif defined(__OpenBSD__)
        return "OpenBSD libc";
    #elif defined(__NetBSD__)
        return "NetBSD libc";
    #elif defined(__linux__)
        return "musl (static)";
    #else
        return "unknown";
    #endif
}

// Prefer the authoritative target facts injected by the build system
// (STHENOS_ARCH/OS/LIBC). They are always #defined by the Makefile but expand
// empty on a standalone `make`, in which case fall back to compile-time
// preprocessor detection.
static inline const char* target_arch_str(void) {
    #ifdef STHENOS_ARCH
        if (STHENOS_ARCH[0]) return STHENOS_ARCH;
    #endif
    return get_architecture();
}

static inline const char* target_os_str(void) {
    #ifdef STHENOS_OS
        if (STHENOS_OS[0]) return STHENOS_OS;
    #endif
    return get_operating_system();
}

static inline const char* target_libc_str(void) {
    #ifdef STHENOS_LIBC
        if (STHENOS_LIBC[0]) return STHENOS_LIBC;
    #endif
    return get_c_library();
}

// Zig cross-compiles with clang, which advertises itself as GCC 4.2.1 via the
// __GNUC__ macros; check __clang__ first so the report is accurate.
static inline void get_compiler_str(char *buf, size_t n) {
    #if defined(__clang__)
        snprintf(buf, n, "Clang %d.%d.%d", __clang_major__, __clang_minor__, __clang_patchlevel__);
    #elif defined(__GNUC__)
        #ifdef __GNUC_PATCHLEVEL__
            snprintf(buf, n, "GCC %d.%d.%d", __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);
        #else
            snprintf(buf, n, "GCC %d.%d", __GNUC__, __GNUC_MINOR__);
        #endif
    #else
        snprintf(buf, n, "unknown");
    #endif
}

// Fixed inner width of the info box, in display columns. All rows pad to this
// so the right border always lines up regardless of value length.
#define CUSTOM_BOX_W 54

static inline void box_rule(const char *left, const char *right) {
    int i;
    fputs(left, stdout);
    for (i = 0; i < CUSTOM_BOX_W; i++) fputs("─", stdout);
    fputs(right, stdout);
    fputc('\n', stdout);
}

static inline void box_row(const char *key, const char *val) {
    char buf[256];
    // Content is ASCII, so byte count == column count and %-*s aligns cleanly.
    snprintf(buf, sizeof(buf), " %s: %s", key, val);
    printf("│%-*s│\n", CUSTOM_BOX_W, buf);
}

static inline void box_center(const char *text) {
    char buf[256];
    int len = (int)strlen(text);
    int pad = (CUSTOM_BOX_W - len) / 2;
    if (pad < 0) pad = 0;
    snprintf(buf, sizeof(buf), "%*s%s", pad, "", text);
    printf("│%-*s│\n", CUSTOM_BOX_W, buf);
}

static inline void print_build_info_common(const char *info_title, const char *build_type) {
    char buf[256];

    box_rule("┌", "┐");
    box_center(info_title);
    box_rule("├", "┤");

    #if !defined(_WIN32) && !defined(NO_HOSTNAME)
    {
        char hostname[256];
        if (gethostname(hostname, sizeof(hostname)) == 0)
            box_row("Host", hostname);
    }
    #endif

    box_row("Target", target_arch_str());
    box_row("CPU", get_architecture());
    box_row("OS", target_os_str());
    box_row("Endianness", get_endianness());
    box_row("C library", target_libc_str());

    #if defined(__GLIBC__) && defined(__GLIBC_MINOR__)
        snprintf(buf, sizeof(buf), "%d.%d", __GLIBC__, __GLIBC_MINOR__);
        box_row("libc version", buf);
    #endif

    get_compiler_str(buf, sizeof(buf));
    box_row("Compiler", buf);

    snprintf(buf, sizeof(buf), "%zu bytes", sizeof(void*));
    box_row("Pointer size", buf);
    box_row("Build type", build_type);

    #if !defined(_WIN32) && !defined(NO_PID)
        snprintf(buf, sizeof(buf), "%d", (int)getpid());
        box_row("PID", buf);
    #endif

    box_rule("└", "┘");
}

#endif