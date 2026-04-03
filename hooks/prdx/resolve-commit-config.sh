#!/bin/bash
# Shared commit config resolution library
# Source this file to set commit configuration variables
#
# Usage:
#   source "$(dirname "$0")/resolve-commit-config.sh"
#
# Sets: COMMIT_FORMAT, COAUTHOR_ENABLED, COAUTHOR_NAME, COAUTHOR_EMAIL,
#        EXTENDED_DESC_ENABLED, CLAUDE_LINK_ENABLED

# Find config file if not already set
if [ -z "$CONFIG_FILE" ]; then
  _RCC_DIR="$(pwd)"
  while [ "$_RCC_DIR" != "/" ]; do
    [ -f "$_RCC_DIR/prdx.json" ] && CONFIG_FILE="$_RCC_DIR/prdx.json" && break
    [ -f "$_RCC_DIR/.prdx/prdx.json" ] && CONFIG_FILE="$_RCC_DIR/.prdx/prdx.json" && break
    _RCC_DIR="$(dirname "$_RCC_DIR")"
  done
fi

# Defaults
COMMIT_FORMAT="conventional"
COAUTHOR_ENABLED=true
COAUTHOR_NAME="Claude"
COAUTHOR_EMAIL="noreply@anthropic.com"
EXTENDED_DESC_ENABLED=true
CLAUDE_LINK_ENABLED=true

# Override from config if available
if [ -n "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
  COMMIT_FORMAT=$(jq -r '.commits.format // "conventional"' "$CONFIG_FILE" 2>/dev/null)
  COAUTHOR_ENABLED=$(jq -r '.commits.coAuthor.enabled // true' "$CONFIG_FILE" 2>/dev/null)
  COAUTHOR_NAME=$(jq -r '.commits.coAuthor.name // "Claude"' "$CONFIG_FILE" 2>/dev/null)
  COAUTHOR_EMAIL=$(jq -r '.commits.coAuthor.email // "noreply@anthropic.com"' "$CONFIG_FILE" 2>/dev/null)
  EXTENDED_DESC_ENABLED=$(jq -r '.commits.extendedDescription.enabled // true' "$CONFIG_FILE" 2>/dev/null)
  CLAUDE_LINK_ENABLED=$(jq -r '.commits.extendedDescription.includeClaudeCodeLink // true' "$CONFIG_FILE" 2>/dev/null)
fi
