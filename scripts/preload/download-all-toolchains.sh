#!/bin/bash
set -euo pipefail

echo "Downloading All Glibc Toolchains"
echo "This will download all 28 glibc toolchains"
echo "Build timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo

ARCHITECTURES="x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x \
               aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el \
               riscv32 microblazeel microblazebe nios2 openrisc arcle m68k \
               mips32v2besf mips32v2lesf ppc32besf powerpclesf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/download-toolchains.sh"

PARALLEL_JOBS=${TOOLCHAIN_PARALLEL_DOWNLOADS:-8}

JOB_DIR="/tmp/toolchain-jobs-$$"
mkdir -p "$JOB_DIR"

download_with_tracking() {
    local arch="$1"
    local job_file="$JOB_DIR/$arch"
    
    if download_toolchain "$arch"; then
        echo "success" > "$job_file"
    else
        log_error "failed" > "$job_file"
    fi
}

echo "Starting parallel downloads (${PARALLEL_JOBS} concurrent)..."
echo

JOB_COUNT=0
for arch in $ARCHITECTURES; do
    while [ $(jobs -r | wc -l) -ge $PARALLEL_JOBS ]; do
        sleep 0.1
    done
    
    JOB_COUNT=$((JOB_COUNT + 1))
    log_tool "$JOB_COUNT/28" "Starting download for $arch..."
    download_with_tracking "$arch" &
done

echo
echo "Waiting for all downloads to complete..."
wait

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
            log_error "Failed: $arch"
        fi
    else
        FAILED=$((FAILED + 1))
        FAILED_ARCHS="$FAILED_ARCHS $arch"
        echo "No result for: $arch"
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
    log_warn "WARNING: $FAILED toolchain(s) failed to download"
    log_error "Retrying failed downloads sequentially..."
    echo
    
    FAILED_ARCHS=""
    for arch in $ARCHITECTURES; do
        if [ -f "$JOB_DIR/$arch" ]; then
            result=$(cat "$JOB_DIR/$arch")
            if [ "$result" = "failed" ]; then
                FAILED_ARCHS="$FAILED_ARCHS $arch"
            fi
        fi
    done
    
    RETRY_SUCCESS=0
    for arch in $FAILED_ARCHS; do
        echo "Retrying download for $arch..."
        if download_toolchain "$arch"; then
            RETRY_SUCCESS=$((RETRY_SUCCESS + 1))
            echo "Successfully downloaded $arch on retry"
        else
            log_error "Failed to download $arch even on retry"
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
        echo "The Docker build will fail to ensure all architectures are supported"
        exit 1
    fi
fi

echo
echo "All toolchains downloaded successfully!"
exit 0