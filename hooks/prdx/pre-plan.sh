#!/bin/bash
# Pre-plan validation hook
# Runs before /prdx:plan to validate environment

set -e

PROJECT_ROOT="${PRDX_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE=""
SEARCH_DIR="$PROJECT_ROOT"
while [ "$SEARCH_DIR" != "/" ]; do
  [ -f "$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/prdx.json" && break
  [ -f "$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done
PLANS_SUBDIR=$(jq -r '.plansDirectory // ".prdx/plans"' "$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="$PROJECT_ROOT/$PLANS_SUBDIR"

# Check if in git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Not a git repository"
    echo "Initialize git first: git init"
    exit 1
fi

# Ensure plans directory exists
mkdir -p "$PLANS_DIR"

# Ensure plans directory tracking is correct — conditional on whether plans are under .prdx/
GITIGNORE="$PROJECT_ROOT/.gitignore"
if echo "$PLANS_SUBDIR" | grep -q "^\.prdx/"; then
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF '.prdx/*' "$GITIGNORE"; then
    echo '' >> "$GITIGNORE"
    echo '# PRDX - only track plans (ignore state, markers, etc.)' >> "$GITIGNORE"
    echo '.prdx/*' >> "$GITIGNORE"
    echo "!$PLANS_SUBDIR/" >> "$GITIGNORE"
  fi
else
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF '.prdx/*' "$GITIGNORE"; then
    echo '' >> "$GITIGNORE"
    echo '# PRDX state (ignore all)' >> "$GITIGNORE"
    echo '.prdx/*' >> "$GITIGNORE"
  fi
fi

echo "Environment validated"
exit 0
