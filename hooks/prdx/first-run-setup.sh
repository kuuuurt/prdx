#!/bin/bash
# First-run setup: creates plans directory structure and settings
# Source this file — outputs FIRST_RUN=true if setup was performed
#
# Usage:
#   source "$(dirname "$0")/first-run-setup.sh"
#
# Requires: PROJECT_ROOT, PLANS_DIR, PLANS_SUBDIR (source resolve-plans-dir.sh first)

FIRST_RUN=false

# CI mode skips setup
if [ "${CI_MODE}" = "true" ]; then
  return 0 2>/dev/null || exit 0
fi

if [ ! -f "${PROJECT_ROOT:-.}/.prdx/plans-setup-done" ]; then
  FIRST_RUN=true
  mkdir -p "${PROJECT_ROOT:-.}/.claude" "${PROJECT_ROOT:-.}/.prdx" "${PLANS_DIR:-.prdx/plans}"
  _SETTINGS="${PROJECT_ROOT:-.}/.claude/settings.local.json"
  if [ -f "$_SETTINGS" ] && command -v jq &>/dev/null; then
    jq --arg dir "${PLANS_SUBDIR:-.prdx/plans}" '. + {plansDirectory: $dir}' "$_SETTINGS" > "$_SETTINGS.tmp" && mv "$_SETTINGS.tmp" "$_SETTINGS"
  elif [ ! -f "$_SETTINGS" ]; then
    echo "{\"plansDirectory\": \"${PLANS_SUBDIR:-.prdx/plans}\"}" > "$_SETTINGS"
  fi
  echo "local" > "${PROJECT_ROOT:-.}/.prdx/plans-setup-done"
fi
