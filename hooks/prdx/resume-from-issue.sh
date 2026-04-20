#!/usr/bin/env bash
# Resume a CI-created PRD locally from a GitHub issue comment
# Source this file — do NOT execute directly
#
# Usage:
#   # Option A: from issue number
#   ISSUE_NUMBER=42 source "$(dirname "$0")/resume-from-issue.sh"
#
#   # Option B: from PR number (resolves Closes #N)
#   PR_NUMBER=7 source "$(dirname "$0")/resume-from-issue.sh"
#
# Prerequisites:
#   Caller must have sourced resolve-plans-dir.sh first
#   (so PLANS_DIR and PROJECT_ROOT are set).
#
# Sets (in caller's scope):
#   RESUME_SLUG        — derived slug for the resumed PRD
#   RESUME_PR_NUMBER   — PR number (empty if no PR found)
#   RESUME_PHASE       — "reviewing" (PR exists) or "post-implement" (no PR)
#
# Returns:
#   0 on success, 1 on error (with message to stderr)

# Requires bash (uses process substitution)
if [ -z "$BASH_VERSION" ]; then
  echo "resume-from-issue: requires bash (process substitution not available in current shell)" >&2
  return 1 2>/dev/null || exit 1
fi

# Guard: skip if already loaded for this exact ISSUE_NUMBER:PR_NUMBER combination
_RFI_GUARD_KEY="${ISSUE_NUMBER}:${PR_NUMBER}"
[ -n "$_RESUME_FROM_ISSUE_LOADED" ] && [ "$_RESUME_FROM_ISSUE_LOADED" = "$_RFI_GUARD_KEY" ] && return 0

# Error helper — unset guard flag, echo to stderr, and return 1
_rfi_err() {
  echo "resume-from-issue: $*" >&2
  unset _RESUME_FROM_ISSUE_LOADED
  return 1
}

# Set guard now; _rfi_err will unset it on any error path so retries work
_RESUME_FROM_ISSUE_LOADED="$_RFI_GUARD_KEY"

# Reset output vars
RESUME_SLUG=""
RESUME_PR_NUMBER=""
RESUME_PHASE=""

# Dependency checks
if ! command -v gh &>/dev/null; then
  _rfi_err "gh is required but not found on PATH" || return 1
fi
if ! command -v jq &>/dev/null; then
  _rfi_err "jq is required but not found on PATH" || return 1
fi

# Require PLANS_DIR / PROJECT_ROOT (set by resolve-plans-dir.sh)
if [ -z "$PROJECT_ROOT" ] || [ -z "$PLANS_DIR" ]; then
  _rfi_err "PROJECT_ROOT and PLANS_DIR must be set. Source resolve-plans-dir.sh first." || return 1
fi

# ── Step 1: Resolve ISSUE_NUMBER from PR_NUMBER if needed ──────────────────

_RFI_PR_PASSED=""

if [ -n "$PR_NUMBER" ] && [ -z "$ISSUE_NUMBER" ]; then
  _RFI_PR_PASSED="$PR_NUMBER"
  _RFI_PR_BODY=$(gh pr view "$PR_NUMBER" --json body --jq '.body' 2>/dev/null)
  if [ -z "$_RFI_PR_BODY" ]; then
    _rfi_err "Could not fetch body for PR #$PR_NUMBER" || return 1
  fi
  # Extract first Closes/Fixes/Resolves #N (case-insensitive)
  ISSUE_NUMBER=$(echo "$_RFI_PR_BODY" \
    | grep -ioE '(closes|fixes|resolves) #[0-9]+' \
    | head -1 \
    | grep -oE '[0-9]+')
  if [ -z "$ISSUE_NUMBER" ]; then
    _rfi_err "PR #$PR_NUMBER body contains no 'Closes/Fixes/Resolves #N' reference" || return 1
  fi
fi

if [ -z "$ISSUE_NUMBER" ]; then
  _rfi_err "ISSUE_NUMBER (or PR_NUMBER) must be set before sourcing this file" || return 1
fi

# ── Step 2: Fetch issue title + PRD comment ────────────────────────────────

_RFI_ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" \
  --json title,comments \
  --jq '{title: .title, comment: ([.comments[] | select(.body | contains("<!-- prdx-prd -->"))] | last)}' \
  2>/dev/null)

if [ -z "$_RFI_ISSUE_JSON" ]; then
  _rfi_err "Could not fetch issue #$ISSUE_NUMBER" || return 1
fi

_RFI_TITLE=$(echo "$_RFI_ISSUE_JSON" | jq -r '.title // ""')
_RFI_COMMENT_BODY=$(echo "$_RFI_ISSUE_JSON" | jq -r '.comment.body // ""')

if [ -z "$_RFI_COMMENT_BODY" ]; then
  _rfi_err "Issue #$ISSUE_NUMBER has no <!-- prdx-prd --> comment. Run \`@claude plan\` first." || return 1
fi

# ── Step 3: Derive slug from issue title ───────────────────────────────────

# Filler list aligned exactly with /prdx:plan Step 0 rule (no "and", no "or")
_RFI_FILLERS="add
implement
create
update
fix
refactor
improve
the
a
for
from
to
in
on
of
with"

# Tokenize on non-alphanumeric, lowercase, filter fillers, take up to 4 tokens
RESUME_SLUG=$(echo "$_RFI_TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -cs 'a-z0-9' '\n' \
  | grep -v '^$' \
  | grep -Fxvf <(echo "$_RFI_FILLERS") \
  | head -4 \
  | tr '\n' '-' \
  | sed 's/-$//')

if [ -z "$RESUME_SLUG" ]; then
  _rfi_err "Could not derive slug from issue title: $_RFI_TITLE" || return 1
fi

# ── Step 4: Idempotency — existing state wins ──────────────────────────────

_RFI_STATE_FILE="$PROJECT_ROOT/.prdx/state/${RESUME_SLUG}.json"

if [ -f "$_RFI_STATE_FILE" ]; then
  echo "Resume: state already exists for ${RESUME_SLUG}"
  _RFI_EXISTING=$(cat "$_RFI_STATE_FILE" 2>/dev/null)
  RESUME_PHASE=$(echo "$_RFI_EXISTING" | jq -r '.phase // "post-implement"')
  RESUME_PR_NUMBER=$(echo "$_RFI_EXISTING" | jq -r '.pr_number | if . == null then "" else tostring end')
  return 0
fi

# ── Step 5: Gather all remote data before writing anything ─────────────────

# Parse **Branch:** from the in-memory PRD body (before writing to disk)
_RFI_PRD_STRIPPED=$(echo "$_RFI_COMMENT_BODY" | sed 's/<!-- prdx-prd -->//')
_RFI_BRANCH=$(echo "$_RFI_PRD_STRIPPED" \
  | grep -m1 '^\*\*Branch:\*\*' \
  | sed -E 's/\*\*Branch:\*\*[[:space:]]*//')

_RFI_FOUND_PR=""
if [ -n "$_RFI_BRANCH" ]; then
  _RFI_FOUND_PR=$(gh pr list --head "$_RFI_BRANCH" --state all --json number --jq '.[0].number // empty' 2>/dev/null)
fi

# Fall back to the explicitly passed PR_NUMBER when branch lookup found nothing
if [ -z "$_RFI_FOUND_PR" ] && [ -n "$_RFI_PR_PASSED" ]; then
  _RFI_FOUND_PR="$_RFI_PR_PASSED"
fi

# ── Step 6: Write PRD file and state file atomically ──────────────────────

mkdir -p "$PLANS_DIR"
echo "$_RFI_PRD_STRIPPED" > "$PLANS_DIR/prdx-${RESUME_SLUG}.md"

mkdir -p "$PROJECT_ROOT/.prdx/state"

if [ -n "$_RFI_FOUND_PR" ]; then
  RESUME_PR_NUMBER="$_RFI_FOUND_PR"
  RESUME_PHASE="reviewing"
  printf '{"slug":"%s","phase":"reviewing","quick":false,"pr_number":%s}\n' \
    "$RESUME_SLUG" "$RESUME_PR_NUMBER" > "$_RFI_STATE_FILE"
else
  RESUME_PHASE="post-implement"
  echo "Resume: no PR found for ${RESUME_SLUG} — setting phase to post-implement" >&2
  printf '{"slug":"%s","phase":"post-implement","quick":false}\n' \
    "$RESUME_SLUG" > "$_RFI_STATE_FILE"
fi

return 0
