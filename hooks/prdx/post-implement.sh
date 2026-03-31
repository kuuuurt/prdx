#!/bin/bash
# Post-implement hook
# Runs after /prdx:implement to verify tests pass and update PRD status

set -e

PROJECT_ROOT="${PRDX_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE=""
SEARCH_DIR="$PROJECT_ROOT"
while [ "$SEARCH_DIR" != "/" ]; do
  [ -f "$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/prdx.json" && break
  [ -f "$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done
PLANS_SUBDIR=$(jq -r '.plansDirectory // ".prdx/plans"' "$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="$PROJECT_ROOT/$PLANS_SUBDIR"

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
TEST_PASSED=true
TEST_CMD=""

if [ -f "Makefile" ] && grep -q "^test:" Makefile 2>/dev/null; then
    TEST_CMD="make test"
elif [ -f "bun.lockb" ] || [ -f "bunfig.toml" ]; then
    TEST_CMD="bun test"
elif [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    TEST_CMD="npm test"
elif [ -f "build.gradle.kts" ] || [ -f "build.gradle" ]; then
    TEST_CMD="./gradlew test"
elif [ -f "Cargo.toml" ]; then
    TEST_CMD="cargo test"
elif [ -f "go.mod" ]; then
    TEST_CMD="go test ./..."
elif [ -f "Package.swift" ] || ls *.xcodeproj 1>/dev/null 2>&1; then
    # Swift/Xcode: try swift test first (SPM), fall back to xcodebuild
    if [ -f "Package.swift" ]; then
        TEST_CMD="swift test"
    else
        # Find the first .xcodeproj and extract scheme
        XCODEPROJ=$(ls -d *.xcodeproj 2>/dev/null | head -1)
        SCHEME=$(xcodebuild -list -project "$XCODEPROJ" 2>/dev/null | awk '/Schemes:/{found=1; next} found && /^$/{exit} found{gsub(/^[[:space:]]+/,""); print; exit}')
        if [ -n "$SCHEME" ]; then
            # Dynamically detect an available iPhone simulator; fall back to iPhone 16
            SIM_NAME=$(xcrun simctl list devices available 2>/dev/null | grep -E "iPhone [0-9]" | tail -1 | sed 's/.*(\(.*\)).*/\1/')
            SIM_DEST="${SIM_NAME:-iPhone 16}"
            TEST_CMD="xcodebuild test -project $XCODEPROJ -scheme $SCHEME -destination 'platform=iOS Simulator,name=$SIM_DEST'"
        fi
    fi
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then
    TEST_CMD="pytest"
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
