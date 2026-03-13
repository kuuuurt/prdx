#!/bin/bash
# resolve-plans-dir.sh
# Helper that resolves the PRDX plans directory.
# Source this file; do NOT execute it directly.
#
# Usage:
#   source "$(dirname "$0")/resolve-plans-dir.sh"
#   PLANS_DIR="$(resolve_plans_dir)"

resolve_plans_dir() {
    local settings_file
    local project_root
    local plans_dir

    # Allow callers (and tests) to override project root detection
    if [ -n "$PRDX_PROJECT_ROOT" ]; then
        project_root="$PRDX_PROJECT_ROOT"
    elif command -v git &>/dev/null; then
        project_root="$(git rev-parse --show-toplevel 2>/dev/null)"
    fi

    # Path to the project-local Claude settings file
    if [ -n "$project_root" ]; then
        settings_file="$project_root/.claude/settings.local.json"
    fi

    # Attempt to read plansDirectory from settings using jq
    if [ -n "$settings_file" ] && [ -f "$settings_file" ] && command -v jq &>/dev/null; then
        plans_dir="$(jq -r '.plansDirectory // empty' "$settings_file" 2>/dev/null)"
    fi

    # If we got a value, expand relative paths to absolute
    if [ -n "$plans_dir" ]; then
        case "$plans_dir" in
            /*)
                # Already absolute
                echo "$plans_dir"
                ;;
            *)
                # Relative — expand against project root
                if [ -n "$project_root" ]; then
                    echo "$project_root/$plans_dir"
                else
                    # No project root available; fall through to default
                    plans_dir=""
                    echo "${HOME}/.claude/plans"
                fi
                ;;
        esac
        return
    fi

    # Default fallback
    echo "${HOME}/.claude/plans"
}
