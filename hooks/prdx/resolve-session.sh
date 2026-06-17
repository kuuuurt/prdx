#!/usr/bin/env bash
# Session-resume resolver for headless prdx runs.
# Source this file — do NOT execute directly.
#
# prdx persists a `session_id` so a later `claude -p --resume <id>` can pick up
# the prior conversation. Whether that session still EXISTS is the host
# environment's concern (container volume, CI cache, local disk) — prdx only
# detects its presence and degrades. This helper does that detection.
#
# Usage:
#   source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-session.sh"
#
#   # Persist a session id captured from `claude -p --output-format json`:
#   session_store my-slug "$SESSION_ID"
#
#   # Classify the resume path for a slug:
#   session_resolve my-slug
#   echo "$SESSION_MODE"   # resumable | reconstruct | cold
#   echo "$SESSION_ID"     # the stored id (empty unless resumable)
#
# Prerequisites:
#   PROJECT_ROOT must be set (source resolve-plans-dir.sh first).
#   jq is required for store; resolve degrades without it.

# ── Locate the Claude session store ───────────────────────────────────────
# Claude Code writes per-project session transcripts to:
#   ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<encoded-cwd>/<session_id>.jsonl
# where <encoded-cwd> is the project's absolute path with `/` and `.` → `-`.
_session_projects_dir() {
  local cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local cwd="${PROJECT_ROOT:-$(pwd)}"
  local encoded
  encoded=$(echo "$cwd" | sed 's/[/.]/-/g')
  echo "$cfg/projects/$encoded"
}

# session_jsonl_path <session_id> — print the expected transcript path (no existence check).
session_jsonl_path() {
  local sid="$1"
  [ -z "$sid" ] && return 1
  echo "$(_session_projects_dir)/$sid.jsonl"
}

# session_store <slug> <session_id> — persist session_id into the slug's state file.
# Merges into existing JSON; creates the file if absent. No-op on empty id.
session_store() {
  local slug="$1" sid="$2"
  [ -z "$slug" ] && { echo "session_store: slug required" >&2; return 1; }
  [ -z "$sid" ] && return 0
  if [ -z "$PROJECT_ROOT" ]; then
    echo "session_store: PROJECT_ROOT not set. Source resolve-plans-dir.sh first." >&2
    return 1
  fi
  if ! command -v jq &>/dev/null; then
    echo "session_store: jq required but not found." >&2
    return 1
  fi
  local state_file="$PROJECT_ROOT/.prdx/state/$slug.json"
  mkdir -p "$PROJECT_ROOT/.prdx/state"
  local tmp
  tmp="$(mktemp)"
  if [ -f "$state_file" ] && jq empty "$state_file" 2>/dev/null; then
    jq --arg sid "$sid" '.session_id = $sid' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
  else
    jq -n --arg slug "$slug" --arg sid "$sid" '{slug: $slug, session_id: $sid}' > "$tmp" && mv "$tmp" "$state_file"
  fi
}

# session_resolve <slug> — classify the resume path.
# Sets (in caller's scope):
#   SESSION_ID   — stored session id (empty unless SESSION_MODE=resumable)
#   SESSION_MODE — resumable  : session_id stored AND its JSONL exists on disk
#                  reconstruct : session unavailable but dev-plan shards exist
#                  cold        : nothing to resume from
session_resolve() {
  local slug="$1"
  SESSION_ID=""
  SESSION_MODE="cold"
  [ -z "$slug" ] && return 0
  if [ -z "$PROJECT_ROOT" ]; then
    echo "session_resolve: PROJECT_ROOT not set. Source resolve-plans-dir.sh first." >&2
    return 0
  fi

  # 1. Read stored session_id.
  local stored=""
  local state_file="$PROJECT_ROOT/.prdx/state/$slug.json"
  if [ -f "$state_file" ] && command -v jq &>/dev/null; then
    stored=$(jq -r '.session_id // ""' "$state_file" 2>/dev/null)
  fi

  # 2. Resumable only if the transcript actually exists on disk.
  if [ -n "$stored" ]; then
    local jsonl
    jsonl="$(session_jsonl_path "$stored")"
    if [ -f "$jsonl" ]; then
      SESSION_ID="$stored"
      SESSION_MODE="resumable"
      return 0
    fi
    # Stored but absent → environment didn't persist it. Fall through to reconstruct/cold.
    echo "session_resolve: session $stored not found on disk — degrading to reconstruct/cold" >&2
  fi

  # 3. No live session → reconstruct if dev-plan shards exist, else cold.
  if [ -d "$PROJECT_ROOT/.prdx/state/$slug/dev-plan" ] && \
     [ -n "$(ls -A "$PROJECT_ROOT/.prdx/state/$slug/dev-plan" 2>/dev/null)" ]; then
    SESSION_MODE="reconstruct"
  else
    SESSION_MODE="cold"
  fi
  return 0
}
