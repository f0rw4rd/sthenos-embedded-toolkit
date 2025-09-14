PROG = custom
SRCS = custom.c
OBJS = $(SRCS:.c=.o)

all: $(PROG)

$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -DBUILD_CFLAGS='"$(CFLAGS)"' -DBUILD_LDFLAGS='"$(LDFLAGS)"' -c -o $@ $<

clean:
	rm -f $(PROG) $(OBJS)

install: $(PROG)
	@echo "Binary built successfully: $(PROG)"

.PHONY: all clean install