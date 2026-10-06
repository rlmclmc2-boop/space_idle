#!/usr/bin/env bash
set -eu
: "${PROJECT:?required}" "${CHECKPOINT:?required}" "${RESULT:?required}"
mkdir -p "$RESULT"
export XDG_DATA_HOME="$RESULT/userdata" XDG_CONFIG_HOME="$RESULT/config" XDG_CACHE_HOME="$RESULT/cache"
export QA_DIAGNOSTIC_RESULT_DIR="$RESULT" HYPERSPACE_RESUME_PATH="$CHECKPOINT"
export QA_STAGE_MODE=cached QA_STAGE_VFX_PROBE=1 QA_STAGE_VFX_FAST=1 QA_IDLE_SALVAGE=1
export HYPERSPACE_LONGRUN_OPTIONS
HYPERSPACE_LONGRUN_OPTIONS=$(cat "$(dirname "$0")/cached-runtime-options.json")
exec godot --headless --path "$PROJECT" --script res://qa/stage_campaign.gd
