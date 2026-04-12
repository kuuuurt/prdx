#!/usr/bin/env bats
# Tests for PRDX hook validation logic

load helpers/test_helper

@test "pre-implement hook rejects missing Goal section" {
    # Copy fixture without Goal to test plans dir
    copy_fixture_to_plans "missing-goal" "prdx-test-missing-goal"

    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Run pre-implement hook - should fail
    run run_hook "pre-implement" "test-missing-goal"

    # Should fail with non-zero exit code
    [ "$status" -ne 0 ]

    # Should mention missing Goal
    echo "$output" | grep -q "Missing required section.*Goal"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook rejects missing Acceptance Criteria section" {
    # Copy fixture without Acceptance Criteria
    copy_fixture_to_plans "missing-criteria" "prdx-test-missing-criteria"

    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Run pre-implement hook - should fail
    run run_hook "pre-implement" "test-missing-criteria"

    # Should fail
    [ "$status" -ne 0 ]

    # Should mention missing Acceptance Criteria
    echo "$output" | grep -q "Missing required section.*Acceptance Criteria"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook rejects missing Approach section" {
    # Copy fixture without Approach
    copy_fixture_to_plans "missing-approach" "prdx-test-missing-approach"

    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Run pre-implement hook - should fail
    run run_hook "pre-implement" "test-missing-approach"

    # Should fail
    [ "$status" -ne 0 ]

    # Should mention missing Approach
    echo "$output" | grep -q "Missing required section.*Approach"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook accepts valid PRD" {
    # Copy valid fixture
    copy_fixture_to_plans "valid-prd" "prdx-test-valid"

    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Run pre-implement hook with "y" input for uncommitted changes prompt
    run bash -c "echo 'y' | bash $REPO_ROOT/hooks/prdx/pre-implement.sh test-valid"

    # Should succeed
    [ "$status" -eq 0 ]

    # Should mention validation passed
    echo "$output" | grep -q "PRD validation passed"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook rejects completed PRD" {
    # Copy completed status fixture
    copy_fixture_to_plans "status-completed" "prdx-test-completed"

    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Run pre-implement hook - should fail
    run run_hook "pre-implement" "test-completed"

    # Should fail
    [ "$status" -ne 0 ]

    # Should mention PRD is completed
    echo "$output" | grep -q "already completed"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook fails when PRD not found" {
    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Run pre-implement hook with non-existent PRD
    run run_hook "pre-implement" "nonexistent-prd"

    # Should fail
    [ "$status" -ne 0 ]

    # Should mention PRD not found
    echo "$output" | grep -q "PRD not found"
    [ "$?" -eq 0 ]
}

@test "post-implement hook updates status to review" {
    # Copy valid fixture
    copy_fixture_to_plans "valid-prd" "prdx-test-post-impl"

    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    local prd_file="$TEST_PLANS_DIR/prdx-test-post-impl.md"

    # Initial status should be planning
    local initial_status=$(get_prd_status "$prd_file")
    [ "$initial_status" = "planning" ]

    # Run post-implement hook
    run run_hook "post-implement" "test-post-impl"

    # Should succeed
    [ "$status" -eq 0 ]

    # Status should now be review
    local new_status=$(get_prd_status "$prd_file")
    [ "$new_status" = "review" ]
}

@test "post-implement hook outputs helpful message" {
    # Copy valid fixture
    copy_fixture_to_plans "valid-prd" "prdx-test-msg"

    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Run post-implement hook
    run run_hook "post-implement" "test-msg"

    # Should mention status update
    echo "$output" | grep -q "Updated PRD status to 'review'"
    [ "$?" -eq 0 ]

    # Should mention next step
    echo "$output" | grep -q "/prdx:push"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook validates all required sections" {
    # Test that the hook checks for all three required sections
    local hook_file="$REPO_ROOT/hooks/prdx/pre-implement.sh"

    # Should check for Goal
    grep -q "## Goal" "$hook_file"
    [ "$?" -eq 0 ]

    # Should check for Acceptance Criteria
    grep -q "## Acceptance Criteria" "$hook_file"
    [ "$?" -eq 0 ]

    # Should check for Approach
    grep -q "## Approach" "$hook_file"
    [ "$?" -eq 0 ]
}

@test "hooks use correct PRD file naming pattern" {
    local pre_hook="$REPO_ROOT/hooks/prdx/pre-implement.sh"
    local post_hook="$REPO_ROOT/hooks/prdx/post-implement.sh"

    # Should look for prdx-* pattern
    grep -q "prdx-" "$pre_hook"
    [ "$?" -eq 0 ]

    grep -q "prdx-" "$post_hook"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook supports project-scoped PRD listing" {
    local pre_hook="$REPO_ROOT/hooks/prdx/pre-implement.sh"

    # Should detect project name
    grep -q "PROJECT_NAME" "$pre_hook"
    [ "$?" -eq 0 ]

    # Should filter by Project field when listing
    grep -q "Project" "$pre_hook"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook has unprefixed fallback" {
    local pre_hook="$REPO_ROOT/hooks/prdx/pre-implement.sh"

    # Should have fallback for plans without prdx- prefix (uses $PLANS_DIR)
    grep -qE 'PLANS_DIR.*PRD_SLUG.*\.md|plans/.*PRD_SLUG.*\.md' "$pre_hook"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook accepts PRD with free-form platform: python" {
    # Copy fixture with python platform value
    copy_fixture_to_plans "platform-python" "prdx-test-python"

    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Run pre-implement hook - should succeed
    run bash -c "echo 'y' | bash $REPO_ROOT/hooks/prdx/pre-implement.sh test-python"

    # Should succeed
    [ "$status" -eq 0 ]

    # Should mention validation passed
    echo "$output" | grep -q "PRD validation passed"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook accepts PRD with free-form platform: flutter" {
    # Copy fixture with flutter platform value
    copy_fixture_to_plans "platform-flutter" "prdx-test-flutter"

    # Point hooks at the test project root
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Run pre-implement hook - should succeed
    run bash -c "echo 'y' | bash $REPO_ROOT/hooks/prdx/pre-implement.sh test-flutter"

    # Should succeed
    [ "$status" -eq 0 ]

    # Should mention validation passed
    echo "$output" | grep -q "PRD validation passed"
    [ "$?" -eq 0 ]
}

# ============================================================
# resolve-slug.sh tests
# ============================================================

@test "resolve-slug: exact prefixed match sets RESOLVED_SLUG and PRD_FILE" {
    copy_fixture_to_plans "valid-prd" "prdx-my-feature"
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-slug.sh" my-feature
        echo "SLUG=$RESOLVED_SLUG"
        echo "FILE=$PRD_FILE"
        echo "RENAMED=$RENAMED"
    '

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SLUG=my-feature"
    echo "$output" | grep -q "FILE=.*prdx-my-feature.md"
    echo "$output" | grep -q "RENAMED=false"
}

@test "resolve-slug: exact unprefixed match auto-renames file and sets RENAMED=true" {
    copy_fixture_to_plans "valid-prd" "unprefixed-plan"
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-slug.sh" unprefixed-plan
        echo "SLUG=$RESOLVED_SLUG"
        echo "RENAMED=$RENAMED"
        [ -f "$PLANS_DIR/prdx-unprefixed-plan.md" ] && echo "FILE_EXISTS=true"
        [ ! -f "$PLANS_DIR/unprefixed-plan.md" ] && echo "OLD_GONE=true"
    '

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SLUG=unprefixed-plan"
    echo "$output" | grep -q "RENAMED=true"
    echo "$output" | grep -q "FILE_EXISTS=true"
    echo "$output" | grep -q "OLD_GONE=true"
}

@test "resolve-slug: substring match resolves correct slug" {
    copy_fixture_to_plans "valid-prd" "prdx-backend-auth-refresh"
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-slug.sh" auth-refresh
        echo "SLUG=$RESOLVED_SLUG"
    '

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SLUG=backend-auth-refresh"
}

@test "resolve-slug: word-boundary match finds PRD containing all words" {
    copy_fixture_to_plans "valid-prd" "prdx-backend-auth-refresh"
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-slug.sh" auth
        echo "SLUG=$RESOLVED_SLUG"
    '

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SLUG=backend-auth-refresh"
}

@test "resolve-slug: ambiguous match exits 1 and prints listing" {
    copy_fixture_to_plans "valid-prd" "prdx-backend-auth"
    copy_fixture_to_plans "valid-prd" "prdx-backend-auth-refresh"
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    # Use "auth" as slug — it won't match either exactly, so substring step finds both
    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-slug.sh" auth 2>&1 || exit 1
        echo "RESOLVED=$RESOLVED_SLUG"
    '

    [ "$status" -ne 0 ]
    echo "$output" | grep -qE "Multiple|backend-auth"
}

@test "resolve-slug: not found exits 1 and lists available PRDs" {
    copy_fixture_to_plans "valid-prd" "prdx-other-feature"
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-slug.sh" nonexistent-xyz 2>&1
        echo "SLUG=$RESOLVED_SLUG"
    '

    [ "$status" -ne 0 ] || echo "$output" | grep -q "SLUG=$"
    echo "$output" | grep -qiE "not found|Available|other-feature"
}

@test "resolve-slug: PLANS_DIR unset exits 1 with error message" {
    run bash -c '
        unset PLANS_DIR
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-slug.sh" some-slug 2>&1
        echo "exit=$?"
    '

    echo "$output" | grep -qE "PLANS_DIR|resolve-plans-dir"
}

# ============================================================
# read-state.sh tests
# ============================================================

@test "read-state: present state file with all keys sets all STATE_* vars" {
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.prdx/state"
    cat > "$TEST_TEMP_DIR/.prdx/state/my-feature.json" <<'EOF'
{"slug": "my-feature", "phase": "in-progress", "quick": false, "parent": "parent-prd", "pr_number": 42}
EOF

    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/read-state.sh" my-feature
        echo "PHASE=$STATE_PHASE"
        echo "QUICK=$STATE_QUICK"
        echo "PARENT=$STATE_PARENT"
        echo "PR=$STATE_PR_NUMBER"
    '

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE=in-progress"
    echo "$output" | grep -q "QUICK=false"
    echo "$output" | grep -q "PARENT=parent-prd"
    echo "$output" | grep -q "PR=42"
}

@test "read-state: present state file missing optional keys leaves those vars empty" {
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.prdx/state"
    cat > "$TEST_TEMP_DIR/.prdx/state/simple-feature.json" <<'EOF'
{"slug": "simple-feature", "phase": "review", "quick": false}
EOF

    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/read-state.sh" simple-feature
        echo "PHASE=$STATE_PHASE"
        echo "PARENT=$STATE_PARENT"
        echo "PR=$STATE_PR_NUMBER"
    '

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE=review"
    echo "$output" | grep -q "PARENT=$"
    echo "$output" | grep -q "PR=$"
}

@test "read-state: absent state file sets all STATE_* vars empty and exits 0" {
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"

    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/read-state.sh" nonexistent-slug
        echo "PHASE=$STATE_PHASE"
        echo "PARENT=$STATE_PARENT"
        echo "PR=$STATE_PR_NUMBER"
    '

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE=$"
    echo "$output" | grep -q "PARENT=$"
    echo "$output" | grep -q "PR=$"
}

@test "read-state: malformed JSON sets all STATE_* vars empty and exits 0 with warning" {
    export PRDX_PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.prdx/state"
    echo "{ not valid json ::::" > "$TEST_TEMP_DIR/.prdx/state/broken-feature.json"

    run bash -c '
        source "'"$REPO_ROOT"'/hooks/prdx/resolve-plans-dir.sh"
        source "'"$REPO_ROOT"'/hooks/prdx/read-state.sh" broken-feature 2>&1
        echo "PHASE=$STATE_PHASE"
        echo "PR=$STATE_PR_NUMBER"
    '

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE=$"
    echo "$output" | grep -q "PR=$"
    echo "$output" | grep -qi "warning\|malformed"
}
