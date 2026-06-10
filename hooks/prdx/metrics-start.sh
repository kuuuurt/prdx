#!/bin/bash
# Write active-run marker for token metrics tracking.
# Usage: source "$(dirname "$0")/metrics-start.sh" <slug>
#
# Writes .prdx/metrics/active-run.json with run context so metrics-end.sh
# can locate the correct JSONL window when the run completes.

_METRICS_SLUG="${1:-}"
_PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
_METRICS_DIR="$_PROJECT_ROOT/.prdx/metrics"

mkdir -p "$_METRICS_DIR"

cat > "$_METRICS_DIR/active-run.json" <<EOF
{
  "slug": "$_METRICS_SLUG",
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "main_session_id": "${CLAUDE_SESSION_ID:-}",
  "working_dir": "$PWD"
}
EOF
