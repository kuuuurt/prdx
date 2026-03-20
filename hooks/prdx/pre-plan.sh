#!/bin/bash
# Pre-plan validation hook
# Runs before /prdx:plan to validate environment

set -e

PROJECT_ROOT="${PRDX_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PLANS_DIR="$PROJECT_ROOT/.prdx/plans"

# Check if in git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Not a git repository"
    echo "Initialize git first: git init"
    exit 1
fi

# Ensure plans directory exists
mkdir -p "$PLANS_DIR"

echo "Environment validated"
exit 0
