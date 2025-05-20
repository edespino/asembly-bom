#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : stations/configure-cloudberry.sh
# Purpose  : Specialized configure script for the 'cloudberry' core component.
# Inputs   :
#   - CONFIGURE_FLAGS: passed from bom.yaml
#   - DEBUG_EXTENSIONS=1: enables debug build flags
#   - INSTALL_PREFIX: optional override (defaults to /usr/local/cloudberry)
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Load shared environment
# shellcheck disable=SC1091
[ -f config/env.sh ] && . config/env.sh

# Setup
NAME="cloudberry"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local/cloudberry}"
DEBUG_EXTENSIONS="${DEBUG_EXTENSIONS:-0}"
BUILD_DIR="parts/${NAME}"

# Helpers
section()         { echo "==> $1..."; }
section_complete(){ echo "✅ $1 complete (duration: $(($(date +%s) - $2))s)"; }
log()             { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

# Validate environment
if [[ ! -d "$BUILD_DIR" ]]; then
  echo "[configure] ERROR: Build directory '$BUILD_DIR' does not exist"
  exit 1
fi

cd "$BUILD_DIR"

section "configure"
start_time=$(date +%s)

# Debug flags
if [[ "$DEBUG_EXTENSIONS" == "1" ]]; then
  CONFIGURE_DEBUG_OPTS="--enable-debug --enable-cassert --enable-debug-extensions"
else
  CONFIGURE_DEBUG_OPTS=""
fi

# Optional Xerces-C setup
if [[ -d /opt/xerces-c ]]; then
  log "Using Xerces-C from /opt/xerces-c"
  sudo chmod a+w /usr/local

  mkdir -p "${INSTALL_PREFIX}/lib"
  cp -P /opt/xerces-c/lib/libxerces-c.so \
        /opt/xerces-c/lib/libxerces-c-3.*.so \
        "${INSTALL_PREFIX}/lib" 2>/dev/null || true

  export LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
  xerces_include="--with-includes=/opt/xerces-c/include"
  xerces_libs="--with-libraries=${INSTALL_PREFIX}/lib"
else
  log "Using system-installed Xerces-C"
  xerces_include=""
  xerces_libs=""
fi

# Final configure command
CONFIGURE_CMD="./configure --prefix=${INSTALL_PREFIX} \
  ${CONFIGURE_FLAGS:-} \
  ${CONFIGURE_DEBUG_OPTS} \
  ${xerces_include} \
  ${xerces_libs}"

log "Running configure with:"
echo "  $CONFIGURE_CMD"
echo ""

# Run it
# shellcheck disable=SC2086
eval $CONFIGURE_CMD 2>&1 | tee "configure-$(date '+%Y%m%d-%H%M%S').log"

section_complete "configure" "$start_time"
