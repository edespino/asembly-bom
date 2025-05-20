#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : stations/configure-pgpool.sh
# Purpose  : Configure script for the pgpool component using Autotools.
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Load shared environment
# shellcheck disable=SC1091
[ -f config/env.sh ] && source config/env.sh

NAME="pgpool"
SRC_DIR="parts/$NAME"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLOUDBERRY_PREFIX="/usr/local/cloudberry"
CLOUDBERRY_PATH_SH="$CLOUDBERRY_PREFIX/greenplum_path.sh"
INSTALL_PREFIX="/usr/local/$NAME"

# Helpers
section()         { echo "==> $1..."; }
section_complete(){ echo "✅ $1 complete (duration: $(($(date +%s) - $2))s)"; }
log()             { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

section "configure $NAME"
start_time=$(date +%s)

cd "$SRC_DIR"

# Load PostgreSQL environment
if [[ -f "$CLOUDBERRY_PATH_SH" ]]; then
  source "$CLOUDBERRY_PATH_SH"
else
  echo "[configure-pgpool] ERROR: greenplum_path.sh not found at $CLOUDBERRY_PATH_SH" >&2
  exit 1
fi

# Ensure pg_config is available
if ! command -v pg_config >/dev/null; then
  echo "❌ Error: pg_config not found in PATH after sourcing environment." >&2
  exit 1
fi

# Run autoreconf to generate configure script
log "Running autoreconf -fi"
autoreconf -fi

# Define PostgreSQL paths
PG_INCLUDEDIR="$CLOUDBERRY_PREFIX/include"
PG_LIBDIR="$CLOUDBERRY_PREFIX/lib"
PG_BINDIR="$CLOUDBERRY_PREFIX/bin"

# Construct configure command
BUILD_TRIPLET=$(./config.guess)

# Construct configure command
CONFIGURE_CMD="./configure \
  --prefix=\"$INSTALL_PREFIX\" \
  --with-pgsql-includedir=\"$PG_INCLUDEDIR\" \
  --with-pgsql-libdir=\"$PG_LIBDIR\" \
  --with-pgsql-bindir=\"$PG_BINDIR\" \
  --build=\"$BUILD_TRIPLET\""

log "Running configure with:"
echo "  $CONFIGURE_CMD"
eval $CONFIGURE_CMD 2>&1 | tee "configure-$(date '+%Y%m%d-%H%M%S').log"
