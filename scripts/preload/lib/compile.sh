#!/bin/bash
# Compilation functions for preload libraries

# Compile a single preload library
build_preload_library() {
    local lib="$1"
    local arch="$2"
    
    # Check if library source exists
    if ! library_exists "$lib"; then
        log_error "Library source not found: $lib"
        return 1
    fi
    
    # Ensure output directory exists
    local output_dir=$(get_output_dir "$arch")
    ensure_dir "$output_dir" || return 1
    
    # Setup logging
    local log_file=$(get_log_file "$lib" "$arch")
    ensure_dir "$(dirname "$log_file")" || return 1
    
    # Check if already built
    local output_file="${output_dir}/${lib}.so"
    if [ -f "$output_file" ]; then
        local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
        log "Already built: $output_file ($size)"
        return 0
    fi
    
    # Ensure toolchain exists
    if ! ensure_toolchain "$arch"; then
        log_error "Toolchain not available for $arch"
        return 1
    fi
    
    # Setup cross-compilation environment
    setup_cross_env "$arch"
    
    # Get source and compiler
    local source=$(get_library_source "$lib")
    local compiler=$(get_compiler "$arch")
    local strip_cmd=$(get_strip "$arch")
    
    # Compilation flags - optimize for maximum compatibility
    # -fPIC: Position Independent Code (required for shared libraries)
    # -O2: Standard optimization
    # -fno-strict-aliasing: Better compatibility with older code
    # No stack protector or hardening that might require newer runtime support
    local cflags="-fPIC -O2 -Wall -D_GNU_SOURCE -fno-strict-aliasing $CFLAGS"
    
    # Linker flags - minimal for compatibility
    # -shared: Build shared library
    # -soname: Set SONAME for the library
    # No RELRO or BIND_NOW which might not work on older systems
    # Add --hash-style=both for compatibility with older and newer loaders
    local ldflags="-shared -Wl,-soname,${lib}.so -Wl,--hash-style=both $LDFLAGS"
    
    # Add architecture-specific optimizations
    case "$arch" in
        x86_64)
            cflags="$cflags -mtune=generic"
            ;;
        aarch64)
            cflags="$cflags -mtune=generic"
            ;;
    esac
    
    log_debug "Compiling $lib for $arch..."
    log_debug "Source: $source"
    log_debug "Compiler: $compiler"
    log_debug "CFLAGS: $cflags"
    log_debug "LDFLAGS: $ldflags"
    
    # Create temporary build directory
    local build_dir="/tmp/build-${lib}-${arch}-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Compile
    {
        echo "=== Building $lib for $arch ==="
        echo "Date: $(date)"
        echo "Source: $source"
        echo "Compiler: $compiler"
        echo "CFLAGS: $cflags"
        echo "LDFLAGS: $ldflags"
        echo
        
        # Compile to object file
        echo "=== Compilation ==="
        $compiler $cflags -c "$source" -o "${lib}.o" 2>&1 || {
            echo "Compilation failed"
            cd /
            rm -rf "$build_dir"
            return 1
        }
        
        # Link to shared library
        echo
        echo "=== Linking ==="
        $compiler $ldflags -o "${lib}.so" "${lib}.o" -ldl 2>&1 || {
            echo "Linking failed"
            cd /
            rm -rf "$build_dir"
            return 1
        }
        
        # Strip symbols
        echo
        echo "=== Stripping ==="
        $strip_cmd "${lib}.so" 2>&1 || {
            echo "Warning: Strip failed (non-fatal)"
        }
        
        # Show library info
        echo
        echo "=== Library Info ==="
        file "${lib}.so"
        echo
        readelf -d "${lib}.so" | grep NEEDED || true
        echo
        ls -lh "${lib}.so"
        
    } 2>&1 | tee "$log_file"
    
    # Check if build succeeded
    if [ ! -f "${lib}.so" ]; then
        log_error "Build failed - no output file produced"
        cd /
        rm -rf "$build_dir"
        return 1
    fi
    
    # Copy to output directory
    cp "${lib}.so" "$output_file" || {
        log_error "Failed to copy library to output directory"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Create usage documentation
    create_usage_doc "$lib" "$arch" "$output_dir"
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    # Report success
    local size=$(ls -lh "$output_file" 2>/dev/null | awk '{print $5}')
    log "Successfully built: $output_file ($size)"
    
    return 0
}

# Create usage documentation for a library
create_usage_doc() {
    local lib="$1"
    local arch="$2"
    local output_dir="$3"
    
    case "$lib" in
        debug-helper-tmp)
            cat > "${output_dir}/${lib}-usage.txt" << 'EOF'
Debug Helper - Temporary Files
==============================

Usage:
    LD_PRELOAD=/path/to/debug-helper-tmp.so command

Environment Variables:
    DEBUG_TMP_LOG=/path/to/log    - Log to file instead of stderr
    DEBUG_TMP_TRACE_ALL=1         - Trace all file operations
    DEBUG_TMP_MAX_SIZE=1048576    - Warn when files exceed size (bytes)

Examples:
    # Trace temp file usage
    LD_PRELOAD=./debug-helper-tmp.so make -j8
    
    # Log to file
    DEBUG_TMP_LOG=/tmp/trace.log LD_PRELOAD=./debug-helper-tmp.so ./myapp
    
    # Monitor large files
    DEBUG_TMP_MAX_SIZE=10485760 LD_PRELOAD=./debug-helper-tmp.so ./build.sh

Features:
- Tracks file operations in /tmp, /var/tmp, /dev/shm
- Monitors file sizes and growth
- Detects unclosed file descriptors
- Reports file lifetimes
EOF
            ;;
            
        debug-helper-shell)
            cat > "${output_dir}/${lib}-usage.txt" << 'EOF'
Debug Helper - Shell Commands
=============================

Usage:
    LD_PRELOAD=/path/to/debug-helper-shell.so bash script.sh

Environment Variables:
    DEBUG_SHELL_LOG=/path/to/log  - Log to file instead of stderr
    DEBUG_SHELL_TRACE_ENV=1       - Include environment variables
    DEBUG_SHELL_TRACE_CWD=1       - Include working directory
    DEBUG_SHELL_INDENT=1          - Indent by process depth

Examples:
    # Trace shell script execution
    LD_PRELOAD=./debug-helper-shell.so bash build.sh
    
    # Full trace with environment
    DEBUG_SHELL_TRACE_ENV=1 DEBUG_SHELL_TRACE_CWD=1 \
        LD_PRELOAD=./debug-helper-shell.so make
    
    # Visualize process tree
    DEBUG_SHELL_INDENT=1 LD_PRELOAD=./debug-helper-shell.so ./configure

Features:
- Intercepts all exec* calls
- Tracks fork/wait operations
- Monitors system() and popen()
- Shows process relationships
EOF
            ;;
    esac
}