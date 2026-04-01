#!/bin/bash
# Pre-implement validation hook
# Runs before /prdx:implement to validate PRD and environment

set -e

# shellcheck source=resolve-plans-dir.sh
source "$(dirname "$0")/resolve-plans-dir.sh"

PRD_SLUG="$1"

if [ -z "$PRD_SLUG" ]; then
    echo "No PRD slug provided"
    exit 1
fi

# Find PRD file — exact match first, then quick, then unprefixed, then substring with ambiguity check
PRD_FILE=""

# 1. Exact match: prdx-{slug}.md
if [ -f "$PLANS_DIR/prdx-${PRD_SLUG}.md" ]; then
    PRD_FILE="$PLANS_DIR/prdx-${PRD_SLUG}.md"
# 2. Exact match: prdx-quick-{slug}.md
elif [ -f "$PLANS_DIR/prdx-quick-${PRD_SLUG}.md" ]; then
    PRD_FILE="$PLANS_DIR/prdx-quick-${PRD_SLUG}.md"
# 3. Exact match (unprefixed): {slug}.md
elif [ -f "$PLANS_DIR/${PRD_SLUG}.md" ]; then
    PRD_FILE="$PLANS_DIR/${PRD_SLUG}.md"
else
    # 4. Substring match with ambiguity check (search all .md files)
    MATCHES=$(ls "$PLANS_DIR/"*${PRD_SLUG}*.md 2>/dev/null || true)
    MATCH_COUNT=$(echo "$MATCHES" | grep -c . 2>/dev/null || echo 0)

    if [ "$MATCH_COUNT" -eq 1 ]; then
        PRD_FILE="$MATCHES"
    elif [ "$MATCH_COUNT" -gt 1 ]; then
        echo "Ambiguous slug '$PRD_SLUG' matches multiple PRDs:"
        echo "$MATCHES" | xargs -I{} basename {} .md | sed 's/^prdx-//'
        echo ""
        echo "Please use a more specific slug."
        exit 1
    fi
fi

if [ -z "$PRD_FILE" ]; then
    echo "PRD not found: $PRD_SLUG"
    echo ""
    echo "Available PRDs:"
    PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
    if [ -n "$PROJECT_NAME" ]; then
        grep -rl "^\*\*Project:\*\* $PROJECT_NAME" "$PLANS_DIR/"*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^prdx-//' || echo "No PRDs found"
    else
        ls "$PLANS_DIR/"*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^prdx-//' || echo "No PRDs found"
    fi
    exit 1
fi

echo "Validating PRD: $PRD_FILE"

# Check PRD has required sections
REQUIRED_SECTIONS=("## Goal" "## Acceptance Criteria" "## Approach")

for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "$section" "$PRD_FILE"; then
        echo "Missing required section: $section"
        exit 1
    fi
done

# Check for parent PRD (has children — cannot implement directly)
if grep -q "^## Children" "$PRD_FILE"; then
    echo "Cannot implement parent PRD directly. Use child PRD slugs instead."
    echo "Run: /prdx:show $PRD_SLUG to see child PRDs"
    exit 1
fi

# Check PRD status
STATUS=$(grep "^\*\*Status:\*\*" "$PRD_FILE" | sed 's/\*\*Status:\*\* //')

if [ "$STATUS" = "completed" ] || [ "$STATUS" = "closed" ]; then
    echo "PRD is already $STATUS"
    echo "Cannot implement a closed PRD"
    exit 1
fi

# Check if on correct branch (if branch metadata exists)
if grep -q "^\*\*Branch:\*\*" "$PRD_FILE"; then
    EXPECTED_BRANCH=$(grep "^\*\*Branch:\*\*" "$PRD_FILE" | sed 's/\*\*Branch:\*\* //')
    CURRENT_BRANCH=$(git branch --show-current)

    if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
        echo "Not on expected branch"
        echo "Current: $CURRENT_BRANCH"
        echo "Expected: $EXPECTED_BRANCH"
        echo ""
        if [ "$CI" = "true" ]; then
            echo "CI mode: auto-switching to $EXPECTED_BRANCH"
            git checkout "$EXPECTED_BRANCH" 2>/dev/null || git checkout -b "$EXPECTED_BRANCH"
        else
            read -p "Switch to $EXPECTED_BRANCH? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git checkout "$EXPECTED_BRANCH" 2>/dev/null || git checkout -b "$EXPECTED_BRANCH"
            else
                exit 1
            fi
        fi
    fi
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "You have uncommitted changes"
    git status --short
    echo ""
    if [ "$CI" = "true" ]; then
        echo "CI mode: continuing with uncommitted changes"
    else
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ ! -f "$GITIGNORE" ] || ! { grep -qxF '.prdx/' "$GITIGNORE" || grep -qxF '.prdx/*' "$GITIGNORE"; }; then
  echo '' >> "$GITIGNORE"
  echo '# PRDX' >> "$GITIGNORE"
  echo '.prdx/' >> "$GITIGNORE"
fi

echo "PRD validation passed"
exit 0
