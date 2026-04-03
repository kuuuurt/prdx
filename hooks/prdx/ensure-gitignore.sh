#!/bin/bash
# Ensure .prdx/ is in .gitignore
# Source this file — no arguments needed
#
# Usage:
#   source "$(dirname "$0")/ensure-gitignore.sh"

_PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
_GITIGNORE="$_PROJECT_ROOT/.gitignore"

if [ ! -f "$_GITIGNORE" ] || ! { grep -qxF '.prdx/' "$_GITIGNORE" || grep -qxF '.prdx/*' "$_GITIGNORE"; }; then
  echo '' >> "$_GITIGNORE"
  echo '# PRDX' >> "$_GITIGNORE"
  echo '.prdx/' >> "$_GITIGNORE"
fi
