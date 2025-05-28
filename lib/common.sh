#!/usr/bin/env bash
# lib/common.sh — General-purpose functions for Assembly BOM

# format_duration: Format a duration in seconds as HH:MM:SS or <1s
# Usage: format_duration <seconds>
format_duration() {
    local total_seconds="$1"
    if [[ "$total_seconds" -lt 1 ]]; then
        echo "<1s"
    else
        local hours=$(( total_seconds / 3600 ))
        local minutes=$(( (total_seconds % 3600) / 60 ))
        local seconds=$(( total_seconds % 60 ))
        printf "%02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
    fi
}

section() {
  echo "==> $1..."
}

section_complete() {
  echo "✅ $1 complete (duration: $(format_duration "$(($(date +%s) - $2))"))"
}

log() {
  printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"
}
