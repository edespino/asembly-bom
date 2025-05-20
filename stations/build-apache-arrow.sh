#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : stations/build-apache-arrow.sh
# Purpose  : Specialized build script for the 'apache-arrow' dependency.
# Inputs   :
#   - INSTALL_PREFIX : optional override (defaults to $HOME/assembly-bom/stage/apache-arrow)
#   - NAME           : component name (default: apache-arrow)
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# shellcheck disable=SC1091
[ -f config/env.sh ] && . config/env.sh

NAME="${NAME:-apache-arrow}"
INSTALL_PREFIX="${INSTALL_PREFIX:-$HOME/assembly-bom/stage/$NAME}"
BUILD_DIR="parts/$NAME/cpp/build"

section()         { echo "==> $1..."; }
section_complete(){ echo "✅ $1 complete (duration: $(($(date +%s) - $2))s)"; }
log()             { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

section "build"
start_time=$(date +%s)

# Verify build directory exists
if [[ ! -d "$BUILD_DIR" ]]; then
  echo "[build] ERROR: Build directory '$BUILD_DIR' not found."
  echo "[build] Did you skip the 'configure' step or forget to clone?"
  exit 1
fi

cd "$BUILD_DIR"

# Fiddle 1: symlink mimalloc static library
mkdir -p mimalloc_ep/src/mimalloc_ep/lib/mimalloc-2.0
ln -sf ../../../../../mimalloc_ep-prefix/src/mimalloc_ep-build/libmimalloc.a \
  mimalloc_ep/src/mimalloc_ep/lib/mimalloc-2.0/libmimalloc.a

# Fiddle 2: Remove START_PLAN_NODE_SPAN macro invocations
find ../src/arrow/compute/exec -type f \( -name '*.cc' -o -name '*.h' \) \
  | xargs sed -i '/START_PLAN_NODE_SPAN/d'

# Build core
build_cmd=(make -j"$(nproc)" --directory=".")
log "Running core build:"
printf '  %s\n' "${build_cmd[@]}"
"${build_cmd[@]}" | tee "make-$(date '+%Y.%m.%d-%H.%M.%S').log"

section_complete "build" "$start_time"
