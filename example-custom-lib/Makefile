LIB = custom-lib.so
SRCS = custom-lib.c
OBJS = $(SRCS:.c=.o)

CFLAGS += -fPIC -shared

all: $(LIB)

$(LIB): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(LIB) $(OBJS)

install: $(LIB)
	@echo "Library built successfully: $(LIB)"

.PHONY: all clean install