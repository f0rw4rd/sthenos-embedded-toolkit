#!/bin/bash
set -euo pipefail

echo "Toolchain Downloader"
echo "============================"
echo "Build timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/core/architectures.sh"
source "$SCRIPT_DIR/lib/core/arch_helper.sh"
source "$SCRIPT_DIR/lib/build_helpers.sh"

MUSL_TOOLCHAIN_DIR="/build/toolchains"
GLIBC_TOOLCHAIN_DIR="/build/toolchains-glibc"
PARALLEL_JOBS=${TOOLCHAIN_PARALLEL_DOWNLOADS:-8}
BASE_URL_BOOTLIN="https://toolchains.bootlin.com/downloads/releases/toolchains"

mkdir -p "$MUSL_TOOLCHAIN_DIR" "$GLIBC_TOOLCHAIN_DIR"

verify_toolchain() {
    local target_dir=$1
    
    if [ ! -d "$target_dir" ]; then
        return 1
    fi
    
    if [ ! -d "$target_dir/bin" ]; then
        echo "  Warning: bin directory missing"
        return 1
    fi
    
    local gcc_count=$(ls "$target_dir/bin/"*-gcc 2>/dev/null | wc -l)
    if [ $gcc_count -eq 0 ]; then
        echo "  Warning: GCC compiler not found"
        return 1
    fi
    
    return 0
}

download_musl_toolchain() {
    local url=$1
    local target_dir=$2
    local expected_sha512=$3
    local filename=$(basename "$url")
    local max_retries=3
    local retry_count=0
    local download_success=false
    
    echo "Downloading musl $target_dir..."
    
    cd "$MUSL_TOOLCHAIN_DIR"
    
    if [ -d "$target_dir" ] && ! verify_toolchain "$target_dir"; then
        echo "  Removing corrupted toolchain..."
        rm -rf "$target_dir"
    fi
    
    if [ -d "$target_dir" ] && verify_toolchain "$target_dir"; then
        echo "SUCCESS: $target_dir (already exists and valid)"
        return 0
    fi
    
    
    if ! download_with_progress "$target_dir" "$url" "$filename" "$expected_sha512" "$max_retries" "30"; then
        download_success=false
    else
        download_success=true
    fi
    
    if [ "$download_success" = false ]; then
        log_error "ERROR: Failed to download $target_dir after $max_retries attempts"
        return 1
    fi
    
    local file_size=$(ls -lh "$filename" | awk '{print $5}')
    echo "  Extracting $filename ($file_size)..."
    if tar xzf "$filename"; then
        rm -f "$filename"
        
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

download_glibc_toolchain() {
    local arch="$1"
    
    local custom_glibc_url=$(get_arch_field "$arch" "custom_glibc_url" 2>/dev/null)
    local bootlin_url=$(get_bootlin_url "$arch" 2>/dev/null)
    
    local url=""
    local expected_sha512=""
    
    if [ -n "$custom_glibc_url" ]; then
        url="$custom_glibc_url"
        expected_sha512=$(get_arch_field "$arch" "custom_glibc_sha512" 2>/dev/null)
    elif [ -n "$bootlin_url" ]; then
        url="$BASE_URL_BOOTLIN/$bootlin_url"
        expected_sha512=$(get_arch_field "$arch" "bootlin_sha512" 2>/dev/null)
    else
        log "Skipping $arch - no glibc URL defined"
        return 0
    fi
    
    local glibc_name=$(get_glibc_toolchain "$arch" 2>/dev/null)
    if [ -z "$glibc_name" ]; then
        log_error "No glibc toolchain name for $arch"
        return 1
    fi
    
    local target_dir="$GLIBC_TOOLCHAIN_DIR/$glibc_name"
    
    if [ -d "$target_dir" ] && [ -d "$target_dir/bin" ]; then
        log "$arch toolchain already exists"
        return 0
    fi
    
    log "Downloading $arch toolchain..."
    log "  URL: $url"
    log "  Target: $target_dir"
    
    local temp_dir="/tmp/toolchain-${arch}-$$-$(date +%s%N)"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    trap "cleanup_build_dir '$temp_dir'" EXIT
    
    local filename=$(basename "$url")
    local max_retries=3
    local retry_count=0
    
    if ! download_with_progress "$arch" "$url" "$filename" "$expected_sha512" "$max_retries" "60"; then
        cleanup_build_dir "$temp_dir"
        return 1
    fi
    
    local file_size=$(ls -lh "$filename" | awk '{print $5}')
    log "  Extracting $filename ($file_size)..."
    if ! tar xf "$filename"; then
        log_error "Failed to extract $arch toolchain"
        return 1
    fi
    
    local extracted_dir=$(find . -maxdepth 1 -type d -name "*" | grep -v "^\.$" | head -1)
    if [ -z "$extracted_dir" ]; then
        log_error "No directory found after extraction for $arch"
        return 1
    fi
    
    mkdir -p "$(dirname "$target_dir")"
    mv "$extracted_dir" "$target_dir"
    
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

generate_musl_toolchains() {
    local toolchains=()
    
    for arch in "${ALL_ARCHITECTURES[@]}"; do
        local musl_name=$(get_musl_toolchain "$arch" 2>/dev/null)
        
        if [ -z "$musl_name" ]; then
            continue
        fi
        
        local custom_url=$(get_arch_field "$arch" "custom_musl_url" 2>/dev/null)
        if [ -n "$custom_url" ]; then
            local filename=$(basename "$custom_url")
            local target_dir="${musl_name%-cross}"
            if [[ "$target_dir" == "$musl_name" ]]; then
                target_dir="$musl_name-cross"
            fi
            local custom_sha512=$(get_arch_field "$arch" "custom_musl_sha512" 2>/dev/null)
            toolchains+=("$custom_url $target_dir $custom_sha512")
        else
            local url="https://musl.cc/${musl_name}-cross.tgz"
            local target_dir="${musl_name}-cross"
            local musl_sha512=$(get_arch_field "$arch" "musl_sha512" 2>/dev/null)
            toolchains+=("$url $target_dir $musl_sha512")
        fi
    done
    
    printf '%s\n' "${toolchains[@]}" | sort -u
}

readarray -t MUSL_TOOLCHAINS < <(generate_musl_toolchains)

echo "PHASE 1: Downloading ${#MUSL_TOOLCHAINS[@]} musl toolchains"
echo

declare -A MUSL_RESULTS
MUSL_JOB_DIR="/tmp/musl-toolchain-jobs-$$"
mkdir -p "$MUSL_JOB_DIR"

download_musl_with_tracking() {
    local line="$1"
    local url=$(echo "$line" | cut -d' ' -f1)
    local target_dir=$(echo "$line" | cut -d' ' -f2)
    local expected_sha512=$(echo "$line" | cut -d' ' -f3)
    local job_file="$MUSL_JOB_DIR/$target_dir"
    
    if download_musl_toolchain "$url" "$target_dir" "$expected_sha512"; then
        echo "success" > "$job_file"
    else
        echo "failed" > "$job_file"
    fi
}

export -f download_musl_with_tracking
export MUSL_JOB_DIR

if command -v parallel >/dev/null 2>&1; then
    printf '%s\n' "${MUSL_TOOLCHAINS[@]}" | parallel -j $PARALLEL_JOBS download_musl_with_tracking {}
else
    printf '%s\n' "${MUSL_TOOLCHAINS[@]}" | xargs -P $PARALLEL_JOBS -I {} bash -c 'download_musl_with_tracking "$@"' _ {}
fi

echo
echo "Waiting for musl downloads to complete..."
wait

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

cd "$MUSL_TOOLCHAIN_DIR"
declare -A toolchain_map
declare -A reverse_map

for arch in "${ALL_ARCHITECTURES[@]}"; do
    local musl_name=$(get_musl_toolchain "$arch" 2>/dev/null)
    if [ -n "$musl_name" ]; then
        local target_dir="${musl_name}-cross"
        toolchain_map["$arch"]="$target_dir"
        if [ -z "${reverse_map[$target_dir]}" ]; then
            reverse_map["$target_dir"]="$arch"
        else
            reverse_map["$target_dir"]="${reverse_map[$target_dir]} $arch"
        fi
    fi
done

for target_dir in "${!reverse_map[@]}"; do
    archs=(${reverse_map[$target_dir]})
    if [ ${#archs[@]} -gt 1 ] && [ -d "$target_dir" ]; then
        primary_arch=""
        for arch in "${archs[@]}"; do
            if [[ "$target_dir" == *"$arch"* ]]; then
                primary_arch="$arch"
                break
            fi
        done
        
        for arch in "${archs[@]}"; do
            if [ "$arch" != "$primary_arch" ] && [ ! -d "$arch" ]; then
                ln -sf "$target_dir" "$arch"
                echo "SUCCESS: $arch (symlinked to $target_dir)"
                MUSL_RESULTS["$arch"]="OK"
                MUSL_SUCCESS=$((MUSL_SUCCESS + 1))
            fi
        done
    fi
done

echo
echo "PHASE 2: Downloading glibc toolchains"
echo

GLIBC_ARCHS=()
for arch in "${ALL_ARCHITECTURES[@]}"; do
    if arch_supports_glibc "$arch"; then
        GLIBC_ARCHS+=("$arch")
    fi
done

echo "Found ${#GLIBC_ARCHS[@]} architectures with glibc support"
echo "Starting glibc downloads with $PARALLEL_JOBS parallel jobs..."
echo

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

for arch in "${GLIBC_ARCHS[@]}"; do
    while [ $(jobs -r | wc -l) -ge $PARALLEL_JOBS ]; do
        sleep 0.1
    done
    
    download_glibc_with_tracking "$arch" &
done

echo "Waiting for glibc downloads to complete..."
wait

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

TOTAL_FAILED=$((MUSL_FAILED + GLIBC_FAILED))
if [ $TOTAL_FAILED -gt 0 ]; then
    echo
    log_error "$TOTAL_FAILED toolchain(s) failed to download"
    log_error "Docker build will fail to ensure all architectures work"
    exit 1
fi

echo
echo "All toolchains downloaded successfully!"
