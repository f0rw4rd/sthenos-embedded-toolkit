#!/bin/bash
# File permissions and ownership management

# FIXED: All files always owned by 1000:1000
readonly BUILD_UID="1000"
readonly BUILD_GID="1000"

# Standard permissions for different file types
readonly EXEC_PERMS="755"
readonly LIB_PERMS="644"
readonly CONFIG_PERMS="644"
readonly LOG_PERMS="644"
readonly DIR_PERMS="755"

# Ensure correct ownership for output files
set_output_ownership() {
    local file="$1"
    local type="${2:-exec}"  # exec, lib, config, log
    
    if [ ! -e "$file" ]; then
        return 0
    fi
    
    case "$type" in
        exec)
            chmod "$EXEC_PERMS" "$file" 2>/dev/null || true
            ;;
        lib)
            chmod "$LIB_PERMS" "$file" 2>/dev/null || true
            ;;
        config|log)
            chmod "$CONFIG_PERMS" "$file" 2>/dev/null || true
            ;;
    esac
    
    # Always set ownership to 1000:1000 if running as root
    if [ "$EUID" -eq 0 ]; then
        chown "1000:1000" "$file" 2>/dev/null || true
    fi
}

# Ensure directory permissions
set_dir_permissions() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        return 0
    fi
    
    chmod "$DIR_PERMS" "$dir" 2>/dev/null || true
    
    # Always set ownership to 1000:1000 if running as root
    if [ "$EUID" -eq 0 ]; then
        chown -R "1000:1000" "$dir" 2>/dev/null || true
    fi
}

# Fix permissions for all files in a directory
fix_directory_permissions() {
    local dir="$1"
    local file_type="${2:-exec}"  # Type of files in directory
    
    if [ ! -d "$dir" ]; then
        return 0
    fi
    
    # Fix directory itself
    set_dir_permissions "$dir"
    
    # Fix all files in directory
    find "$dir" -type f | while read -r file; do
        set_output_ownership "$file" "$file_type"
    done
    
    # Fix all subdirectories
    find "$dir" -type d | while read -r subdir; do
        chmod "$DIR_PERMS" "$subdir" 2>/dev/null || true
        if [ "$EUID" -eq 0 ]; then
            chown "1000:1000" "$subdir" 2>/dev/null || true
        fi
    done
}

# Create directory with correct permissions
create_output_dir() {
    local dir="$1"
    
    mkdir -p "$dir"
    set_dir_permissions "$dir"
}

# Strip binary and fix permissions
strip_and_fix_binary() {
    local binary="$1"
    local strip_cmd="${2:-strip}"
    
    if [ -f "$binary" ]; then
        # Strip if strip command exists
        if command -v "$strip_cmd" >/dev/null 2>&1; then
            "$strip_cmd" "$binary" 2>/dev/null || true
        fi
        
        # Fix permissions
        set_output_ownership "$binary" "exec"
    fi
}

# Copy file with correct permissions
copy_with_permissions() {
    local src="$1"
    local dst="$2"
    local type="${3:-exec}"
    
    cp -f "$src" "$dst"
    set_output_ownership "$dst" "$type"
}

# Move file with correct permissions
move_with_permissions() {
    local src="$1"
    local dst="$2"
    local type="${3:-exec}"
    
    mv -f "$src" "$dst"
    set_output_ownership "$dst" "$type"
}

# Export functions for use in other scripts
export -f set_output_ownership
export -f set_dir_permissions
export -f fix_directory_permissions
export -f create_output_dir
export -f strip_and_fix_binary
export -f copy_with_permissions
export -f move_with_permissions

# Export constants
export BUILD_UID BUILD_GID
export EXEC_PERMS LIB_PERMS CONFIG_PERMS LOG_PERMS DIR_PERMS