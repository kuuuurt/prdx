#!/bin/bash
# Pre-push validation hook
# Runs typecheck → lint → tests before /prdx:push creates a PR.
# Skips silently when no runner is detected for a phase.
# Bypasses entirely on PRDX_SKIP_PREPUSH=1 or CI=true.

set -e

# shellcheck source=discover-commands.sh
source "$(dirname "$0")/discover-commands.sh"

if [ "$PRDX_SKIP_PREPUSH" = "1" ]; then
    echo "Pre-push validation skipped (PRDX_SKIP_PREPUSH=1)"
    exit 0
fi

if [ "$CI" = "true" ]; then
    echo "Pre-push validation skipped (CI=true)"
    exit 0
fi

run_phase() {
    local label="$1"
    local cmd="$2"

    if [ -z "$cmd" ]; then
        echo "${label}: no runner detected, skipping"
        return 0
    fi

    echo "${label}: $cmd"
    if ! eval "$cmd" 2>&1; then
        echo ""
        echo "${label} failed — fix before pushing, or bypass with PRDX_SKIP_PREPUSH=1 (or --skip-validation)"
        exit 1
    fi
    echo "${label} passed"
}

echo "Running pre-push validation..."

run_phase "Typecheck" "$(discover_typecheck_cmd)"
run_phase "Lint"      "$(discover_lint_cmd)"
run_phase "Tests"     "$(discover_test_cmd)"

echo "Pre-push validation passed"
exit 0
