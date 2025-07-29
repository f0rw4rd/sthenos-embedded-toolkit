#!/bin/bash
# Script to download all toolchains in parallel
set -e

TOOLCHAIN_DIR="/build/toolchains"
mkdir -p "$TOOLCHAIN_DIR"
cd "$TOOLCHAIN_DIR"

# Function to download and extract a toolchain
download_toolchain() {
    local url=$1
    local target_dir=$2
    local filename=$(basename "$url")
    local max_retries=3
    local retry_count=0
    local download_success=false
    
    echo "Downloading $target_dir..."
    
    # Download with retries
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
        echo "✗ Failed to download $target_dir after $max_retries attempts"
        return 1
    fi
    
    # Extract and move
    if tar xzf "$filename"; then
        local extracted_dir="${filename%.tgz}"
        extracted_dir="${extracted_dir%-cross}"
        if [ -d "$extracted_dir" ]; then
            mv "$extracted_dir" "$target_dir"
        fi
        rm -f "$filename"
        echo "✓ $target_dir"
    else
        echo "✗ Failed to extract $target_dir"
        rm -f "$filename"
        return 1
    fi
}

# Export function for parallel execution
export -f download_toolchain

# Define all toolchains
declare -a TOOLCHAINS=(
    "https://musl.cc/arm-linux-musleabi-cross.tgz arm32v5le"
    "https://musl.cc/arm-linux-musleabihf-cross.tgz arm32v5lehf"
    "https://musl.cc/armv7l-linux-musleabihf-cross.tgz arm32v7le"
    "https://musl.cc/armeb-linux-musleabi-cross.tgz armeb"
    "https://musl.cc/armv6-linux-musleabihf-cross.tgz armv6"
    "https://musl.cc/armv7m-linux-musleabi-cross.tgz armv7m"
    "https://musl.cc/armv7r-linux-musleabihf-cross.tgz armv7r"
    "https://musl.cc/aarch64-linux-musl-cross.tgz aarch64"
    "https://musl.cc/i686-linux-musl-cross.tgz ix86le"
    "https://musl.cc/x86_64-linux-musl-cross.tgz x86_64"
    "https://musl.cc/i486-linux-musl-cross.tgz i486"
    "https://musl.cc/mipsel-linux-musl-cross.tgz mips32v2le"
    "https://musl.cc/mips-linux-musl-cross.tgz mips32v2be"
    "https://musl.cc/mips-linux-musln32sf-cross.tgz mipsn32"
    "https://musl.cc/mipsel-linux-musln32sf-cross.tgz mipsn32el"
    "https://musl.cc/mips64el-linux-musl-cross.tgz mips64le"
    "https://musl.cc/mips64-linux-musln32-cross.tgz mips64n32"
    "https://musl.cc/mips64el-linux-musln32-cross.tgz mips64n32el"
    "https://musl.cc/powerpc-linux-musl-cross.tgz ppc32be"
    "https://musl.cc/powerpcle-linux-musl-cross.tgz powerpcle"
    "https://musl.cc/powerpc64-linux-musl-cross.tgz powerpc64"
    "https://musl.cc/powerpc64le-linux-musl-cross.tgz ppc64le"
    "https://musl.cc/sh2-linux-musl-cross.tgz sh2"
    "https://musl.cc/sh2eb-linux-musl-cross.tgz sh2eb"
    "https://musl.cc/sh4-linux-musl-cross.tgz sh4"
    "https://musl.cc/sh4eb-linux-musl-cross.tgz sh4eb"
    "https://musl.cc/microblaze-linux-musl-cross.tgz microblaze"
    "https://musl.cc/microblazeel-linux-musl-cross.tgz microblazeel"
    "https://musl.cc/or1k-linux-musl-cross.tgz or1k"
    "https://musl.cc/m68k-linux-musl-cross.tgz m68k"
    "https://musl.cc/s390x-linux-musl-cross.tgz s390x"
    "https://musl.cc/riscv32-linux-musl-cross.tgz riscv32"
    "https://musl.cc/riscv64-linux-musl-cross.tgz riscv64"
    "https://musl.cc/aarch64_be-linux-musl-cross.tgz aarch64_be"
    "https://musl.cc/mips64-linux-musl-cross.tgz mips64"
)

echo "Downloading ${#TOOLCHAINS[@]} toolchains in parallel..."

# Create a temporary directory for job tracking
JOB_DIR="/tmp/musl-toolchain-jobs-$$"
mkdir -p "$JOB_DIR"

# Function to download with job tracking
download_with_tracking() {
    local line="$1"
    local url=$(echo "$line" | cut -d' ' -f1)
    local target_dir=$(echo "$line" | cut -d' ' -f2)
    local job_file="$JOB_DIR/$target_dir"
    
    if download_toolchain "$url" "$target_dir"; then
        echo "success" > "$job_file"
    else
        echo "failed" > "$job_file"
    fi
}

# Export function for parallel execution
export -f download_with_tracking
export JOB_DIR

# Use GNU parallel if available, otherwise use xargs
if command -v parallel >/dev/null 2>&1; then
    printf '%s\n' "${TOOLCHAINS[@]}" | parallel -j 8 download_with_tracking {}
else
    # Use xargs with -P for parallel processing
    printf '%s\n' "${TOOLCHAINS[@]}" | xargs -P 8 -I {} bash -c 'download_with_tracking "$@"' _ {}
fi

# Count results
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

# Cleanup job directory
rm -rf "$JOB_DIR"

echo
echo "==================================="
echo "Download Summary"
echo "==================================="
echo "Total: $TOTAL"
echo "Successful: $SUCCESS"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    echo
    echo "Retrying failed downloads sequentially..."
    echo
    
    # Convert to array and retry
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
                echo "Failed to download $target_dir even on retry"
            fi
        fi
    done
    
    # Recalculate final results
    FINAL_FAILED=$((FAILED - RETRY_SUCCESS))
    FINAL_SUCCESS=$((SUCCESS + RETRY_SUCCESS))
    
    echo
    echo "==================================="
    echo "Final Download Summary"
    echo "==================================="
    echo "Total: $TOTAL"
    echo "Successful: $FINAL_SUCCESS"
    echo "Failed: $FINAL_FAILED"
    
    if [ "$FINAL_FAILED" -gt 0 ]; then
        echo
        echo "ERROR: $FINAL_FAILED toolchain(s) failed to download even after retries"
        exit 1
    fi
fi

# Special case: arm32v7lehf is a copy of arm32v7le
if [ -d "arm32v7le" ] && [ ! -d "arm32v7lehf" ]; then
    cp -a arm32v7le arm32v7lehf
    echo "✓ arm32v7lehf (copied from arm32v7le)"
fi

echo
echo "All toolchains downloaded successfully"