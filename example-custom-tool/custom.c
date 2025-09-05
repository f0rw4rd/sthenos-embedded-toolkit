#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void print_ascii_art() {
    // https://asciiart.cc/view/11270
    printf("            )           \\     /          (\n");
    printf("          /|\\          ) \\___/ (         /|\\\n");
    printf("        /  |  \\       ( /\\   /\\ )      /  |  \\\n");
    printf("      /    |    \\      \\ ` | ' /     /    |    \\\n");
    printf("+----/-----|-----O------\\  |  /----O------|------\\--------+\n");
    printf("|                 '^`      V     '^`                      |\n");
    printf("|               STHENOS EMBEDDED TOOLKIT                  |\n");
    printf("|                  Custom Tool Builder                    |\n");
    printf("|            Static Binaries for All Architectures        |\n");
    printf("+---------------------------------------------------------+\n");
    printf("  l     /\\     /         \\\\             \\     /\\     l\n");
    printf("  l  /     \\ /            ))              \\ /     \\  l\n");
    printf("   I/       V            //                V       \\I\n");
    printf("                         V\n");
}

void print_build_info() {
    char hostname[256];
    char buffer[64];
    
    printf("┌─────────────────────────────────────────────┐\n");
    printf("│            Build Information                │\n");
    printf("├─────────────────────────────────────────────┤\n");
    
    if (gethostname(hostname, sizeof(hostname)) == 0) {
        printf("│ Hostname: %-33s │\n", hostname);
    }
    
    #if defined(__x86_64__) || defined(__amd64__)
        printf("│ Architecture: %-29s │\n", "x86_64");
    #elif defined(__i386__) || defined(__i686__)
        printf("│ Architecture: %-29s │\n", "x86 (32-bit)");
    #elif defined(__aarch64__)
        printf("│ Architecture: %-29s │\n", "ARM64 (aarch64)");
    #elif defined(__ARM_ARCH_7__) || defined(__ARM_ARCH_7A__)
        printf("│ Architecture: %-29s │\n", "ARMv7");
    #elif defined(__ARM_ARCH_6__) || defined(__ARM_ARCH_6K__)
        printf("│ Architecture: %-29s │\n", "ARMv6");
    #elif defined(__ARM_ARCH_5TE__)
        printf("│ Architecture: %-29s │\n", "ARMv5TE");
    #elif defined(__arm__)
        printf("│ Architecture: %-29s │\n", "ARM (32-bit)");
    #elif defined(__mips64)
        printf("│ Architecture: %-29s │\n", "MIPS64");
    #elif defined(__mips__)
        printf("│ Architecture: %-29s │\n", "MIPS32");
    #elif defined(__powerpc64__) || defined(__PPC64__)
        printf("│ Architecture: %-29s │\n", "PowerPC64");
    #elif defined(__powerpc__) || defined(__PPC__)
        printf("│ Architecture: %-29s │\n", "PowerPC32");
    #elif defined(__sh__)
        printf("│ Architecture: %-29s │\n", "SuperH");
    #elif defined(__m68k__)
        printf("│ Architecture: %-29s │\n", "m68k");
    #elif defined(__s390x__)
        printf("│ Architecture: %-29s │\n", "s390x");
    #elif defined(__s390__)
        printf("│ Architecture: %-29s │\n", "s390");
    #elif defined(__riscv) && (__riscv_xlen == 64)
        printf("│ Architecture: %-29s │\n", "RISC-V 64");
    #elif defined(__riscv) && (__riscv_xlen == 32)
        printf("│ Architecture: %-29s │\n", "RISC-V 32");
    #elif defined(__or1k__)
        printf("│ Architecture: %-29s │\n", "OpenRISC");
    #elif defined(__microblaze__)
        printf("│ Architecture: %-29s │\n", "MicroBlaze");
    #else
        printf("│ Architecture: %-29s │\n", "Unknown");
    #endif
    
    #if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
        printf("│ Endianness: %-31s │\n", "Big-endian");
    #elif defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        printf("│ Endianness: %-31s │\n", "Little-endian");
    #elif defined(__BIG_ENDIAN__) || defined(__ARMEB__) || defined(__MIPSEB__)
        printf("│ Endianness: %-31s │\n", "Big-endian");
    #else
        printf("│ Endianness: %-31s │\n", "Little-endian");
    #endif
    
    #ifdef __GNUC__
        #ifdef __GNUC_PATCHLEVEL__
            snprintf(buffer, sizeof(buffer), "GCC %d.%d.%d", 
                     __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);
        #else
            snprintf(buffer, sizeof(buffer), "GCC %d.%d", 
                     __GNUC__, __GNUC_MINOR__);
        #endif
        printf("│ Compiler: %-33s │\n", buffer);
    #elif defined(__clang__)
        snprintf(buffer, sizeof(buffer), "Clang %d.%d.%d", 
                 __clang_major__, __clang_minor__, __clang_patchlevel__);
        printf("│ Compiler: %-33s │\n", buffer);
    #else
        printf("│ Compiler: %-33s │\n", "Unknown");
    #endif
    
    #ifdef __GLIBC__
        printf("│ C Library: %-32s │\n", "GNU libc (glibc)");
        #ifdef __GLIBC_MINOR__
            snprintf(buffer, sizeof(buffer), "%d.%d", __GLIBC__, __GLIBC_MINOR__);
            printf("│ Version: %-34s │\n", buffer);
        #endif
    #elif defined(__musl__)
        printf("│ C Library: %-32s │\n", "musl libc");
    #else
        // Sthenos uses musl by default for static builds
        printf("│ C Library: %-32s │\n", "musl libc (static)");
    #endif
    
    #ifdef __STDC_VERSION__
        snprintf(buffer, sizeof(buffer), "C%ld", __STDC_VERSION__);
        printf("│ C Standard: %-31s │\n", buffer);
    #endif
    
    #ifdef _POSIX_VERSION
        snprintf(buffer, sizeof(buffer), "%ld", _POSIX_VERSION);
        printf("│ POSIX Version: %-28s │\n", buffer);
    #endif
    
    snprintf(buffer, sizeof(buffer), "%zu bytes", sizeof(void*));
    printf("│ Pointer Size: %-29s │\n", buffer);
    printf("│ Build Type: %-31s │\n", "Static Binary");
    
    #ifdef NDEBUG
        printf("│ Debug: %-36s │\n", "Disabled (Release Build)");
    #else
        printf("│ Debug: %-36s │\n", "Enabled");
    #endif
    
    #ifdef _FORTIFY_SOURCE
        snprintf(buffer, sizeof(buffer), "Level %d", _FORTIFY_SOURCE);
        printf("│ Fortify Source: %-27s │\n", buffer);
    #endif
    
    #ifdef __SSP__
        printf("│ Stack Protection: %-25s │\n", "Enabled");
    #elif defined(__SSP_STRONG__)
        printf("│ Stack Protection: %-25s │\n", "Strong");
    #elif defined(__SSP_ALL__)
        printf("│ Stack Protection: %-25s │\n", "All");
    #endif
    
    #ifdef __PIC__
        printf("│ Position Independent Code: %-16s │\n", "Yes");
    #elif defined(__PIE__)
        printf("│ Position Independent Exec: %-16s │\n", "Yes");
    #endif
    
    #ifdef __OPTIMIZE__
        printf("│ Optimization: %-29s │\n", "Enabled");
    #endif
    
    #ifdef __OPTIMIZE_SIZE__
        printf("│ Size Optimization: %-24s │\n", "Enabled");
    #endif
    
    #ifdef __FAST_MATH__
        printf("│ Fast Math: %-32s │\n", "Enabled");
    #endif
    
    printf("└─────────────────────────────────────────────┘\n");
}

void print_usage(const char *prog_name) {
    printf("\nUsage: %s [options]\n", prog_name);
    printf("\nOptions:\n");
    printf("  -h, --help     Show this help message\n");
    printf("  -a, --ascii    Show ASCII art\n");
    printf("  -i, --info     Show build information\n");
    printf("\nThis is a demonstration tool showing how to integrate\n");
    printf("custom C programs into the Sthenos Embedded Toolkit.\n");
    printf("\n");
}

int main(int argc, char *argv[]) {    
    int show_ascii = 0;
    int show_info = 0;
    
    if (argc > 1) {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
                print_usage(argv[0]);
                return 0;            
            } else if (strcmp(argv[i], "-a") == 0 || strcmp(argv[i], "--ascii") == 0) {
                show_ascii = 1;
            } else if (strcmp(argv[i], "-i") == 0 || strcmp(argv[i], "--info") == 0) {
                show_info = 1;
            } else {
                fprintf(stderr, "Unknown option: %s\n", argv[i]);
                print_usage(argv[0]);
                return 1;
            }
        }
    } else {        
        show_ascii = show_info = 1;
    }
    
    if (show_ascii) {
        print_ascii_art();
        printf("\n");
    }
    
    if (show_info) {
        print_build_info();
        printf("\n");
    }
    
    if (show_ascii || show_info) {
        printf("Hello from the Sthenos Custom Tool!\n");
        printf("This binary was statically compiled for embedded systems.\n");
        printf("\n");
    }
    
    return 0;
}