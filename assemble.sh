#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : assemble.sh
# Purpose  : Lightweight orchestrator for Assembly BOM.
# Notes    :
#   - Supports 'core' and 'extensions' layers
#   - Supports component-specific station scripts: step-name.sh
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Resolve location of this script so we can run it from anywhere
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment and bootstrap tools
# shellcheck disable=SC1091
[ -f config/env.sh ] && source config/env.sh
# shellcheck disable=SC1091
[ -f config/bootstrap.sh ] && source config/bootstrap.sh

# Optional component name filter
ONLY_COMPONENT="${1:-}"

# Require yq
if ! command -v yq >/dev/null 2>&1; then
  echo "[assemble] ERROR: 'yq' is required but not installed."
  exit 1
fi

# Get the first product key from bom.yaml
PRODUCT=$(yq e '.products | keys | .[0]' bom.yaml)
echo "[assemble] Building product: $PRODUCT"

for LAYER in core extensions dependency; do
  COUNT=$(yq e ".products.${PRODUCT}.components.${LAYER} | length" bom.yaml)

  if [[ "$COUNT" -eq 0 ]]; then
    continue
  fi

  echo "[assemble] Processing $LAYER components..."

  for ((i = 0; i < COUNT; i++)); do
    NAME=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].name" bom.yaml)

    # Skip if filtering by component name
    if [[ -n "$ONLY_COMPONENT" && "$NAME" != "$ONLY_COMPONENT" ]]; then
      continue
    fi

    URL=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].url" bom.yaml)
    BRANCH=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].branch" bom.yaml)
    CONFIGURE_FLAGS=$(yq e -o=props ".products.${PRODUCT}.components.${LAYER}[$i].configure_flags" bom.yaml)
    STEPS=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].steps[]" bom.yaml)

    echo "[assemble] Component: $NAME"
    export NAME URL BRANCH CONFIGURE_FLAGS
    export INSTALL_PREFIX="/usr/local/$NAME"

    # Load optional env block if present
    ENV_KEYS=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].env | keys | .[]" bom.yaml 2>/dev/null || true)
    for KEY in $ENV_KEYS; do
      VALUE=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].env.$KEY" bom.yaml)
      export "$KEY"="$VALUE"
      echo "[assemble]     ENV: $KEY=$VALUE"
    done

    for STEP in $STEPS; do
      SCRIPT="stations/${STEP}-${NAME}.sh"
      FALLBACK="stations/${STEP}.sh"

      echo "[assemble] --> Step: $STEP"

      if [[ -x "$SCRIPT" ]]; then
        echo "[assemble]     Using component-specific script: $SCRIPT"
        "$SCRIPT" "$NAME" "$URL" "$BRANCH"
      elif [[ -x "$FALLBACK" ]]; then
        echo "[assemble]     Using shared script: $FALLBACK"
        if [[ "$STEP" == "clone" ]]; then
          "$FALLBACK" "$NAME" "$URL" "$BRANCH"
        else
          "$FALLBACK"
        fi
      else
        echo "[assemble]     ❌ No script found for step '$STEP'"
        exit 1
      fi
    done
  done
done

echo "✅ Assembly complete."
