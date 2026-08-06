PROG = custom
SRCS = custom.c
OBJS = $(SRCS:.c=.o)

all: $(PROG)

$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

# STHENOS_ARCH/OS/LIBC are exported by build-custom.sh so the binary can report
# the exact target it was cross-compiled for. Optional: compiled standalone
# (plain `make`) they expand empty and the program falls back to preprocessor
# detection.
%.o: %.c
	$(CC) $(CFLAGS) -DBUILD_CFLAGS='"$(CFLAGS)"' -DBUILD_LDFLAGS='"$(LDFLAGS)"' \
		-DSTHENOS_ARCH='"$(STHENOS_ARCH)"' -DSTHENOS_OS='"$(STHENOS_OS)"' -DSTHENOS_LIBC='"$(STHENOS_LIBC)"' \
		-c -o $@ $<

clean:
	rm -f $(PROG) $(OBJS)

install: $(PROG)
	@echo "Binary built successfully: $(PROG)"

.PHONY: all clean install