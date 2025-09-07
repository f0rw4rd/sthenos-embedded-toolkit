#!/bin/bash
set -e

# Source logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"

TOOLCHAIN_DIR="/build/toolchains"
mkdir -p "$TOOLCHAIN_DIR"
cd "$TOOLCHAIN_DIR"

verify_toolchain() {
    local target_dir=$1
    
    # Check if directory exists
    if [ ! -d "$target_dir" ]; then
        return 1
    fi
    
    # Check if bin directory exists with gcc compiler
    if [ ! -d "$target_dir/bin" ]; then
        echo "  Warning: bin directory missing"
        return 1
    fi
    
    # Check for GCC compiler (less strict verification)
    local gcc_count=$(ls "$target_dir/bin/"*-gcc 2>/dev/null | wc -l)
    if [ $gcc_count -eq 0 ]; then
        echo "  Warning: GCC compiler not found"
        return 1
    fi
    
    return 0
}

download_toolchain() {
    local url=$1
    local target_dir=$2
    local filename=$(basename "$url")
    local max_retries=3
    local retry_count=0
    local download_success=false
    
    echo "Downloading $target_dir..."
    
    # Remove existing directory if corrupted
    if [ -d "$target_dir" ] && ! verify_toolchain "$target_dir"; then
        echo "  Removing corrupted toolchain..."
        rm -rf "$target_dir"
    fi
    
    # Skip if already exists and valid
    if [ -d "$target_dir" ] && verify_toolchain "$target_dir"; then
        echo "✓ $target_dir (already exists and valid)"
        return 0
    fi
    
    while [ $retry_count -lt $max_retries ]; do
        if wget -q --tries=2 --timeout=30 "$url" -O "$filename"; then
            download_success=true
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo "  Retry $retry_count/$max_retries for $target_dir..."
                sleep 5
            fi
        fi
    done
    
    if [ "$download_success" = false ]; then
        log_error "✗ Failed to download $target_dir after $max_retries attempts"
        return 1
    fi
    
    if tar xzf "$filename"; then
        # The extracted directory should match target_dir
        # (since we're using the actual toolchain names now)
        rm -f "$filename"
        
        # Verify the extracted toolchain
        if verify_toolchain "$target_dir"; then
            echo "✓ $target_dir"
        else
            log_error "✗ $target_dir extracted but appears corrupted"
            rm -rf "$target_dir"
            return 1
        fi
    else
        log_error "✗ Failed to extract $target_dir"
        rm -f "$filename"
        return 1
    fi
}

export -f verify_toolchain
export -f download_toolchain
export -f log_error

declare -a TOOLCHAINS=(
    "https://musl.cc/arm-linux-musleabi-cross.tgz arm-linux-musleabi-cross"
    "https://musl.cc/arm-linux-musleabihf-cross.tgz arm-linux-musleabihf-cross"
    "https://musl.cc/armv7l-linux-musleabihf-cross.tgz armv7l-linux-musleabihf-cross"
    "https://musl.cc/armeb-linux-musleabi-cross.tgz armeb-linux-musleabi-cross"
    "https://musl.cc/armv6-linux-musleabihf-cross.tgz armv6-linux-musleabihf-cross"
    "https://musl.cc/armv7m-linux-musleabi-cross.tgz armv7m-linux-musleabi-cross"
    "https://musl.cc/armv7r-linux-musleabihf-cross.tgz armv7r-linux-musleabihf-cross"
    "https://musl.cc/aarch64-linux-musl-cross.tgz aarch64-linux-musl-cross"
    "https://musl.cc/i686-linux-musl-cross.tgz i686-linux-musl-cross"
    "https://musl.cc/x86_64-linux-musl-cross.tgz x86_64-linux-musl-cross"
    "https://musl.cc/i486-linux-musl-cross.tgz i486-linux-musl-cross"
    "https://musl.cc/mipsel-linux-musl-cross.tgz mipsel-linux-musl-cross"
    "https://musl.cc/mipsel-linux-muslsf-cross.tgz mipsel-linux-muslsf-cross"
    "https://musl.cc/mips-linux-musl-cross.tgz mips-linux-musl-cross"
    "https://musl.cc/mips-linux-muslsf-cross.tgz mips-linux-muslsf-cross"
    "https://musl.cc/mips-linux-musln32sf-cross.tgz mips-linux-musln32sf-cross"
    "https://musl.cc/mipsel-linux-musln32sf-cross.tgz mipsel-linux-musln32sf-cross"
    "https://musl.cc/mips64el-linux-musl-cross.tgz mips64el-linux-musl-cross"
    "https://musl.cc/mips64-linux-musln32-cross.tgz mips64-linux-musln32-cross"
    "https://musl.cc/mips64el-linux-musln32-cross.tgz mips64el-linux-musln32-cross"
    "https://musl.cc/powerpc-linux-musl-cross.tgz powerpc-linux-musl-cross"
    "https://musl.cc/powerpc-linux-muslsf-cross.tgz powerpc-linux-muslsf-cross"
    "https://musl.cc/powerpcle-linux-musl-cross.tgz powerpcle-linux-musl-cross"
    "https://musl.cc/powerpcle-linux-muslsf-cross.tgz powerpcle-linux-muslsf-cross"
    "https://musl.cc/powerpc64-linux-musl-cross.tgz powerpc64-linux-musl-cross"
    "https://musl.cc/powerpc64le-linux-musl-cross.tgz powerpc64le-linux-musl-cross"
    "https://musl.cc/sh2-linux-musl-cross.tgz sh2-linux-musl-cross"
    "https://musl.cc/sh2eb-linux-musl-cross.tgz sh2eb-linux-musl-cross"
    "https://musl.cc/sh4-linux-musl-cross.tgz sh4-linux-musl-cross"
    "https://musl.cc/sh4eb-linux-musl-cross.tgz sh4eb-linux-musl-cross"
    "https://musl.cc/microblaze-linux-musl-cross.tgz microblaze-linux-musl-cross"
    "https://musl.cc/microblazeel-linux-musl-cross.tgz microblazeel-linux-musl-cross"
    "https://musl.cc/or1k-linux-musl-cross.tgz or1k-linux-musl-cross"
    "https://musl.cc/m68k-linux-musl-cross.tgz m68k-linux-musl-cross"
    "https://musl.cc/s390x-linux-musl-cross.tgz s390x-linux-musl-cross"
    "https://musl.cc/riscv32-linux-musl-cross.tgz riscv32-linux-musl-cross"
    "https://musl.cc/riscv64-linux-musl-cross.tgz riscv64-linux-musl-cross"
    "https://musl.cc/aarch64_be-linux-musl-cross.tgz aarch64_be-linux-musl-cross"
    "https://musl.cc/mips64-linux-musl-cross.tgz mips64-linux-musl-cross"
)

echo "Downloading ${#TOOLCHAINS[@]} toolchains in parallel..."

JOB_DIR="/tmp/musl-toolchain-jobs-$$"
mkdir -p "$JOB_DIR"

download_with_tracking() {
    local line="$1"
    local url=$(echo "$line" | cut -d' ' -f1)
    local target_dir=$(echo "$line" | cut -d' ' -f2)
    local job_file="$JOB_DIR/$target_dir"
    
    if download_toolchain "$url" "$target_dir"; then
        echo "success" > "$job_file"
    else
        log_error "failed" > "$job_file"
    fi
}

export -f download_with_tracking
export JOB_DIR

if command -v parallel >/dev/null 2>&1; then
    printf '%s\n' "${TOOLCHAINS[@]}" | parallel -j 8 download_with_tracking {}
else
    printf '%s\n' "${TOOLCHAINS[@]}" | xargs -P 8 -I {} bash -c 'download_with_tracking "$@"' _ {}
fi

TOTAL=0
SUCCESS=0
FAILED=0
FAILED_TOOLCHAINS=""

for line in "${TOOLCHAINS[@]}"; do
    target_dir=$(echo "$line" | cut -d' ' -f2)
    TOTAL=$((TOTAL + 1))
    if [ -f "$JOB_DIR/$target_dir" ]; then
        result=$(cat "$JOB_DIR/$target_dir")
        if [ "$result" = "success" ]; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
            FAILED_TOOLCHAINS="$FAILED_TOOLCHAINS|$line"
        fi
    else
        FAILED=$((FAILED + 1))
        FAILED_TOOLCHAINS="$FAILED_TOOLCHAINS|$line"
        echo "No result for: $target_dir"
    fi
done

rm -rf "$JOB_DIR"

echo
echo "Download Summary"
echo "Total: $TOTAL"
echo "Successful: $SUCCESS"
log_error "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    echo
    log_error "Retrying failed downloads sequentially..."
    echo
    
    IFS='|' read -ra FAILED_ARRAY <<< "$FAILED_TOOLCHAINS"
    RETRY_SUCCESS=0
    
    for line in "${FAILED_ARRAY[@]}"; do
        if [ -n "$line" ]; then
            url=$(echo "$line" | cut -d' ' -f1)
            target_dir=$(echo "$line" | cut -d' ' -f2)
            
            echo "Retrying download for $target_dir..."
            if download_toolchain "$url" "$target_dir"; then
                RETRY_SUCCESS=$((RETRY_SUCCESS + 1))
                echo "Successfully downloaded $target_dir on retry"
            else
                log_error "Failed to download $target_dir even on retry"
            fi
        fi
    done
    
    FINAL_FAILED=$((FAILED - RETRY_SUCCESS))
    FINAL_SUCCESS=$((SUCCESS + RETRY_SUCCESS))
    
    echo
    echo "Final Download Summary"
    echo "Total: $TOTAL"
    echo "Successful: $FINAL_SUCCESS"
    log_error "Failed: $FINAL_FAILED"
    
    if [ "$FINAL_FAILED" -gt 0 ]; then
        echo
        log_error "$FINAL_FAILED toolchain(s) failed to download even after retries"
        exit 1
    fi
fi

if [ -d "arm32v7le" ] && [ ! -d "arm32v7lehf" ]; then
    cp -a arm32v7le arm32v7lehf
    echo "✓ arm32v7lehf (copied from arm32v7le)"
fi

echo
echo "All toolchains downloaded successfully"

# Final verification
echo
echo "Verifying all toolchains..."
VERIFICATION_FAILED=0
for line in "${TOOLCHAINS[@]}"; do
    target_dir=$(echo "$line" | cut -d' ' -f2)
    if [ -d "$target_dir" ]; then
        if ! verify_toolchain "$target_dir" >/dev/null 2>&1; then
            header_count=$(find "$target_dir" -name "*.h" 2>/dev/null | wc -l)
            log_error "✗ $target_dir appears corrupted ($header_count headers)"
            VERIFICATION_FAILED=$((VERIFICATION_FAILED + 1))
        fi
    else
        log_error "✗ $target_dir is missing"
        VERIFICATION_FAILED=$((VERIFICATION_FAILED + 1))
    fi
done

if [ "$VERIFICATION_FAILED" -gt 0 ]; then
    echo
    log_error "$VERIFICATION_FAILED toolchain(s) failed verification"
    exit 1
else
    echo "✓ All toolchains verified successfully"
fi