#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : assemble.sh
# Purpose  : Safe, explicit orchestrator for Assembly BOM
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/assemble-$(date '+%Y%m%d-%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Load environment and bootstrap tools
# shellcheck disable=SC1091
[ -f config/env.sh ] && source config/env.sh
# shellcheck disable=SC1091
[ -f config/bootstrap.sh ] && source config/bootstrap.sh

# Format duration in days, hours, minutes, and seconds
format_duration() {
  local total_seconds=$1
  local days=$((total_seconds / 86400))
  local hours=$(( (total_seconds % 86400) / 3600 ))
  local minutes=$(( (total_seconds % 3600) / 60 ))
  local seconds=$((total_seconds % 60))

  local result=""
  if (( days > 0 )); then result+="${days}d "; fi
  if (( hours > 0 || days > 0 )); then result+="${hours}h "; fi
  if (( minutes > 0 || hours > 0 || days > 0 )); then result+="${minutes}m "; fi
  result+="${seconds}s"

  echo "$result"
}

if [[ "$#" -eq 0 ]]; then
  set -- --help
fi

OPTIONS=c:s:hlrd
LONGOPTS=component:,steps:,help,list,run,dry-run
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
eval set -- "$PARSED"

ONLY_COMPONENTS=()
STEP_OVERRIDE=""
DO_LIST=false
DO_RUN=false
DO_DRY_RUN=false

while true; do
  case "$1" in
    -c|--component)
      IFS=',' read -ra ONLY_COMPONENTS <<< "$2"
      shift 2
      ;;
    -s|--steps) STEP_OVERRIDE="$2"; shift 2 ;;
    -l|--list) DO_LIST=true; shift ;;
    -r|--run) DO_RUN=true; shift ;;
    -d|--dry-run) DO_DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--run] [--list] [--dry-run] [-c <names>] [-s <steps>]"
      echo ""
      echo "  -r, --run            Run BOM steps (must be explicitly provided)"
      echo "  -l, --list           List all components by layer"
      echo "  -c, --component      Target one or more components by name (comma-separated)"
      echo "  -s, --steps          Override steps (comma-separated)"
      echo "  -d, --dry-run        Show build order only"
      echo "  -h, --help           Show this help message"
      exit 0
      ;;
    --) shift; break ;;
    *) echo "[assemble] Unknown option: $1"; exit 1 ;;
  esac
done

PRODUCT=$(yq e '.products | keys | .[0]' bom.yaml)

if [[ "$DO_LIST" == true ]]; then
  echo "[assemble] Components in bom.yaml:"
  for LAYER in dependencies core extensions components; do
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

if [[ "$DO_DRY_RUN" == true ]]; then
  echo "[assemble] Dry run: Build order based on layer ordering (dependencies → core → extensions → components)"
  for LAYER in dependencies core extensions components; do
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

if [[ "$DO_RUN" != true ]]; then
  echo "[assemble] No action taken. Use --run to execute, or --list to inspect."
  echo "Try: $0 --run --component cloudberry --steps build,test"
  exit 0
fi

echo "[assemble] Building product: $PRODUCT"
START_TIME=$(date +%s)
SUMMARY_LINES=()

for LAYER in dependencies core extensions components; do
  COUNT=$(yq e ".products.${PRODUCT}.components.${LAYER} | length" bom.yaml 2>/dev/null || echo 0)
  if [[ "$COUNT" -eq 0 ]]; then continue; fi

  echo "[assemble] Processing $LAYER components..."

  for ((i = 0; i < COUNT; i++)); do
    NAME=$(yq e ".products.${PRODUCT}.components.${LAYER}[$i].name" bom.yaml)

    if (( ${#ONLY_COMPONENTS[@]} > 0 )); then
      skip=true
      for COMP in "${ONLY_COMPONENTS[@]}"; do
        if [[ "$NAME" == "$COMP" ]]; then
          skip=false
          break
        fi
      done
      $skip && continue
    fi

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

    STEP_TIMINGS=()
    COMPONENT_START=$(date +%s)

    for STEP in "${STEPS[@]}"; do
      SCRIPT="stations/${STEP}-${NAME}.sh"
      FALLBACK="stations/${STEP}.sh"
      echo "[assemble] --> Step: $STEP"
      STEP_START=$(date +%s)

      if [[ -x "$SCRIPT" ]]; then
        bash "$SCRIPT" "$NAME" "$URL" "$BRANCH"
      elif [[ -x "$FALLBACK" ]]; then
        if [[ "$STEP" == "clone" ]]; then
          bash "$FALLBACK" "$NAME" "$URL" "$BRANCH"
        else
          bash "$FALLBACK"
        fi
      else
        echo "[assemble] ❌ No script found for step '$STEP'"
        exit 1
      fi

      STEP_DURATION=$(( $(date +%s) - STEP_START ))
      echo "[assemble] ✅ Step completed in $(format_duration "$STEP_DURATION")"
      STEP_TIMINGS+=("    • $STEP  →  $(format_duration "$STEP_DURATION")")
    done

    COMPONENT_DURATION=$(( $(date +%s) - COMPONENT_START ))
    SUMMARY_LINES+=("")
    SUMMARY_LINES+=("[✓] $NAME  —  $(format_duration "$COMPONENT_DURATION")")
    SUMMARY_LINES+=("${STEP_TIMINGS[@]}")
  done

done

echo ""
echo "📋 Component Summary:"
printf '%s\n' "${SUMMARY_LINES[@]}"
echo ""
TOTAL_DURATION=$(( $(date +%s) - START_TIME ))
echo "✅ Assembly complete in $(format_duration "$TOTAL_DURATION")"
echo "📝 Full log: $LOG_FILE"

echo ""
echo "🔍 Postgres Extensions"
echo ""

awk '
/[[:alnum:]_]+[[:space:]]*\|[[:space:]]*default_version/ {
  if (!found) {
    printf "%-20s | %s\n", "Extension", "Version"
    print "---------------------+---------"
    found = 1
  }
  getline; getline
  split($0, a, "|")
  name = a[1]; version = a[2]
  gsub(/^ +| +$/, "", name)
  gsub(/^ +| +$/, "", version)
  printf "%-20s | %s\n", name, version
}
END {
  if (!found) {
    print "No extensions found."
  }
}' "$LOG_FILE"

exit 0
