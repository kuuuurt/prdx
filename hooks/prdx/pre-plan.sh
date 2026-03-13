#!/bin/bash
# Pre-plan validation hook
# Runs before /prdx:plan to validate environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/resolve-plans-dir.sh"
PLANS_DIR=$(resolve_plans_dir)

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
