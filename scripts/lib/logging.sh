#!/bin/bash

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*" >&2
}

log_info() {
    log "$@"
}

log_debug() {
    if [ -n "${DEBUG:-}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $*"
    fi
}

log_tool() {
    local tool=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$tool] $*"
}

log_tool_error() {
    local tool=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$tool] ERROR: $*" >&2
}