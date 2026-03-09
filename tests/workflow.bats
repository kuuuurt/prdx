#!/usr/bin/env bats
# Tests for PRDX workflow status transitions

load helpers/test_helper

@test "status transitions from planning to in-progress" {
    # The pre-implement hook should allow planning status
    copy_fixture_to_plans "status-planning" "prdx-workflow-planning"

    HOME="$TEST_TEMP_DIR"

    # Should pass validation (provide 'y' for uncommitted changes prompt)
    run bash -c "echo 'y' | bash $REPO_ROOT/hooks/prdx/pre-implement.sh workflow-planning"
    [ "$status" -eq 0 ]

    # In real workflow, implement.md would update to in-progress
    # We're just testing that planning is allowed
}

@test "status transitions from in-progress to review" {
    # Copy in-progress fixture
    copy_fixture_to_plans "status-in-progress" "prdx-workflow-progress"

    HOME="$TEST_TEMP_DIR"

    local prd_file="$TEST_PLANS_DIR/prdx-workflow-progress.md"

    # Status should be in-progress
    local initial_status=$(get_prd_status "$prd_file")
    [ "$initial_status" = "in-progress" ]

    # Run post-implement hook
    run run_hook "post-implement" "workflow-progress"
    [ "$status" -eq 0 ]

    # Status should now be review
    local new_status=$(get_prd_status "$prd_file")
    [ "$new_status" = "review" ]
}

@test "review status is valid for pre-implement" {
    # Copy review fixture
    copy_fixture_to_plans "status-review" "prdx-workflow-review"

    HOME="$TEST_TEMP_DIR"

    # Pre-implement should accept review status (for bug fixes)
    run bash -c "echo 'y' | bash $REPO_ROOT/hooks/prdx/pre-implement.sh workflow-review"
    [ "$status" -eq 0 ]
}

@test "completed status is rejected by pre-implement" {
    # Copy completed fixture
    copy_fixture_to_plans "status-completed" "prdx-workflow-completed"

    HOME="$TEST_TEMP_DIR"

    # Pre-implement should reject completed status
    run run_hook "pre-implement" "workflow-completed"
    [ "$status" -ne 0 ]

    # Should mention cannot implement
    echo "$output" | grep -q "Cannot implement"
    [ "$?" -eq 0 ]
}

@test "post-implement updates any status to review" {
    # Test with planning status
    copy_fixture_to_plans "status-planning" "prdx-workflow-any"

    HOME="$TEST_TEMP_DIR"

    local prd_file="$TEST_PLANS_DIR/prdx-workflow-any.md"

    # Run post-implement
    run run_hook "post-implement" "workflow-any"
    [ "$status" -eq 0 ]

    # Should be review regardless of initial status
    local new_status=$(get_prd_status "$prd_file")
    [ "$new_status" = "review" ]
}

@test "workflow enforces review before implemented" {
    # The workflow requires review status before push
    # This is enforced by post-implement always setting to review
    copy_fixture_to_plans "status-in-progress" "prdx-workflow-enforce"

    HOME="$TEST_TEMP_DIR"

    local prd_file="$TEST_PLANS_DIR/prdx-workflow-enforce.md"

    # After post-implement, must be review
    run run_hook "post-implement" "workflow-enforce"
    [ "$status" -eq 0 ]

    local status=$(get_prd_status "$prd_file")
    [ "$status" = "review" ]

    # Cannot skip to implemented without user confirmation
    # (push.md handles the review -> implemented transition)
}

@test "PRD status field is correctly formatted" {
    # Status should be in format: **Status:** <value>
    copy_fixture_to_plans "valid-prd" "prdx-workflow-format"

    HOME="$TEST_TEMP_DIR"

    local prd_file="$TEST_PLANS_DIR/prdx-workflow-format.md"

    # Should match the pattern
    grep -q "^\*\*Status:\*\* " "$prd_file"
    [ "$?" -eq 0 ]

    # Status extraction should work
    local status=$(get_prd_status "$prd_file")
    [ -n "$status" ]
}

@test "multiple status transitions maintain PRD integrity" {
    # Test that status can be changed multiple times
    copy_fixture_to_plans "valid-prd" "prdx-workflow-multiple"

    HOME="$TEST_TEMP_DIR"

    local prd_file="$TEST_PLANS_DIR/prdx-workflow-multiple.md"

    # Initial: planning
    local status=$(get_prd_status "$prd_file")
    [ "$status" = "planning" ]

    # After implementation: review
    run run_hook "post-implement" "workflow-multiple"
    [ "$status" -eq 0 ]

    status=$(get_prd_status "$prd_file")
    [ "$status" = "review" ]

    # Can run post-implement again (for bug fixes)
    run run_hook "post-implement" "workflow-multiple"
    [ "$status" -eq 0 ]

    status=$(get_prd_status "$prd_file")
    [ "$status" = "review" ]

    # File should still be valid
    has_section "$prd_file" "## Goal"
    [ "$?" -eq 0 ]
}

@test "status workflow is documented in prdx.md" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should document status flow
    grep -q "planning.*in-progress.*review.*implemented.*completed" "$prdx_cmd"
    [ "$?" -eq 0 ]
}

@test "PRD Project field is correctly formatted" {
    copy_fixture_to_plans "valid-prd" "prdx-workflow-project"

    HOME="$TEST_TEMP_DIR"

    local prd_file="$TEST_PLANS_DIR/prdx-workflow-project.md"

    # Should have Project field
    grep -q "^\*\*Project:\*\*" "$prd_file"
    [ "$?" -eq 0 ]

    # Project extraction should work
    local project=$(grep "^\*\*Project:\*\*" "$prd_file" | sed 's/\*\*Project:\*\* //')
    [ -n "$project" ]
    [ "$project" = "test-project" ]
}

@test "closed status is also rejected by pre-implement" {
    # Create a fixture with closed status
    copy_fixture_to_plans "valid-prd" "prdx-workflow-closed"

    HOME="$TEST_TEMP_DIR"

    local prd_file="$TEST_PLANS_DIR/prdx-workflow-closed.md"

    # Change status to closed
    sed -i.bak 's/^\*\*Status:\*\* .*/\*\*Status:\*\* closed/' "$prd_file"

    # Pre-implement should reject closed status
    run run_hook "pre-implement" "workflow-closed"
    [ "$status" -ne 0 ]
}
