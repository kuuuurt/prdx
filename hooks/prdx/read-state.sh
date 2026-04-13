#!/usr/bin/env bash
# Shared state file reader library
# Source this file to read a PRD's state file into named variables
#
# Usage:
#   source "$(dirname "$0")/read-state.sh" my-slug
#
# Prerequisites:
#   PROJECT_ROOT must already be set (source resolve-plans-dir.sh first)
#
# Sets (in caller's scope):
#   STATE_PHASE      — phase field from state file (empty if file absent or field missing)
#   STATE_QUICK      — quick field from state file (empty if file absent or field missing)
#   STATE_PARENT     — parent field from state file (empty if file absent or field missing)
#   STATE_PR_NUMBER  — pr_number field from state file (empty if file absent or field missing)
#
# Returns:
#   0 always (absent or malformed state files are not errors)

# Guard: skip if already read for this slug
[ -n "$_READ_STATE_SLUG" ] && [ "$_READ_STATE_SLUG" = "$1" ] && return 0

_RS_SLUG="$1"
_READ_STATE_SLUG="$_RS_SLUG"

STATE_PHASE=""
STATE_QUICK=""
STATE_PARENT=""
STATE_PR_NUMBER=""

if [ -z "$PROJECT_ROOT" ]; then
  echo "read-state.sh: PROJECT_ROOT is not set. Source resolve-plans-dir.sh first." >&2
  return 0
fi

if [ -z "$_RS_SLUG" ]; then
  return 0
fi

_STATE_FILE="$PROJECT_ROOT/.prdx/state/$_RS_SLUG.json"

if [ ! -f "$_STATE_FILE" ]; then
  # Absent state file is not an error — caller checks STATE_PHASE for empty
  return 0
fi

if ! command -v jq &>/dev/null; then
  echo "read-state.sh: jq is required but not found." >&2
  return 0
fi

_RS_CONTENT=$(cat "$_STATE_FILE" 2>/dev/null)

# Validate JSON
if ! echo "$_RS_CONTENT" | jq empty 2>/dev/null; then
  echo "read-state.sh: warning: malformed JSON in $_STATE_FILE" >&2
  return 0
fi

STATE_PHASE=$(echo "$_RS_CONTENT" | jq -r '.phase // ""')
# Use 'if . == null then "" else tostring end' to preserve false/0 values correctly
STATE_QUICK=$(echo "$_RS_CONTENT" | jq -r '.quick | if . == null then "" else tostring end')
STATE_PARENT=$(echo "$_RS_CONTENT" | jq -r '.parent // ""')
STATE_PR_NUMBER=$(echo "$_RS_CONTENT" | jq -r '.pr_number | if . == null then "" else tostring end')

return 0
