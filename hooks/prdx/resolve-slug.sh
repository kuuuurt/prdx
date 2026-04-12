#!/usr/bin/env bash
# Shared slug resolution library
# Source this file to resolve a PRD slug to its canonical form and file path
#
# Usage:
#   source "$(dirname "$0")/resolve-slug.sh" my-slug
#
# Prerequisites:
#   PLANS_DIR must already be set (source resolve-plans-dir.sh first)
#
# Sets (in caller's scope):
#   RESOLVED_SLUG  — canonical slug without prdx- prefix (empty on failure)
#   PRD_FILE       — absolute path to matched PRD file (empty on failure)
#   RENAMED        — "true" if an unprefixed plan was renamed, "false" otherwise
#
# Returns:
#   0 on success (exactly one match found)
#   1 on failure (no match or ambiguous match)

# Guard: skip if already resolved for this exact slug
if [ -n "$_RESOLVE_SLUG_LAST" ] && [ "$_RESOLVE_SLUG_LAST" = "$1" ]; then
  return 0
fi

_INPUT_SLUG="$1"

if [ -z "$PLANS_DIR" ]; then
  echo "resolve-slug.sh: PLANS_DIR is not set. Source resolve-plans-dir.sh first." >&2
  return 1
fi

if [ -z "$_INPUT_SLUG" ]; then
  echo "resolve-slug.sh: slug argument is required." >&2
  return 1
fi

# Record which slug we are resolving (set after arg validation so invalid calls don't poison it)
_RESOLVE_SLUG_LAST="$_INPUT_SLUG"

# Strip prdx- prefix from input if present (normalize for matching)
_SLUG="${_INPUT_SLUG#prdx-}"

# Reset outputs so stale values from a prior call don't leak through
RESOLVED_SLUG=""
PRD_FILE=""
RENAMED="false"

_list_available() {
  local available
  available=$(ls "$PLANS_DIR"/prdx-*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/^prdx-//;s/\.md$//')
  if [ -n "$available" ]; then
    echo "Available PRDs:" >&2
    echo "$available" | sed 's/^/  /' >&2
  else
    echo "No PRDs found in $PLANS_DIR" >&2
  fi
}

# Step 1: Exact prefixed match
_CANDIDATE="$PLANS_DIR/prdx-$_SLUG.md"
if [ -f "$_CANDIDATE" ]; then
  RESOLVED_SLUG="$_SLUG"
  PRD_FILE="$_CANDIDATE"
  return 0
fi

# Step 2: Exact prefixed with quick: prdx-quick-{slug}.md (when slug doesn't already start with quick-)
if [[ "$_SLUG" != quick-* ]]; then
  _QUICK_CANDIDATE="$PLANS_DIR/prdx-quick-$_SLUG.md"
  if [ -f "$_QUICK_CANDIDATE" ]; then
    RESOLVED_SLUG="quick-$_SLUG"
    PRD_FILE="$_QUICK_CANDIDATE"
    return 0
  fi
fi

# Step 3: Exact unprefixed fallback — then auto-rename
_UNPREFIXED="$PLANS_DIR/$_SLUG.md"
if [ -f "$_UNPREFIXED" ]; then
  _NEW_PATH="$PLANS_DIR/prdx-$_SLUG.md"
  mv "$_UNPREFIXED" "$_NEW_PATH"
  RESOLVED_SLUG="$_SLUG"
  PRD_FILE="$_NEW_PATH"
  RENAMED="true"
  return 0
fi

# Step 4: Substring match across prdx-*{slug}*.md
_MATCHES=$(ls "$PLANS_DIR"/prdx-*"$_SLUG"*.md 2>/dev/null)
if [ -n "$_MATCHES" ]; then
  _COUNT=$(echo "$_MATCHES" | wc -l | tr -d ' ')
  if [ "$_COUNT" -eq 1 ]; then
    _MATCHED_FILE="$_MATCHES"
    _MATCHED_SLUG=$(basename "$_MATCHED_FILE" .md | sed 's/^prdx-//')
    RESOLVED_SLUG="$_MATCHED_SLUG"
    PRD_FILE="$_MATCHED_FILE"
    return 0
  else
    echo "Multiple PRDs match \"$_SLUG\":" >&2
    echo "$_MATCHES" | xargs -n1 basename | sed 's/^prdx-//;s/\.md$//' | sed 's/^/  /' >&2
    echo "Use AskUserQuestion to let the user select one." >&2
    return 1
  fi
fi

# Step 5: Word-boundary match — split slug on '-', find PRDs containing all words (case-insensitive)
_WORDS=$(echo "$_SLUG" | tr '-' '\n' | grep -v '^$')
if [ -n "$_WORDS" ]; then
  _WB_MATCHES=$(ls "$PLANS_DIR"/prdx-*.md 2>/dev/null)
  for _WORD in $_WORDS; do
    _WB_MATCHES=$(echo "$_WB_MATCHES" | xargs -I{} bash -c 'basename "$1" .md | grep -qi "$2" && echo "$1"' _ {} "$_WORD" 2>/dev/null)
    [ -z "$_WB_MATCHES" ] && break
  done

  if [ -n "$_WB_MATCHES" ]; then
    _WB_COUNT=$(echo "$_WB_MATCHES" | grep -c '.md' 2>/dev/null || echo 0)
    if [ "$_WB_COUNT" -eq 1 ]; then
      _MATCHED_FILE=$(echo "$_WB_MATCHES" | head -1)
      _MATCHED_SLUG=$(basename "$_MATCHED_FILE" .md | sed 's/^prdx-//')
      RESOLVED_SLUG="$_MATCHED_SLUG"
      PRD_FILE="$_MATCHED_FILE"
      return 0
    else
      echo "Multiple PRDs match \"$_SLUG\" (word-boundary):" >&2
      echo "$_WB_MATCHES" | xargs -n1 basename | sed 's/^prdx-//;s/\.md$//' | sed 's/^/  /' >&2
      echo "Use AskUserQuestion to let the user select one." >&2
      return 1
    fi
  fi
fi

# No match found
echo "PRD not found: \"$_SLUG\"" >&2
_list_available
return 1
