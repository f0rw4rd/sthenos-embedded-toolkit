#include "custom-shared.h"

void print_build_info() {
    print_build_info_common("Build Information", "Static Binary");
}

void print_usage(const char *prog_name) {
    printf("\nUsage: %s [options]\n", prog_name);
    printf("\nOptions:\n");
    printf("  -h, --help     Show this help message\n");
    printf("  -a, --ascii    Show ASCII art\n");
    printf("  -i, --info     Show build information\n");
    printf("\nThis is a demonstration tool showing how to integrate\n");
    printf("custom C programs into the Sthenos Embedded Toolkit.\n");
    printf("\n");
}

int main(int argc, char *argv[]) {    
    int show_ascii = 0;
    int show_info = 0;
    
    if (argc > 1) {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
                print_usage(argv[0]);
                return 0;            
            } else if (strcmp(argv[i], "-a") == 0 || strcmp(argv[i], "--ascii") == 0) {
                show_ascii = 1;
            } else if (strcmp(argv[i], "-i") == 0 || strcmp(argv[i], "--info") == 0) {
                show_info = 1;
            } else {
                fprintf(stderr, "Unknown option: %s\n", argv[i]);
                print_usage(argv[0]);
                return 1;
            }
        }
    } else {        
        show_ascii = show_info = 1;
    }
    
    if (show_ascii) {
        print_ascii_art("Custom Tool Builder", "Static Binaries for All Architectures");
        printf("\n");
    }
    
    if (show_info) {
        print_build_info();
        printf("\n");
    }
    
    if (show_ascii || show_info) {
        printf("Hello from the Sthenos Custom Tool!\n");
        printf("This binary was statically compiled for embedded systems.\n");
        printf("\n");
    }
    
    return 0;
}