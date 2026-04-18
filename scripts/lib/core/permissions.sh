#!/bin/bash

readonly BUILD_UID="1000"
readonly BUILD_GID="1000"

readonly EXEC_PERMS="755"
readonly LIB_PERMS="644"
readonly CONFIG_PERMS="644"
readonly LOG_PERMS="644"
readonly DIR_PERMS="755"

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
    
    if [ "$EUID" -eq 0 ]; then
        chown "1000:1000" "$file" 2>/dev/null || true
    fi
}

set_dir_permissions() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        return 0
    fi
    
    chmod "$DIR_PERMS" "$dir" 2>/dev/null || true
    
    if [ "$EUID" -eq 0 ]; then
        chown -R "1000:1000" "$dir" 2>/dev/null || true
    fi
}

fix_directory_permissions() {
    local dir="$1"
    local file_type="${2:-exec}"  # Type of files in directory
    
    if [ ! -d "$dir" ]; then
        return 0
    fi
    
    set_dir_permissions "$dir"
    
    find "$dir" -type f | while read -r file; do
        set_output_ownership "$file" "$file_type"
    done
    
    find "$dir" -type d | while read -r subdir; do
        chmod "$DIR_PERMS" "$subdir" 2>/dev/null || true
        if [ "$EUID" -eq 0 ]; then
            chown "1000:1000" "$subdir" 2>/dev/null || true
        fi
    done
}

create_output_dir() {
    local dir="$1"
    
    mkdir -p "$dir"
    set_dir_permissions "$dir"
}

strip_and_fix_binary() {
    local binary="$1"
    local strip_cmd="${2:-strip}"
    
    if [ -f "$binary" ]; then
        if command -v "$strip_cmd" >/dev/null 2>&1; then
            "$strip_cmd" "$binary" 2>/dev/null || true
        fi
        
        set_output_ownership "$binary" "exec"
    fi
}

copy_with_permissions() {
    local src="$1"
    local dst="$2"
    local type="${3:-exec}"
    
    cp -f "$src" "$dst"
    set_output_ownership "$dst" "$type"
}

move_with_permissions() {
    local src="$1"
    local dst="$2"
    local type="${3:-exec}"
    
    mv -f "$src" "$dst"
    set_output_ownership "$dst" "$type"
}

export -f set_output_ownership
export -f set_dir_permissions
export -f fix_directory_permissions
export -f create_output_dir
export -f strip_and_fix_binary
export -f copy_with_permissions
export -f move_with_permissions

export BUILD_UID BUILD_GID
export EXEC_PERMS LIB_PERMS CONFIG_PERMS LOG_PERMS DIR_PERMS
