#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : stations/build-install-pgpool.sh
# Purpose  : Build and install the pgpool component using Autotools.
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Load shared environment
# shellcheck disable=SC1091
[ -f config/env.sh ] && source config/env.sh

NAME="pgpool"
SRC_DIR="parts/$NAME"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Helpers
section()         { echo "==> $1..."; }
section_complete(){ echo "✅ $1 complete (duration: $(($(date +%s) - $2))s)"; }
log()             { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

cd "$SRC_DIR"

# Build step
section "build $NAME"
start_time=$(date +%s)
make 2>&1 | tee "build-$(date '+%Y%m%d-%H%M%S').log"
section_complete "build $NAME" "$start_time"

# Install step
section "install $NAME"
start_time=$(date +%s)
make install 2>&1 | tee "install-$(date '+%Y%m%d-%H%M%S').log"
section_complete "install $NAME" "$start_time"

# Version check
section "verify $NAME version"
BIN_PATH="/usr/local/$NAME/bin/pgpool"
if [[ -x "$BIN_PATH" ]]; then
  "$BIN_PATH" --version
else
  echo "❌ pgpool binary not found at $BIN_PATH" >&2
  exit 1
fi
