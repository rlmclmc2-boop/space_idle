#!/usr/bin/env bash
set -eu
: "${PROJECT:?self-built e528 project required}" "${CHECKPOINT:?converted full binary checkpoint required}" "${RESULT:?isolated result directory required}"
mkdir -p "$RESULT"
export XDG_DATA_HOME="$RESULT/userdata" XDG_CONFIG_HOME="$RESULT/config" XDG_CACHE_HOME="$RESULT/cache"
export DISPLAY="${DISPLAY:-:90}" QA_IDLE_SALVAGE=1
export QA_DIAGNOSTIC_RESULT_DIR="$RESULT" HYPERSPACE_RESUME_PATH="$CHECKPOINT"
export HYPERSPACE_LONGRUN_OPTIONS
HYPERSPACE_LONGRUN_OPTIONS=$(cat "$(dirname "$0")/runtime-options.json")
exec godot --path "$PROJECT" --script res://qa/hyperspace_longrun.gd --rendering-method gl_compatibility
