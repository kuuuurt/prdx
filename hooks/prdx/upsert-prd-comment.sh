#!/usr/bin/env bash
# Upsert a <!-- prdx-prd --> comment on a GitHub issue
# Source this file — do NOT execute directly
#
# Usage:
#   source "$(git rev-parse --show-toplevel)/hooks/prdx/upsert-prd-comment.sh"
#   upsert_prd_comment "$ISSUE_NUMBER" "$PRD_BODY"
#
# Inputs (positional args):
#   $1 = ISSUE_NUMBER   — positive integer
#   $2 = PRD_BODY       — PRD content (marker prepended idempotently)
#
# Exports on success:
#   PRD_COMMENT_ID      — numeric comment ID
#   PRD_COMMENT_URL     — HTML URL of the comment
#   PRD_COMMENT_ACTION  — "created" or "updated"
#
# Returns:
#   0 on success, 1 on hard failure (no gh, no auth, unexpected API error)

# Requires bash
if [ -z "$BASH_VERSION" ]; then
  echo "upsert-prd-comment: requires bash" >&2
  return 1 2>/dev/null || exit 1
fi

# Double-source guard
[ -n "$_UPSERT_PRD_COMMENT_LOADED" ] && return 0
_UPSERT_PRD_COMMENT_LOADED=1

# Error helper — unset guard so a failed source can be retried cleanly
_upc_err() {
  echo "upsert-prd-comment: $*" >&2
  unset _UPSERT_PRD_COMMENT_LOADED
  return 1
}

upsert_prd_comment() {
  local issue_number="${1:-$ISSUE_NUMBER}"
  local prd_body="${2:-$PRD_BODY}"

  # ── Validate inputs ────────────────────────────────────────────────────────

  if [ -z "$issue_number" ] || ! [[ "$issue_number" =~ ^[0-9]+$ ]]; then
    _upc_err "ISSUE_NUMBER must be a non-empty integer (got: '${issue_number}')" || return 1
  fi
  if [ -z "$prd_body" ]; then
    _upc_err "PRD_BODY must be non-empty" || return 1
  fi

  # ── Dependency checks ──────────────────────────────────────────────────────

  if ! command -v gh &>/dev/null; then
    _upc_err "gh is required but not found on PATH" || return 1
  fi
  if ! command -v jq &>/dev/null; then
    _upc_err "jq is required but not found on PATH" || return 1
  fi

  # ── Resolve repo ───────────────────────────────────────────────────────────

  local repo
  repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
  if [ -z "$repo" ]; then
    _upc_err "Could not resolve repo via gh repo view — check gh auth status" || return 1
  fi

  # ── Idempotently prepend marker ────────────────────────────────────────────

  local marker="<!-- prdx-prd -->"
  if [[ "$prd_body" != "${marker}"* ]]; then
    prd_body="${marker}
${prd_body}"
  fi

  # ── Detect existing PRD comment ────────────────────────────────────────────

  local existing_comment
  existing_comment=$(gh api "repos/$repo/issues/$issue_number/comments" --paginate \
    --jq '[.[] | select(.body | contains("<!-- prdx-prd -->"))] | last' \
    2>/dev/null)

  local existing_id=""
  if [ -n "$existing_comment" ] && [ "$existing_comment" != "null" ]; then
    existing_id=$(echo "$existing_comment" | jq -r '.id // empty' 2>/dev/null)
  fi

  # ── PATCH existing or POST new ─────────────────────────────────────────────

  if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
    # Attempt PATCH
    local patch_out patch_err patch_exit _upc_tmp_err
    _upc_tmp_err=$(mktemp)
    patch_out=$(gh api "repos/$repo/issues/comments/$existing_id" \
      -X PATCH -f body="$prd_body" 2>"$_upc_tmp_err")
    patch_exit=$?
    patch_err=$(cat "$_upc_tmp_err" 2>/dev/null)
    rm -f "$_upc_tmp_err"

    if [ "$patch_exit" -eq 0 ]; then
      # PATCH succeeded
      PRD_COMMENT_ID="$existing_id"
      PRD_COMMENT_URL=$(echo "$patch_out" | jq -r '.html_url // ""' 2>/dev/null)
      PRD_COMMENT_ACTION="updated"
      echo "upsert-prd-comment: updated #${PRD_COMMENT_ID}" >&2
      export PRD_COMMENT_ID PRD_COMMENT_URL PRD_COMMENT_ACTION
      return 0
    elif [ "$patch_exit" -eq 22 ]; then
      # HTTP 4xx (404 deleted, 410 gone, 403 forbidden, etc.) — fall through to POST
      echo "upsert-prd-comment: comment #${existing_id} unreachable (HTTP 4xx) — falling back to POST" >&2
    else
      _upc_err "PATCH failed for comment #${existing_id}: ${patch_err}" || return 1
    fi
  fi

  # POST new comment
  local post_url
  post_url=$(gh issue comment "$issue_number" --body "$prd_body" 2>/dev/null)
  if [ -z "$post_url" ]; then
    _upc_err "gh issue comment returned no output for issue #${issue_number}" || return 1
  fi

  # gh issue comment prints the comment URL to stdout
  local comment_url
  comment_url=$(echo "$post_url" | grep -o 'https://[^ ]*' | head -1)
  if [ -z "$comment_url" ]; then
    comment_url="$post_url"
  fi

  PRD_COMMENT_ID=$(echo "$comment_url" | grep -o '[0-9]*$')
  PRD_COMMENT_URL="$comment_url"
  PRD_COMMENT_ACTION="created"
  echo "upsert-prd-comment: created #${PRD_COMMENT_ID}" >&2
  export PRD_COMMENT_ID PRD_COMMENT_URL PRD_COMMENT_ACTION
  return 0
}
