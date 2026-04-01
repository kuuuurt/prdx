#!/bin/bash
# Pre-plan validation hook
# Runs before /prdx:plan to validate environment

set -e

# shellcheck source=resolve-plans-dir.sh
source "$(dirname "$0")/resolve-plans-dir.sh"

# Check if in git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Not a git repository"
    echo "Initialize git first: git init"
    exit 1
fi

# Ensure plans directory exists
mkdir -p "$PLANS_DIR"

GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ ! -f "$GITIGNORE" ] || ! { grep -qxF '.prdx/' "$GITIGNORE" || grep -qxF '.prdx/*' "$GITIGNORE"; }; then
  echo '' >> "$GITIGNORE"
  echo '# PRDX' >> "$GITIGNORE"
  echo '.prdx/' >> "$GITIGNORE"
fi

echo "Environment validated"
exit 0
