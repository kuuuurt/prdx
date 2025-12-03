#!/bin/bash
# Pre-implement validation hook
# Runs before /prdx:implement to validate PRD and environment

set -e

PRD_SLUG="$1"

if [ -z "$PRD_SLUG" ]; then
    echo "❌ No PRD slug provided"
    exit 1
fi

# Find PRD file
PRD_FILE=$(find .claude/prds -name "*${PRD_SLUG}*.md" -type f | head -1)

if [ -z "$PRD_FILE" ]; then
    echo "❌ PRD not found: $PRD_SLUG"
    echo ""
    echo "Available PRDs:"
    find .claude/prds -name "*.md" -type f -exec basename {} .md \;
    exit 1
fi

echo "📄 Validating PRD: $PRD_FILE"

# Check PRD has required sections
REQUIRED_SECTIONS=("## Goal" "## Acceptance Criteria" "## Approach" "## Implementation Tasks")

for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "$section" "$PRD_FILE"; then
        echo "❌ Missing required section: $section"
        exit 1
    fi
done

# Check PRD status
STATUS=$(grep "^\*\*Status:\*\*" "$PRD_FILE" | sed 's/\*\*Status:\*\* //')

if [ "$STATUS" = "completed" ] || [ "$STATUS" = "closed" ]; then
    echo "❌ PRD is already $STATUS"
    echo "Cannot implement a closed PRD"
    exit 1
fi

# Check if on correct branch (if branch metadata exists)
if grep -q "^\*\*Branch:\*\*" "$PRD_FILE"; then
    EXPECTED_BRANCH=$(grep "^\*\*Branch:\*\*" "$PRD_FILE" | sed 's/\*\*Branch:\*\* //')
    CURRENT_BRANCH=$(git branch --show-current)

    if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
        echo "⚠️  Not on expected branch"
        echo "Current: $CURRENT_BRANCH"
        echo "Expected: $EXPECTED_BRANCH"
        echo ""
        read -p "Switch to $EXPECTED_BRANCH? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git checkout "$EXPECTED_BRANCH" 2>/dev/null || git checkout -b "$EXPECTED_BRANCH"
        else
            exit 1
        fi
    fi
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️  You have uncommitted changes"
    git status --short
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✓ PRD validation passed"
exit 0
