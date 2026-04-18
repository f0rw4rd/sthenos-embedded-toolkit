#!/bin/bash
# busybox_nodrop: Delegates to build-busybox.sh with "nodrop" variant
# This avoids duplicating busybox build logic. See build-busybox.sh for details.
# SUPPORTED_OS="linux,android" inherited from build-busybox.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/build-busybox.sh" "$1" "nodrop"
