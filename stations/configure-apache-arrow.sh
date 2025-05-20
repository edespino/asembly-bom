#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : stations/configure-apache-arrow.sh
# Purpose  : Configure script for the Apache Arrow component using CMake.
# Inputs   :
#   - CONFIGURE_FLAGS: CMake flags passed from bom.yaml (mandatory)
#   - INSTALL_PREFIX: override default install path
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Load shared environment
# shellcheck disable=SC1091
[ -f config/env.sh ] && . config/env.sh

# Setup
NAME="apache-arrow"
INSTALL_PREFIX="${INSTALL_PREFIX:-$HOME/assembly-bom/stage/$NAME}"
BUILD_DIR="parts/$NAME/cpp/build"

# Helpers
section()         { echo "==> $1..."; }
section_complete(){ echo "✅ $1 complete (duration: $(($(date +%s) - $2))s)"; }
log()             { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

# Prepare build and install directories
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_PREFIX"
cd "$BUILD_DIR"

section "configure"
start_time=$(date +%s)

# Require CONFIGURE_FLAGS
if [[ -z "${CONFIGURE_FLAGS:-}" ]]; then
  echo "❌ Error: CONFIGURE_FLAGS must be provided externally (e.g., via bom.yaml)." >&2
  exit 1
fi

# Final CMake command
CMAKE_CMD="cmake .. $CONFIGURE_FLAGS"

log "Running cmake with:"
echo "  $CMAKE_CMD"
echo ""

# Run it
# shellcheck disable=SC2086
eval $CMAKE_CMD 2>&1 | tee "configure-$(date '+%Y%m%d-%H%M%S').log"

section_complete "configure" "$start_time"
