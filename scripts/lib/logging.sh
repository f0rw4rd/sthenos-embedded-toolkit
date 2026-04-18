#!/bin/bash

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
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
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $*" >&2
    fi
}

log_tool() {
    local tool=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$tool] $*" >&2
}

log_tool_error() {
    local tool=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$tool] ERROR: $*" >&2
}

log_tool_warn() {
    local tool=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$tool] WARN: $*" >&2
}
