#!/bin/bash
# Write active-run marker for token metrics tracking.
# Usage: source "$(dirname "$0")/metrics-start.sh"
#
# Writes .prdx/metrics/active-run.json with run context so metrics-end.sh
# can locate the correct JSONL window when the run completes.
# Slug is not known at start time — metrics-end.sh accepts it as $1.

_PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
_METRICS_DIR="$_PROJECT_ROOT/.prdx/metrics"

mkdir -p "$_METRICS_DIR"

jq -n \
  --arg started_at  "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg session_id  "${CLAUDE_SESSION_ID:-}" \
  --arg working_dir "$PWD" \
  '{started_at: $started_at, main_session_id: $session_id, working_dir: $working_dir}' \
  > "$_METRICS_DIR/active-run.json"
