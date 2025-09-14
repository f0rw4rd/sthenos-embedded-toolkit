#define _GNU_SOURCE
#include "custom-shared.h"

__attribute__((constructor))
void init_library() {
    printf("\n");
    print_ascii_art("Custom Shared Library", "LD_PRELOAD Injection Demo");
    printf("\n");
    
    char proc_path[256];
    char exe_path[256] = {0};
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/exe", getpid());
    
    printf("┌─────────────────────────────────────────────┐\n");
    printf("│       Shared Library Information            │\n");
    printf("├─────────────────────────────────────────────┤\n");
    
    char hostname[256];
    if (gethostname(hostname, sizeof(hostname)) == 0) {
        printf("│ Hostname: %-33s │\n", hostname);
    }
    
    printf("│ Architecture: %-29s │\n", get_architecture());
    printf("│ Endianness: %-31s │\n", get_endianness());
    printf("│ C Library: %-32s │\n", get_c_library());
    printf("│ Library Type: %-29s │\n", "Shared (.so)");
    printf("│ Loading Method: %-27s │\n", "LD_PRELOAD");
    
    if (readlink(proc_path, exe_path, sizeof(exe_path)-1) > 0) {
        char *exe_name = strrchr(exe_path, '/');
        if (exe_name) {
            exe_name++;
        } else {
            exe_name = exe_path;
        }
        printf("│ Injected Into: %-28s │\n", exe_name);
    }
    
    printf("│ Process PID: %-30d │\n", getpid());
    printf("└─────────────────────────────────────────────┘\n");
    
    printf("\n[*] Sthenos Custom Library loaded successfully!\n\n");
}

__attribute__((destructor))
void fini_library() {
    printf("[*] Sthenos Custom Library unloading...\n");
}