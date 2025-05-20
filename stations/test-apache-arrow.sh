#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : stations/test-apache-arrow.sh
# Purpose  : Run Apache Arrow tests, excluding arrow-ipc-read-write-test.
# Inputs   :
#   - NAME : component name (default: apache-arrow)
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Load shared environment
# shellcheck disable=SC1091
[ -f config/env.sh ] && . config/env.sh

NAME="${NAME:-apache-arrow}"
BUILD_DIR="parts/$NAME/cpp/build"

# Logging helpers
section()         { echo "==> $1..."; }
section_complete(){ echo "✅ $1 complete (duration: $(($(date +%s) - $2))s)"; }
log()             { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

section "test"
start_time=$(date +%s)

# Validate build directory
if [[ ! -d "$BUILD_DIR" ]]; then
  echo "[test] ERROR: Build directory '$BUILD_DIR' not found."
  exit 1
fi

cd "$BUILD_DIR"

log "Running tests with ctest (excluding arrow-ipc-read-write-test)"
ctest --output-on-failure -E arrow-ipc-read-write-test | tee "ctest-results-$(date '+%Y.%m.%d-%H.%M.%S').log"

section_complete "test" "$start_time"
