#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <ctype.h>

#define MAX_SHELLCODE_SIZE 1048576

void print_usage(const char *prog) {
    fprintf(stderr, "Usage: %s [options]\n", prog);
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "  -x <hex>     Execute shellcode from hex string\n");
    fprintf(stderr, "  -f <file>    Execute shellcode from binary file\n");
    fprintf(stderr, "  -c           Execute shellcode from C array (stdin)\n");
    fprintf(stderr, "  -s           Execute raw shellcode from stdin\n");
    fprintf(stderr, "  -d           Debug mode (print shellcode info)\n");
    fprintf(stderr, "  -h           Show this help\n");
    exit(1);
}

size_t hex_to_bytes(const char *hex, unsigned char *bytes, size_t max_len) {
    size_t len = strlen(hex);
    size_t bytes_len = 0;
    
    if (len >= 2 && hex[0] == '0' && (hex[1] == 'x' || hex[1] == 'X')) {
        hex += 2;
        len -= 2;
    }
    
    for (size_t i = 0; i < len && bytes_len < max_len; i += 2) {
        char pair[3] = {0};
        pair[0] = hex[i];
        pair[1] = (i + 1 < len) ? hex[i + 1] : '0';
        
        unsigned int byte;
        if (sscanf(pair, "%02x", &byte) != 1) {
            fprintf(stderr, "Invalid hex at position %zu: %s\n", i, pair);
            return 0;
        }
        
        bytes[bytes_len++] = (unsigned char)byte;
    }
    
    return bytes_len;
}

size_t read_file(const char *filename, unsigned char *buffer, size_t max_len) {
    int fd = open(filename, O_RDONLY);
    if (fd < 0) {
        perror("open");
        return 0;
    }
    
    struct stat st;
    if (fstat(fd, &st) < 0) {
        perror("fstat");
        close(fd);
        return 0;
    }
    
    if (st.st_size > max_len) {
        fprintf(stderr, "File too large: %ld bytes (max %zu)\n", st.st_size, max_len);
        close(fd);
        return 0;
    }
    
    ssize_t bytes_read = read(fd, buffer, st.st_size);
    close(fd);
    
    if (bytes_read < 0) {
        perror("read");
        return 0;
    }
    
    return bytes_read;
}

size_t parse_c_array(unsigned char *buffer, size_t max_len) {
    size_t bytes_len = 0;
    char line[4096];
    
    while (fgets(line, sizeof(line), stdin) && bytes_len < max_len) {
        char *p = line;
        
        while (*p && bytes_len < max_len) {
            while (*p && !isxdigit(*p)) p++;
            if (!*p) break;
            
            if (*p == '0' && (*(p+1) == 'x' || *(p+1) == 'X')) {
                p += 2;
            }
            
            char hex[3] = {0};
            for (int i = 0; i < 2 && isxdigit(*p); i++) {
                hex[i] = *p++;
            }
            
            if (hex[0]) {
                unsigned int byte;
                if (sscanf(hex, "%02x", &byte) == 1) {
                    buffer[bytes_len++] = (unsigned char)byte;
                }
            }
        }
    }
    
    return bytes_len;
}

size_t read_stdin_raw(unsigned char *buffer, size_t max_len) {
    size_t total = 0;
    ssize_t bytes;
    
    while (total < max_len && (bytes = read(STDIN_FILENO, buffer + total, max_len - total)) > 0) {
        total += bytes;
    }
    
    return total;
}

void execute_shellcode(unsigned char *shellcode, size_t size, int debug) {
    if (debug) {
        printf("Shellcode size: %zu bytes\n", size);
        printf("First 32 bytes: ");
        for (size_t i = 0; i < size && i < 32; i++) {
            printf("%02x ", shellcode[i]);
        }
        printf("\n");
    }
    
    void *mem = mmap(NULL, size, PROT_READ | PROT_WRITE | PROT_EXEC,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    if (mem == MAP_FAILED) {
        perror("mmap");
        exit(1);
    }
    
    memcpy(mem, shellcode, size);
    
    if (debug) {
        printf("Executing shellcode at %p...\n", mem);
    }
    
    void (*func)() = (void (*)())mem;
    func();
    
    munmap(mem, size);
}

int main(int argc, char *argv[]) {
    unsigned char shellcode[MAX_SHELLCODE_SIZE];
    size_t shellcode_size = 0;
    int debug = 0;
    int opt;
    
    if (argc < 2) {
        print_usage(argv[0]);
    }
    
    while ((opt = getopt(argc, argv, "x:f:csdh")) != -1) {
        switch (opt) {
            case 'x':
                shellcode_size = hex_to_bytes(optarg, shellcode, MAX_SHELLCODE_SIZE);
                if (shellcode_size == 0) {
                    fprintf(stderr, "Failed to parse hex string\n");
                    exit(1);
                }
                break;
                
            case 'f':
                shellcode_size = read_file(optarg, shellcode, MAX_SHELLCODE_SIZE);
                if (shellcode_size == 0) {
                    fprintf(stderr, "Failed to read file: %s\n", optarg);
                    exit(1);
                }
                break;
                
            case 'c':
                shellcode_size = parse_c_array(shellcode, MAX_SHELLCODE_SIZE);
                if (shellcode_size == 0) {
                    fprintf(stderr, "Failed to parse C array\n");
                    exit(1);
                }
                break;
                
            case 's':
                shellcode_size = read_stdin_raw(shellcode, MAX_SHELLCODE_SIZE);
                if (shellcode_size == 0) {
                    fprintf(stderr, "No shellcode read from stdin\n");
                    exit(1);
                }
                break;
                
            case 'd':
                debug = 1;
                break;
                
            case 'h':
            default:
                print_usage(argv[0]);
        }
    }
    
    if (shellcode_size == 0) {
        fprintf(stderr, "No shellcode provided\n");
        print_usage(argv[0]);
    }
    
    execute_shellcode(shellcode, shellcode_size, debug);
    
    return 0;
}