# Makefile for custom tool example
# This will be used by the build system when CUSTOM_LOCAL_SOURCE is set

# Tool name
PROG = custom

# Source files
SRCS = custom.c

# Object files
OBJS = $(SRCS:.c=.o)

# Default target
all: $(PROG)

# Build the program
$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

# Compile source files
%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Clean build artifacts
clean:
	rm -f $(PROG) $(OBJS)

# Install target (used by build system)
install: $(PROG)
	@echo "Binary built successfully: $(PROG)"

.PHONY: all clean install