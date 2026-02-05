#!/bin/bash
# PostToolUse hook that prompts Claude to optimize changed lines
# Triggered after Edit/Write operations
#
# Usage: Configure in .claude/settings.json:
# {
#   "hooks": {
#     "PostToolUse": [
#       {
#         "matcher": "Edit|Write",
#         "hooks": [
#           {
#             "type": "command",
#             "command": "./hooks/prdx/post-edit-optimize.sh"
#           }
#         ]
#       }
#     ]
#   }
# }

FILE="$CLAUDE_FILE_PATH"

# Skip if no file path
[ -z "$FILE" ] && exit 0

# Skip non-source files
case "$FILE" in
  *.kt|*.kts|*.swift|*.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs)
    ;;
  *)
    exit 0
    ;;
esac

# Skip if file doesn't exist
[ ! -f "$FILE" ] && exit 0

# Get the line range that was changed (from git diff of unstaged changes)
CHANGED_LINES=$(git diff --unified=0 "$FILE" 2>/dev/null | grep -E "^@@" | head -1 | sed -E 's/.*\+([0-9]+)(,([0-9]+))?.*/\1-\3/' | sed 's/-$//')

if [ -n "$CHANGED_LINES" ]; then
  # Output JSON with additionalContext for Claude
  cat << EOF
{
  "additionalContext": "PRDX Auto-Optimize: Apply optimization rules to lines $CHANGED_LINES in $FILE. Check for: documentation-style comments to remove, single-use variables to inline, single-use functions to inline. Use Edit tool to apply any optimizations found. If no optimizations needed, continue."
}
EOF
fi

exit 0
