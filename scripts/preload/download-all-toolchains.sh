#!/bin/bash
# Download all pre-built glibc toolchains during Docker build
# This ensures toolchains are available at runtime
set -euo pipefail

echo "==================================="
echo "Downloading All Glibc Toolchains"
echo "==================================="
echo "This will download all 24 glibc toolchains"
echo "Build timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==================================="
echo

# All supported architectures (24 total - xtensa removed as it only has uclibc)
ARCHITECTURES="x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x \
               aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el \
               riscv32 microblazeel microblazebe nios2 openrisc arcle m68k"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the download script which has the download_toolchain function
source "$SCRIPT_DIR/download-toolchains.sh"

# Number of parallel downloads (adjust based on your connection)
# Can be overridden with TOOLCHAIN_PARALLEL_DOWNLOADS environment variable
PARALLEL_JOBS=${TOOLCHAIN_PARALLEL_DOWNLOADS:-8}

# Create a temporary directory for job tracking
JOB_DIR="/tmp/toolchain-jobs-$$"
mkdir -p "$JOB_DIR"

# Function to download with job tracking
download_with_tracking() {
    local arch="$1"
    local job_file="$JOB_DIR/$arch"
    
    if download_toolchain "$arch"; then
        echo "success" > "$job_file"
    else
        echo "failed" > "$job_file"
    fi
}

# Start downloads in parallel
echo "Starting parallel downloads (${PARALLEL_JOBS} concurrent)..."
echo

JOB_COUNT=0
for arch in $ARCHITECTURES; do
    # Wait if we've reached the parallel job limit
    while [ $(jobs -r | wc -l) -ge $PARALLEL_JOBS ]; do
        sleep 0.1
    done
    
    JOB_COUNT=$((JOB_COUNT + 1))
    echo "[$JOB_COUNT/24] Starting download for $arch..."
    download_with_tracking "$arch" &
done

# Wait for all jobs to complete
echo
echo "Waiting for all downloads to complete..."
wait

# Count results
TOTAL=0
SUCCESS=0
FAILED=0
FAILED_ARCHS=""

for arch in $ARCHITECTURES; do
    TOTAL=$((TOTAL + 1))
    if [ -f "$JOB_DIR/$arch" ]; then
        result=$(cat "$JOB_DIR/$arch")
        if [ "$result" = "success" ]; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
            FAILED_ARCHS="$FAILED_ARCHS $arch"
            echo "Failed: $arch"
        fi
    else
        FAILED=$((FAILED + 1))
        FAILED_ARCHS="$FAILED_ARCHS $arch"
        echo "No result for: $arch"
    fi
done

# Cleanup
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
    echo "WARNING: $FAILED toolchain(s) failed to download"
    echo "Retrying failed downloads sequentially..."
    echo
    
    # Collect failed architectures
    FAILED_ARCHS=""
    for arch in $ARCHITECTURES; do
        if [ -f "$JOB_DIR/$arch" ]; then
            result=$(cat "$JOB_DIR/$arch")
            if [ "$result" = "failed" ]; then
                FAILED_ARCHS="$FAILED_ARCHS $arch"
            fi
        fi
    done
    
    # Retry failed downloads one by one
    RETRY_SUCCESS=0
    for arch in $FAILED_ARCHS; do
        echo "Retrying download for $arch..."
        if download_toolchain "$arch"; then
            RETRY_SUCCESS=$((RETRY_SUCCESS + 1))
            echo "Successfully downloaded $arch on retry"
        else
            echo "Failed to download $arch even on retry"
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
        echo "The Docker build will fail to ensure all architectures are supported"
        exit 1
    fi
fi

echo
echo "All toolchains downloaded successfully!"
exit 0