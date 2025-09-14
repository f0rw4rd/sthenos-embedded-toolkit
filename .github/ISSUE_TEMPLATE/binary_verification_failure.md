---
name: Binary Verification Failure
about: Report an issue with binary verification or execution
title: '[VERIFY] Binary verification failed for [TOOL] on [ARCHITECTURE]'
labels: 'bug, verification'
assignees: ''

---

## Binary Information
**Tool name:** 
<!-- e.g., strace, busybox, gdb, etc. -->

**Architecture:** 
<!-- e.g., x86_64, arm32v7le, mips64le, etc. -->

**Binary path:** 
<!-- e.g., /build/output/x86_64/strace -->

## Build Environment
**Docker image used:**
- [ ] stheno-musl (musl-based builds)
- [ ] stheno-glibc (glibc-based builds)

**Build command used:**
```bash
# Paste the exact build command here
```

## Verification Details

### File command output
```bash
# Run: file /path/to/binary
# Paste output here
```

### ldd output (if applicable)
```bash
# Run: ldd /path/to/binary
# Paste output here
```

### Readelf output
```bash
# Run: readelf -h /path/to/binary
# Paste output here
```

## Build Logs
<details>
<summary>Build log output</summary>

```
# Paste relevant build logs here
# You can find logs in:
# - /build/logs/ (for musl builds)
# - /build/logs-glibc-static/ (for glibc builds)
# - /build/logs-preload/ (for preload libraries)
```

</details>

## QEMU Testing (if attempted)

### QEMU command used
```bash
# e.g., qemu-arm-static /path/to/binary --version
```

### QEMU output/error
```
# Paste QEMU output or error messages here
```

## Expected vs Actual Behavior
**Expected:** 
<!-- What did you expect to happen? -->

**Actual:** 
<!-- What actually happened? -->

## Additional Context
<!-- Add any other context about the problem here -->

## Checklist
- [ ] I have included the build logs
- [ ] I have included the file command output
- [ ] I have included the architecture information
- [ ] I have tested with QEMU (if possible)
- [ ] I have checked that the toolchain for this architecture exists