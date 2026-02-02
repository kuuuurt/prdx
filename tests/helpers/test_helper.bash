#!/bin/bash
# Test helper functions for PRDX testing

# Setup function - runs before each test
setup() {
    # Create temporary directory for test isolation
    export TEST_TEMP_DIR="/Users/kuuurt/Documents/Work/personal/prdx/tests/tmp"
    mkdir -p "$TEST_TEMP_DIR"

    # Set up test plans directory (mimicking ~/.claude/plans/)
    export TEST_PLANS_DIR="$TEST_TEMP_DIR/.claude/plans"
    mkdir -p "$TEST_PLANS_DIR"

    # Store original HOME and replace with test directory
    export ORIGINAL_HOME="$HOME"

    # Set REPO_ROOT for accessing fixtures
    export REPO_ROOT="/Users/kuuurt/Documents/Work/personal/prdx"
    export FIXTURES_DIR="$REPO_ROOT/tests/fixtures"
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
