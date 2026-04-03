#!/bin/bash
# Shared DEFAULT_BRANCH resolution library
# Source this file to set DEFAULT_BRANCH
#
# Usage:
#   source "$(dirname "$0")/resolve-default-branch.sh"
#
# Reads from prdx.json defaultBranch, falls back to git symbolic-ref, then 'main'

# Find config file (reuse resolve-plans-dir.sh if already sourced, else walk up)
if [ -z "$CONFIG_FILE" ]; then
  _RDB_DIR="${PRDX_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  while [ "$_RDB_DIR" != "/" ]; do
    [ -f "$_RDB_DIR/prdx.json" ] && CONFIG_FILE="$_RDB_DIR/prdx.json" && break
    [ -f "$_RDB_DIR/.prdx/prdx.json" ] && CONFIG_FILE="$_RDB_DIR/.prdx/prdx.json" && break
    _RDB_DIR="$(dirname "$_RDB_DIR")"
  done
fi

DEFAULT_BRANCH=""
if [ -n "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
  DEFAULT_BRANCH=$(jq -r '.pullRequest.defaultBase // .defaultBranch // ""' "$CONFIG_FILE" 2>/dev/null)
fi
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
fi
