#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : assemble.sh
# Purpose  : Safe, explicit orchestrator for Assembly BOM
# Features :
#   - Requires --run to execute build steps
#   - Use --list to inspect components
#   - Combine with --component/-c and --steps/-s
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment and bootstrap tools
# shellcheck disable=SC1091
[ -f config/env.sh ] && source config/env.sh
# shellcheck disable=SC1091
[ -f config/bootstrap.sh ] && source config/bootstrap.sh

# Require yq
if ! command -v yq >/dev/null 2>&1; then
  echo "[assemble] ERROR: 'yq' is required but not installed."
  exit 1
fi

# --- If no arguments, behave as --help ---
if [[ "$#" -eq 0 ]]; then
  set -- --help
fi

# --- CLI Parsing ---
OPTIONS=c:s:hlr
LONGOPTS=component:,steps:,help,list,run
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
eval set -- "$PARSED"

ONLY_COMPONENT=""
STEP_OVERRIDE=""
DO_LIST=false
DO_RUN=false

while true; do
  case "$1" in
    -c|--component) ONLY_COMPONENT="$2"; shift 2 ;;
    -s|--steps) STEP_OVERRIDE="$2"; shift 2 ;;
    -l|--list) DO_LIST=true; shift ;;
    -r|--run) DO_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--run] [--list] [-c <name>] [-s <steps>]"
      echo ""
      echo "  --run                Run BOM steps (must be explicitly provided)"
      echo "  --list               List all components by layer"
      echo "  -c, --component      Target a specific component (optional)"
      echo "  -s, --steps          Override steps (comma-separated)"
      echo "  -h, --help           Show this help message"
      exit 0
      ;;
    --) shift; break ;;
    *) echo "[assemble] Unknown option: $1"; exit 1 ;;
  esac
done

PRODUCT=$(yq e '.products | keys | .[0]' bom.yaml)

# --- List Components ---
if [[ "$DO_LIST" == true ]]; then
  echo "[assemble] Components in bom.yaml:"
  for LAYER in core extensions dependency; do
    COUNT=$(yq e ".products.${PRODUCT}.components.${LAYER} | length" bom.yaml 2>/dev/null || echo 0)
    if [[ "$COUNT" -eq 0 ]]; then continue; fi
    echo ""
    echo "$LAYER:"
    for ((i = 0; i < COUNT; i++)); do
      NAME=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].name" bom.yaml)
      echo "  - $NAME"
    done
  done
  exit 0
fi

# --- Require --run ---
if [[ "$DO_RUN" != true ]]; then
  echo "[assemble] No action taken. Use --run to execute, or --list to inspect."
  echo "Try: $0 --run --component cloudberry --steps build,test"
  exit 0
fi

# --- Run BOM Workflow ---
echo "[assemble] Building product: $PRODUCT"

for LAYER in core extensions dependency; do
  COUNT=$(yq e ".products.${PRODUCT}.components.${LAYER} | length" bom.yaml 2>/dev/null || echo 0)
  if [[ "$COUNT" -eq 0 ]]; then continue; fi

  echo "[assemble] Processing $LAYER components..."

  for ((i = 0; i < COUNT; i++)); do
    NAME=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].name" bom.yaml)

    if [[ -n "$ONLY_COMPONENT" && "$NAME" != "$ONLY_COMPONENT" ]]; then continue; fi

    URL=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].url" bom.yaml)
    BRANCH=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].branch" bom.yaml)
    CONFIGURE_FLAGS=$(yq e -o=props ".products.${PRODUCT}.components.${LAYER}[$i].configure_flags" bom.yaml)

    if [[ -n "$STEP_OVERRIDE" ]]; then
      IFS=',' read -ra STEPS <<< "$STEP_OVERRIDE"
    else
      mapfile -t STEPS < <(yq e ".products.${PRODUCT}.components.${LAYER}[$i].steps[]" bom.yaml)
    fi

    echo "[assemble] Component: $NAME"
    export NAME URL BRANCH CONFIGURE_FLAGS
    export INSTALL_PREFIX="/usr/local/$NAME"

    ENV_KEYS=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].env | keys | .[]" bom.yaml 2>/dev/null || true)
    for KEY in $ENV_KEYS; do
      VALUE=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].env.$KEY" bom.yaml)
      export "$KEY"="$VALUE"
      echo "[assemble]     ENV: $KEY=$VALUE"
    done

    for STEP in "${STEPS[@]}"; do
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
