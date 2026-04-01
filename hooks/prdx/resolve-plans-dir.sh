#!/bin/bash
# Shared PLANS_DIR resolution library
# Source this file to set PROJECT_ROOT, CONFIG_FILE, and PLANS_DIR
#
# Usage:
#   source "$(dirname "$0")/resolve-plans-dir.sh"

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
