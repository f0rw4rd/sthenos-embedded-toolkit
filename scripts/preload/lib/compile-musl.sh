#!/bin/bash
# Compilation functions for preload libraries using musl toolchains

# Compile a single preload library with musl
build_preload_library_musl() {
    local lib="$1"
    local arch="$2"
    
    # Set libc type for output directory
    export LIBC_TYPE="musl"
    
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
    
    # Get musl toolchain path
    local musl_prefix=$(get_musl_toolchain_prefix "$arch")
    local musl_toolchain_dir="/build/toolchains/${musl_prefix}-cross"
    
    if [ ! -d "$musl_toolchain_dir" ]; then
        log_error "Musl toolchain not available for $arch"
        return 1
    fi
    
    # Get source
    local source=$(get_library_source "$lib")
    local compiler="${musl_toolchain_dir}/bin/${musl_prefix}-gcc"
    local strip_cmd="${musl_toolchain_dir}/bin/${musl_prefix}-strip"
    
    if [ ! -x "$compiler" ]; then
        log_error "Musl compiler not found: $compiler"
        return 1
    fi
    
    # Compilation flags for musl
    # Note: musl doesn't need _GNU_SOURCE in most cases, but we keep it for compatibility
    local cflags="-fPIC -O2 -Wall -D_GNU_SOURCE -fno-strict-aliasing"
    
    # Linker flags - musl specific
    local ldflags="-shared -Wl,-soname,${lib}.so"
    
    # Add architecture-specific optimizations
    case "$arch" in
        x86_64)
            cflags="$cflags -mtune=generic"
            ;;
        aarch64*)
            cflags="$cflags -mtune=generic"
            ;;
    esac
    
    log_debug "Compiling $lib for $arch with musl..."
    log_debug "Source: $source"
    log_debug "Compiler: $compiler"
    log_debug "CFLAGS: $cflags"
    log_debug "LDFLAGS: $ldflags"
    
    # Create temporary build directory
    local build_dir="/tmp/build-${lib}-${arch}-musl-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Compile
    {
        echo "=== Building $lib for $arch with musl ==="
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
    log "Successfully built with musl: $output_file ($size)"
    
    return 0
}

# Get musl toolchain prefix for architecture
get_musl_toolchain_prefix() {
    local arch="$1"
    
    case "$arch" in
        x86_64)      echo "x86_64-linux-musl" ;;
        aarch64)     echo "aarch64-linux-musl" ;;
        aarch64_be)  echo "aarch64_be-linux-musl" ;;
        arm32v5le)   echo "arm-linux-musleabi" ;;
        arm32v5lehf) echo "arm-linux-musleabihf" ;;
        arm32v7le)   echo "armv7l-linux-musleabihf" ;;
        arm32v7lehf) echo "armv7l-linux-musleabihf" ;;
        armeb)       echo "armeb-linux-musleabi" ;;
        armv6)       echo "armv6-linux-musleabihf" ;;
        armv7m)      echo "armv7m-linux-musleabi" ;;
        armv7r)      echo "armv7r-linux-musleabihf" ;;
        i486)        echo "i486-linux-musl" ;;
        ix86le)      echo "i686-linux-musl" ;;
        m68k)        echo "m68k-linux-musl" ;;
        microblaze)  echo "microblaze-linux-musl" ;;
        microblazeel) echo "microblazeel-linux-musl" ;;
        mips32v2be)  echo "mips-linux-musl" ;;
        mips32v2le)  echo "mipsel-linux-musl" ;;
        mips64)      echo "mips64-linux-musl" ;;
        mips64le)    echo "mips64el-linux-musl" ;;
        or1k)        echo "or1k-linux-musl" ;;
        ppc32be)     echo "powerpc-linux-musl" ;;
        powerpcle)   echo "powerpcle-linux-musl" ;;
        powerpc64)   echo "powerpc64-linux-musl" ;;
        ppc64le)     echo "powerpc64le-linux-musl" ;;
        riscv32)     echo "riscv32-linux-musl" ;;
        riscv64)     echo "riscv64-linux-musl" ;;
        s390x)       echo "s390x-linux-musl" ;;
        sh2)         echo "sh2-linux-musl" ;;
        sh2eb)       echo "sh2eb-linux-musl" ;;
        sh4)         echo "sh4-linux-musl" ;;
        sh4eb)       echo "sh4eb-linux-musl" ;;
        *)           echo "" ;;
    esac
}