#!/bin/bash
# Post-implement hook
# Runs after /prdx:implement to update PRD status

set -e

PRD_SLUG="$1"

if [ -z "$PRD_SLUG" ]; then
    echo "❌ No PRD slug provided"
    exit 1
fi

# Find PRD file
PRD_FILE=$(find .claude/prds -name "*${PRD_SLUG}*.md" -type f | head -1)

if [ -z "$PRD_FILE" ]; then
    echo "⚠️  PRD not found: $PRD_SLUG"
    exit 0  # Don't fail, just warn
fi

# Update status to implemented
sed -i.bak 's/^\*\*Status:\*\* .*/\*\*Status:\*\* implemented/' "$PRD_FILE"
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

echo "✓ Updated PRD status to 'implemented'"
exit 0
