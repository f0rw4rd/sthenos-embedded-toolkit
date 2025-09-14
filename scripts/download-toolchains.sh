#!/bin/bash
set -euo pipefail

echo "Toolchain Downloader"
echo "============================"
echo "Build timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# Source architecture definitions directly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/core/architectures.sh"
source "$SCRIPT_DIR/lib/core/arch_helper.sh"

# Configuration for both musl and glibc
MUSL_TOOLCHAIN_DIR="/build/toolchains"
GLIBC_TOOLCHAIN_DIR="/build/toolchains-glibc"
PARALLEL_JOBS=${TOOLCHAIN_PARALLEL_DOWNLOADS:-8}
BASE_URL_BOOTLIN="https://toolchains.bootlin.com/downloads/releases/toolchains"

mkdir -p "$MUSL_TOOLCHAIN_DIR" "$GLIBC_TOOLCHAIN_DIR"

# Verify toolchain function (works for both musl and glibc)
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

# Download musl toolchain from musl.cc
download_musl_toolchain() {
    local url=$1
    local target_dir=$2
    local filename=$(basename "$url")
    local max_retries=3
    local retry_count=0
    local download_success=false
    
    echo "Downloading musl $target_dir..."
    
    cd "$MUSL_TOOLCHAIN_DIR"
    
    # Remove existing directory if corrupted
    if [ -d "$target_dir" ] && ! verify_toolchain "$target_dir"; then
        echo "  Removing corrupted toolchain..."
        rm -rf "$target_dir"
    fi
    
    # Skip if already exists and valid
    if [ -d "$target_dir" ] && verify_toolchain "$target_dir"; then
        echo "SUCCESS: $target_dir (already exists and valid)"
        return 0
    fi
    
    source "$(dirname "$0")/lib/build_helpers.sh"
    if ! download_with_progress "$target_dir" "$url" "$filename" "$max_retries" "30"; then
        download_success=false
    else
        download_success=true
    fi
    
    if [ "$download_success" = false ]; then
        log_error "ERROR: Failed to download $target_dir after $max_retries attempts"
        return 1
    fi
    
    # Extract with progress indicator
    local file_size=$(ls -lh "$filename" | awk '{print $5}')
    echo "  Extracting $filename ($file_size)..."
    if tar xzf "$filename"; then
        rm -f "$filename"
        
        # Verify the extracted toolchain
        if verify_toolchain "$target_dir"; then
            echo "SUCCESS: $target_dir"
        else
            log_error "ERROR: $target_dir extracted but appears corrupted"
            rm -rf "$target_dir"
            return 1
        fi
    else
        log_error "ERROR: Failed to extract $target_dir"
        rm -f "$filename"
        return 1
    fi
}

# Download glibc toolchain from bootlin
download_glibc_toolchain() {
    local arch="$1"
    
    # Get bootlin URL directly from architecture config
    local bootlin_url=$(get_bootlin_url "$arch" 2>/dev/null)
    if [ -z "$bootlin_url" ]; then
        log "Skipping $arch - no bootlin_url defined"
        return 0
    fi
    
    # Get glibc name for target directory
    local glibc_name=$(get_glibc_toolchain "$arch" 2>/dev/null)
    if [ -z "$glibc_name" ]; then
        log_error "No glibc toolchain name for $arch"
        return 1
    fi
    
    local target_dir="$GLIBC_TOOLCHAIN_DIR/$glibc_name"
    
    # Skip if already exists
    if [ -d "$target_dir" ] && [ -d "$target_dir/bin" ]; then
        log "$arch toolchain already exists"
        return 0
    fi
    
    log "Downloading $arch toolchain..."
    log "  URL: $BASE_URL_BOOTLIN/$bootlin_url"
    log "  Target: $target_dir"
    
    # Create temp directory
    local temp_dir="/tmp/toolchain-${arch}-$$-$(date +%s%N)"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Cleanup function
    cleanup_temp() {
        cd /
        rm -rf "$temp_dir"
    }
    trap cleanup_temp EXIT
    
    # Download with retries
    local url="$BASE_URL_BOOTLIN/$bootlin_url"
    local filename=$(basename "$bootlin_url")
    local max_retries=3
    local retry_count=0
    
    if ! download_with_progress "$arch" "$url" "$filename" "$max_retries" "60"; then
        cleanup_temp
        return 1
    fi
    
    # Extract with progress
    local file_size=$(ls -lh "$filename" | awk '{print $5}')
    log "  Extracting $filename ($file_size)..."
    if ! tar xf "$filename"; then
        log_error "Failed to extract $arch toolchain"
        return 1
    fi
    
    # Find extracted directory
    local extracted_dir=$(find . -maxdepth 1 -type d -name "*" | grep -v "^\.$" | head -1)
    if [ -z "$extracted_dir" ]; then
        log_error "No directory found after extraction for $arch"
        return 1
    fi
    
    # Move to final location
    mkdir -p "$(dirname "$target_dir")"
    mv "$extracted_dir" "$target_dir"
    
    # Verify
    if [ ! -d "$target_dir/bin" ]; then
        log_error "Invalid toolchain structure for $arch - no bin directory"
        return 1
    fi
    
    log "Successfully installed $arch toolchain"
    return 0
}

export -f verify_toolchain
export -f download_musl_toolchain
export -f download_glibc_toolchain
export -f log_error

# Musl toolchains from musl.cc
declare -a MUSL_TOOLCHAINS=(
    "https://musl.cc/arm-linux-musleabi-cross.tgz arm-linux-musleabi-cross"
    "https://musl.cc/arm-linux-musleabihf-cross.tgz arm-linux-musleabihf-cross"
    "https://musl.cc/armv7l-linux-musleabihf-cross.tgz armv7l-linux-musleabihf-cross"
    "https://musl.cc/armeb-linux-musleabi-cross.tgz armeb-linux-musleabi-cross"
    "https://musl.cc/armeb-linux-musleabihf-cross.tgz armeb-linux-musleabihf-cross"
    "https://musl.cc/armel-linux-musleabi-cross.tgz armel-linux-musleabi-cross"
    "https://musl.cc/armel-linux-musleabihf-cross.tgz armel-linux-musleabihf-cross"
    "https://musl.cc/armv5l-linux-musleabi-cross.tgz armv5l-linux-musleabi-cross"
    "https://musl.cc/armv5l-linux-musleabihf-cross.tgz armv5l-linux-musleabihf-cross"
    "https://musl.cc/armv6-linux-musleabi-cross.tgz armv6-linux-musleabi-cross"
    "https://musl.cc/armv6-linux-musleabihf-cross.tgz armv6-linux-musleabihf-cross"
    "https://musl.cc/armv7m-linux-musleabi-cross.tgz armv7m-linux-musleabi-cross"
    "https://musl.cc/armv7r-linux-musleabihf-cross.tgz armv7r-linux-musleabihf-cross"
    "https://musl.cc/aarch64-linux-musl-cross.tgz aarch64-linux-musl-cross"
    "https://musl.cc/i686-linux-musl-cross.tgz i686-linux-musl-cross"
    "https://musl.cc/x86_64-linux-musl-cross.tgz x86_64-linux-musl-cross"
    "https://musl.cc/x86_64-linux-muslx32-cross.tgz x86_64-linux-muslx32-cross"
    "https://musl.cc/i486-linux-musl-cross.tgz i486-linux-musl-cross"
    "https://musl.cc/mipsel-linux-musl-cross.tgz mipsel-linux-musl-cross"
    "https://musl.cc/mipsel-linux-muslsf-cross.tgz mipsel-linux-muslsf-cross"
    "https://musl.cc/mips-linux-musl-cross.tgz mips-linux-musl-cross"
    "https://musl.cc/mips-linux-muslsf-cross.tgz mips-linux-muslsf-cross"
    "https://musl.cc/mips-linux-musln32sf-cross.tgz mips-linux-musln32sf-cross"
    "https://musl.cc/mipsel-linux-musln32-cross.tgz mipsel-linux-musln32-cross"
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

echo "PHASE 1: Downloading ${#MUSL_TOOLCHAINS[@]} musl toolchains"
echo

# Track results
declare -A MUSL_RESULTS
MUSL_JOB_DIR="/tmp/musl-toolchain-jobs-$$"
mkdir -p "$MUSL_JOB_DIR"

download_musl_with_tracking() {
    local line="$1"
    local url=$(echo "$line" | cut -d' ' -f1)
    local target_dir=$(echo "$line" | cut -d' ' -f2)
    local job_file="$MUSL_JOB_DIR/$target_dir"
    
    if download_musl_toolchain "$url" "$target_dir"; then
        echo "success" > "$job_file"
    else
        echo "failed" > "$job_file"
    fi
}

export -f download_musl_with_tracking
export MUSL_JOB_DIR

# Download musl toolchains in parallel
if command -v parallel >/dev/null 2>&1; then
    printf '%s\n' "${MUSL_TOOLCHAINS[@]}" | parallel -j $PARALLEL_JOBS download_musl_with_tracking {}
else
    printf '%s\n' "${MUSL_TOOLCHAINS[@]}" | xargs -P $PARALLEL_JOBS -I {} bash -c 'download_musl_with_tracking "$@"' _ {}
fi

echo
echo "Waiting for musl downloads to complete..."
wait

# Collect musl results
MUSL_TOTAL=0
MUSL_SUCCESS=0
MUSL_FAILED=0

for line in "${MUSL_TOOLCHAINS[@]}"; do
    target_dir=$(echo "$line" | cut -d' ' -f2)
    MUSL_TOTAL=$((MUSL_TOTAL + 1))
    
    if [ -f "$MUSL_JOB_DIR/$target_dir" ]; then
        result=$(cat "$MUSL_JOB_DIR/$target_dir")
        if [ "$result" = "success" ]; then
            MUSL_SUCCESS=$((MUSL_SUCCESS + 1))
            MUSL_RESULTS["$target_dir"]="OK"
        else
            MUSL_FAILED=$((MUSL_FAILED + 1))
            MUSL_RESULTS["$target_dir"]="FAIL"
        fi
    else
        MUSL_FAILED=$((MUSL_FAILED + 1))
        MUSL_RESULTS["$target_dir"]="ERR"
    fi
done

rm -rf "$MUSL_JOB_DIR"

# Copy arm32v7le to arm32v7lehf if needed
cd "$MUSL_TOOLCHAIN_DIR"
if [ -d "arm32v7le" ] && [ ! -d "arm32v7lehf" ]; then
    cp -a arm32v7le arm32v7lehf
    echo "SUCCESS: arm32v7lehf (copied from arm32v7le)"
    MUSL_RESULTS["arm32v7lehf"]="OK"
    MUSL_SUCCESS=$((MUSL_SUCCESS + 1))
fi

echo
echo "PHASE 2: Downloading glibc toolchains"
echo

# Get all architectures that have glibc support
GLIBC_ARCHS=()
for arch in "${ALL_ARCHITECTURES[@]}"; do
    if arch_supports_glibc "$arch"; then
        GLIBC_ARCHS+=("$arch")
    fi
done

echo "Found ${#GLIBC_ARCHS[@]} architectures with glibc support"
echo "Starting glibc downloads with $PARALLEL_JOBS parallel jobs..."
echo

# Track glibc results
declare -A GLIBC_RESULTS
GLIBC_JOB_DIR="/tmp/glibc-toolchain-jobs-$$"
mkdir -p "$GLIBC_JOB_DIR"

download_glibc_with_tracking() {
    local arch="$1"
    local result_file="$GLIBC_JOB_DIR/$arch"
    
    if download_glibc_toolchain "$arch"; then
        echo "success" > "$result_file"
    else
        echo "failed" > "$result_file"
    fi
}

export -f download_glibc_with_tracking
export GLIBC_JOB_DIR

# Start parallel glibc downloads
for arch in "${GLIBC_ARCHS[@]}"; do
    # Control parallel jobs
    while [ $(jobs -r | wc -l) -ge $PARALLEL_JOBS ]; do
        sleep 0.1
    done
    
    download_glibc_with_tracking "$arch" &
done

# Wait for all glibc jobs
echo "Waiting for glibc downloads to complete..."
wait

# Collect glibc results
GLIBC_TOTAL=0
GLIBC_SUCCESS=0
GLIBC_FAILED=0

for arch in "${GLIBC_ARCHS[@]}"; do
    GLIBC_TOTAL=$((GLIBC_TOTAL + 1))
    result_file="$GLIBC_JOB_DIR/$arch"
    
    if [ -f "$result_file" ]; then
        result=$(cat "$result_file")
        if [ "$result" = "success" ]; then
            GLIBC_SUCCESS=$((GLIBC_SUCCESS + 1))
            GLIBC_RESULTS["$arch"]="OK"
        else
            GLIBC_FAILED=$((GLIBC_FAILED + 1))
            GLIBC_RESULTS["$arch"]="FAIL"
        fi
    else
        GLIBC_FAILED=$((GLIBC_FAILED + 1))
        GLIBC_RESULTS["$arch"]="ERR"
    fi
done

rm -rf "$GLIBC_JOB_DIR"

echo
echo "FINAL RESULTS"
echo

# Print musl results
echo "Musl toolchains (${#MUSL_TOOLCHAINS[@]} total):"
for line in "${MUSL_TOOLCHAINS[@]}"; do
    target_dir=$(echo "$line" | cut -d' ' -f2)
    echo "${MUSL_RESULTS[$target_dir]} $target_dir"
done
if [ -d "$MUSL_TOOLCHAIN_DIR/arm32v7lehf" ]; then
    echo "${MUSL_RESULTS[arm32v7lehf]} arm32v7lehf (copied)"
fi

echo
echo "Glibc toolchains (${#GLIBC_ARCHS[@]} total):"
for arch in "${GLIBC_ARCHS[@]}"; do
    echo "${GLIBC_RESULTS[$arch]} $arch"
done

echo
echo "Summary:"
echo "  Musl Total: $MUSL_TOTAL, Success: $MUSL_SUCCESS, Failed: $MUSL_FAILED"
echo "  Glibc Total: $GLIBC_TOTAL, Success: $GLIBC_SUCCESS, Failed: $GLIBC_FAILED"
echo "  Overall Total: $((MUSL_TOTAL + GLIBC_TOTAL))"
echo "  Overall Success: $((MUSL_SUCCESS + GLIBC_SUCCESS))"
echo "  Overall Failed: $((MUSL_FAILED + GLIBC_FAILED))"

# Exit with error if any failed
TOTAL_FAILED=$((MUSL_FAILED + GLIBC_FAILED))
if [ $TOTAL_FAILED -gt 0 ]; then
    echo
    log_error "$TOTAL_FAILED toolchain(s) failed to download"
    log_error "Docker build will fail to ensure all architectures work"
    exit 1
fi

echo
echo "All toolchains downloaded successfully!"