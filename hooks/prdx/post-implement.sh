#!/bin/bash
# Post-implement hook
# Runs after /prdx:implement to verify tests pass and update PRD status

set -e

# shellcheck source=resolve-plans-dir.sh
source "$(dirname "$0")/resolve-plans-dir.sh"
# shellcheck source=discover-commands.sh
source "$(dirname "$0")/discover-commands.sh"

PRD_SLUG="$1"

if [ -z "$PRD_SLUG" ]; then
    echo "No PRD slug provided"
    exit 1
fi

# Find PRD file — exact match first, then quick, then substring with ambiguity check
PRD_FILE=""

# 1. Exact match: prdx-{slug}.md
if [ -f "$PLANS_DIR/prdx-${PRD_SLUG}.md" ]; then
    PRD_FILE="$PLANS_DIR/prdx-${PRD_SLUG}.md"
# 2. Exact match: prdx-quick-{slug}.md
elif [ -f "$PLANS_DIR/prdx-quick-${PRD_SLUG}.md" ]; then
    PRD_FILE="$PLANS_DIR/prdx-quick-${PRD_SLUG}.md"
else
    # 3. Substring match with ambiguity check
    MATCHES=$(ls "$PLANS_DIR/"prdx-*${PRD_SLUG}*.md 2>/dev/null || true)
    MATCH_COUNT=$(echo "$MATCHES" | grep -c . 2>/dev/null || echo 0)

    if [ "$MATCH_COUNT" -eq 1 ]; then
        PRD_FILE="$MATCHES"
    elif [ "$MATCH_COUNT" -gt 1 ]; then
        echo "Warning: Ambiguous slug '$PRD_SLUG' matches multiple PRDs:"
        echo "$MATCHES" | xargs -I{} basename {} .md | sed 's/^prdx-//'
        echo "Skipping post-implement updates."
        exit 0
    fi
fi

if [ -z "$PRD_FILE" ]; then
    echo "PRD not found: $PRD_SLUG"
    exit 0  # Don't fail, just warn
fi

# --- Test Verification Gate ---
# Try common test runners, skip if none found
TEST_CMD=$(discover_test_cmd)

if [ -n "$TEST_CMD" ]; then
    echo "Running tests: $TEST_CMD"
    if ! eval "$TEST_CMD" 2>&1; then
        echo ""
        echo "Tests failing — agent should fix before review"
        exit 1
    fi
    echo "Tests passed"
else
    echo "No test runner detected, skipping test verification"
fi

# --- Update PRD Status ---

# Update status to review (user must confirm before pushing)
sed -i.bak 's/^\*\*Status:\*\* .*/\*\*Status:\*\* review/' "$PRD_FILE"
rm "${PRD_FILE}.bak"

# Add implementation timestamp if not present
if ! grep -qF "**Implemented:**" "$PRD_FILE"; then
    CURRENT_DATE=$(date +%Y-%m-%d)
    # Add after Implementation Notes header
    if grep -q "^## Implementation Notes" "$PRD_FILE"; then
        sed -i.bak "/^## Implementation Notes/a\\
\\
**Implemented:** $CURRENT_DATE" "$PRD_FILE"
        rm "${PRD_FILE}.bak"
    fi
fi

echo "Updated PRD status to 'review'"

# --- Write per-PRD state file ---
mkdir -p .prdx/state

# Check if this is a child PRD
PARENT=$(grep '^\*\*Parent:\*\*' "$PRD_FILE" 2>/dev/null | sed 's/\*\*Parent:\*\* //' | xargs)

if [ -n "$PARENT" ]; then
  cat > .prdx/state/${PRD_SLUG}.json << EOF
{"slug": "${PRD_SLUG}", "phase": "review", "quick": false, "parent": "${PARENT}"}
EOF
else
  cat > .prdx/state/${PRD_SLUG}.json << EOF
{"slug": "${PRD_SLUG}", "phase": "review", "quick": false}
EOF
fi

echo "Test the implementation, then run /prdx:push to create PR"
exit 0
