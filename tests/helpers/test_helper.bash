#!/bin/bash
# Test helper functions for PRDX testing

# Setup function - runs before each test
setup() {
    # Determine repo root from this script's location
    # BATS_TEST_DIRNAME is the directory containing the .bats file
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    export FIXTURES_DIR="$REPO_ROOT/tests/fixtures"

    # Create temporary directory for test isolation (use mktemp for portability)
    export TEST_TEMP_DIR="$(mktemp -d)"

    # Set up test plans directory (project-local)
    export TEST_PLANS_DIR="$TEST_TEMP_DIR/.prdx/plans"
    mkdir -p "$TEST_PLANS_DIR"

    # Point hooks at the temp dir as the project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Store original HOME
    export ORIGINAL_HOME="$HOME"
}

# Teardown function - runs after each test
teardown() {
    # Clean up temporary directory
    if [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi

    # Restore HOME
    if [ -n "$ORIGINAL_HOME" ]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

# Helper: Copy fixture to test plans directory
copy_fixture_to_plans() {
    local fixture_name="$1"
    local target_name="${2:-prdx-$fixture_name}"

    cp "$FIXTURES_DIR/$fixture_name.md" "$TEST_PLANS_DIR/$target_name.md"
}

# Helper: Run hook script with error handling
run_hook() {
    local hook_name="$1"
    shift
    local hook_path="$REPO_ROOT/hooks/prdx/$hook_name.sh"

    if [ ! -f "$hook_path" ]; then
        echo "Hook not found: $hook_path"
        return 1
    fi

    bash "$hook_path" "$@"
}

# Helper: Extract status from PRD file
get_prd_status() {
    local prd_file="$1"
    grep "^\*\*Status:\*\*" "$prd_file" | sed 's/\*\*Status:\*\* //' || echo ""
}

# Helper: Check if PRD has required section
has_section() {
    local prd_file="$1"
    local section="$2"
    grep -q "$section" "$prd_file"
}

# Helper: Count decision gates in a file
count_decision_gates() {
    local file="$1"
    grep -c "AskUserQuestion" "$file" 2>/dev/null || echo "0"
}

# Helper: Check if file contains text
contains_text() {
    local file="$1"
    local text="$2"
    grep -q "$text" "$file"
}
