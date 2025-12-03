#!/bin/bash
# Pre-plan validation hook
# Runs before /prdx:plan to validate environment

set -e

# Check if in git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    echo "Initialize git first: git init"
    exit 1
fi

# Ensure .claude/prds directory exists
mkdir -p .claude/prds

# Check if PRD directory is in .gitignore
if ! grep -q "^\.claude/prds/" .gitignore 2>/dev/null; then
    echo "⚠️  .claude/prds/ not in .gitignore"
    echo "PRD files should not be committed to git"
    echo ""
    echo "Add this line to .gitignore:"
    echo ".claude/prds/"
    echo ""
    read -p "Add to .gitignore automatically? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ".claude/prds/" >> .gitignore
        echo "✓ Added to .gitignore"
    fi
fi

exit 0
