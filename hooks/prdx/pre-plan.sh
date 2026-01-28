#!/bin/bash
# Pre-plan validation hook
# Runs before /prdx:plan to validate environment

set -e

# Check if in git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Not a git repository"
    echo "Initialize git first: git init"
    exit 1
fi

# Ensure ~/.claude/plans directory exists (Claude's default)
mkdir -p ~/.claude/plans

echo "Environment validated"
exit 0
