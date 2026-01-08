#!/bin/bash
# Post-tool-use hook for auto-formatting
# Runs after Edit/Write operations on code files
#
# Usage: Configure in .claude/settings.json:
# {
#   "hooks": {
#     "PostToolUse": [
#       {
#         "matcher": "Edit|Write",
#         "hooks": ["./hooks/prdx/post-tool-use.sh $CLAUDE_FILE_PATH"]
#       }
#     ]
#   }
# }

FILE="$1"

# Skip if no file or file doesn't exist
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0

# Get file extension
EXT="${FILE##*.}"

case "$EXT" in
  # JavaScript/TypeScript
  js|jsx|ts|tsx|json)
    if command -v prettier &>/dev/null; then
      prettier --write "$FILE" 2>/dev/null
    elif [ -f "node_modules/.bin/prettier" ]; then
      npx prettier --write "$FILE" 2>/dev/null
    fi
    ;;

  # Kotlin
  kt|kts)
    if command -v ktlint &>/dev/null; then
      ktlint -F "$FILE" 2>/dev/null
    elif command -v ktfmt &>/dev/null; then
      ktfmt "$FILE" 2>/dev/null
    fi
    ;;

  # Swift
  swift)
    if command -v swiftformat &>/dev/null; then
      swiftformat "$FILE" 2>/dev/null
    fi
    ;;

  # Python
  py)
    if command -v black &>/dev/null; then
      black --quiet "$FILE" 2>/dev/null
    elif command -v ruff &>/dev/null; then
      ruff format "$FILE" 2>/dev/null
    fi
    ;;

  # Go
  go)
    if command -v gofmt &>/dev/null; then
      gofmt -w "$FILE" 2>/dev/null
    fi
    ;;

  # Rust
  rs)
    if command -v rustfmt &>/dev/null; then
      rustfmt "$FILE" 2>/dev/null
    fi
    ;;
esac

exit 0
