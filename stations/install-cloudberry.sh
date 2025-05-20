#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : stations/install-cloudberry.sh
# Purpose  : Specialized install script for the 'cloudberry' core component.
# Inputs   :
#   - NAME            : component name (default: cloudberry)
#   - INSTALL_PREFIX  : optional (defaults to /usr/local)
#   - GP_ENV_PATH     : optional (if set, used for final `postgres` check)
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# shellcheck disable=SC1091
[ -f config/env.sh ] && . config/env.sh

NAME="${NAME:-cloudberry}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local/$NAME}"
BUILD_DIR="parts/$NAME"
GP_ENV_PATH="${GP_ENV_PATH:-$INSTALL_PREFIX/greenplum_path.sh}"

section()         { echo "==> $1..."; }
section_complete(){ echo "✅ $1 complete (duration: $(($(date +%s) - $2))s)"; }
log()             { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

section "install"
start_time=$(date +%s)

# Ensure source tree exists
if [[ ! -d "$BUILD_DIR" ]]; then
  echo "[install] ERROR: Build directory '$BUILD_DIR' not found"
  exit 1
fi

cd "$BUILD_DIR"

# Adjust permissions on prefix
sudo chmod a+w "$INSTALL_PREFIX"

# Set LD_LIBRARY_PATH if needed
if [[ -d /opt/xerces-c ]]; then
  export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:${LD_LIBRARY_PATH:-}"
fi

# Core install
install_cmd=(make -j"$(nproc)" install --directory=".")
log "Running core install:"
printf '  %s\n' "${install_cmd[@]}"
"${install_cmd[@]}" | tee "make-install-$(date '+%Y.%m.%d-%H.%M.%S').log"

# Contrib install
if [[ -d "contrib" ]]; then
  contrib_cmd=(make -j"$(nproc)" install --directory="contrib")
  log "Installing contrib:"
  printf '  %s\n' "${contrib_cmd[@]}"
  "${contrib_cmd[@]}" | tee "make-contrib-install-$(date '+%Y.%m.%d-%H.%M.%S').log"
else
  log "Skipping contrib install — directory not found."
fi

# Build pygresql
if [[ -d "gpMgmt/bin" ]]; then
  pygresql_build_cmd=(make pygresql --directory="gpMgmt/bin")
  log "Building pygresql:"
  printf '  %s\n' "${pygresql_build_cmd[@]}"
  "${pygresql_build_cmd[@]}" | tee "make-pygresql-$(date '+%Y.%m.%d-%H.%M.%S').log"
else
  log "Skipping pygresql build — gpMgmt/bin not found."
fi

# Install gpMgmt
if [[ -d "gpMgmt" ]]; then
  pygresql_install_cmd=(make -j"$(nproc)" install --directory="gpMgmt")
  log "Installing gpMgmt:"
  printf '  %s\n' "${pygresql_install_cmd[@]}"
  "${pygresql_install_cmd[@]}" | tee "make-pygresql-install-$(date '+%Y.%m.%d-%H.%M.%S').log"
else
  log "Skipping gpMgmt install — gpMgmt/ not found."
fi

# Post-install check
if [[ -f "$GP_ENV_PATH" ]]; then
  # shellcheck disable=SC1090
  source "$GP_ENV_PATH"
  postgres --version
  postgres --gp-version
else
  log "Warning: $GP_ENV_PATH not found."
  exit 1
fi

section_complete "install" "$start_time"
