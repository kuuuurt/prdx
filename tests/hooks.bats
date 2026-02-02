#!/usr/bin/env bats
# Tests for PRDX hook validation logic

load helpers/test_helper

@test "pre-implement hook rejects missing Goal section" {
    # Copy fixture without Goal to test plans dir
    copy_fixture_to_plans "missing-goal" "prdx-test-missing-goal"

    # Change HOME to use test plans directory
    HOME="$TEST_TEMP_DIR"

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

    # Change HOME to use test plans directory
    HOME="$TEST_TEMP_DIR"

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

    # Change HOME to use test plans directory
    HOME="$TEST_TEMP_DIR"

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

    # Change HOME to use test plans directory
    HOME="$TEST_TEMP_DIR"

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

    # Change HOME to use test plans directory
    HOME="$TEST_TEMP_DIR"

    # Run pre-implement hook - should fail
    run run_hook "pre-implement" "test-completed"

    # Should fail
    [ "$status" -ne 0 ]

    # Should mention PRD is completed
    echo "$output" | grep -q "already completed"
    [ "$?" -eq 0 ]
}

@test "pre-implement hook fails when PRD not found" {
    # Change HOME to use test plans directory
    HOME="$TEST_TEMP_DIR"

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

    # Change HOME to use test plans directory
    HOME="$TEST_TEMP_DIR"

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

    # Change HOME to use test plans directory
    HOME="$TEST_TEMP_DIR"

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
