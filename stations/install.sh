#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : stations/install.sh
# Purpose  : Default install script for components using `make install`.
# Inputs   :
#   - NAME : component name (required)
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Load shared environment
# shellcheck disable=SC1091
[ -f config/env.sh ] && . config/env.sh

# Required input
NAME="${NAME:?Component name (NAME) must be provided}"
BUILD_DIR="parts/$NAME"

# Logging helpers
section()         { echo "==> $1..."; }
section_complete(){ echo "✅ $1 complete (duration: $(($(date +%s) - $2))s)"; }
log()             { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

section "install"
start_time=$(date +%s)

# Validate build directory
if [[ ! -d "$BUILD_DIR" ]]; then
  echo "[install] ERROR: Build directory '$BUILD_DIR' not found."
  exit 1
fi

cd "$BUILD_DIR"

log "Component:       $NAME"
log "Build directory: $BUILD_DIR"
echo ""

# Perform install
install_cmd=(make -j"$(nproc)" install)
log "Running install command:"
printf '  %s\n' "${install_cmd[@]}"
"${install_cmd[@]}" | tee "make-install-$(date '+%Y.%m.%d-%H.%M.%S').log"

section_complete "install" "$start_time"
