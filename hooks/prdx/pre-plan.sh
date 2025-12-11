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

# Ensure .prdx/prds directory exists
mkdir -p .prdx/prds

# Check if PRD directory is in .gitignore
if ! grep -q "^\.prdx/prds/" .gitignore 2>/dev/null; then
    echo "⚠️  .prdx/prds/ not in .gitignore"
    echo "PRD files should not be committed to git"
    echo ""
    echo "Add this line to .gitignore:"
    echo ".prdx/prds/"
    echo ""
    read -p "Add to .gitignore automatically? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ".prdx/prds/" >> .gitignore
        echo "✓ Added to .gitignore"
    fi
fi

exit 0
