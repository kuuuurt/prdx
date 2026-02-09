#!/bin/bash
# Post-implement hook
# Runs after /prdx:implement to verify tests pass and update PRD status

set -e

PRD_SLUG="$1"

if [ -z "$PRD_SLUG" ]; then
    echo "No PRD slug provided"
    exit 1
fi

# Find PRD file (prdx-* naming convention)
PRD_FILE=$(ls ~/.claude/plans/prdx-*${PRD_SLUG}*.md 2>/dev/null | head -1)

if [ -z "$PRD_FILE" ]; then
    echo "PRD not found: $PRD_SLUG"
    exit 0  # Don't fail, just warn
fi

# --- Test Verification Gate ---
# Try common test runners, skip if none found
TEST_PASSED=true
TEST_CMD=""

if [ -f "Makefile" ] && grep -q "^test:" Makefile 2>/dev/null; then
    TEST_CMD="make test"
elif [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    TEST_CMD="npm test"
elif [ -f "build.gradle.kts" ] || [ -f "build.gradle" ]; then
    TEST_CMD="./gradlew test"
elif [ -f "Cargo.toml" ]; then
    TEST_CMD="cargo test"
elif [ -f "go.mod" ]; then
    TEST_CMD="go test ./..."
fi

if [ -n "$TEST_CMD" ]; then
    echo "Running tests: $TEST_CMD"
    if ! $TEST_CMD 2>&1; then
        echo ""
        echo "Tests failing — agent should fix before review"
        TEST_PASSED=false
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
if ! grep -q "^**Implemented:**" "$PRD_FILE"; then
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
echo "Test the implementation, then run /prdx:push to create PR"
exit 0
