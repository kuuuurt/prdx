#!/usr/bin/env bats
# Tests for PRDX command structure and decision gates

load helpers/test_helper

@test "prdx.md contains post-plan decision gate" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should have decision gate after planning completes
    run grep -A 3 "After plan mode completes" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should mention AskUserQuestion
    run grep "AskUserQuestion" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should have Publish/Implement/Stop options
    run grep -E "(Publish to GitHub|Implement now|Stop here)" "$prdx_cmd"
    [ "$status" -eq 0 ]
}

@test "prdx.md contains post-implement decision gate" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should have decision gate after implementation
    run grep -A 3 "After implementation completes" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should have Test first/Create PR options
    run grep -E "(Test first|Create PR now)" "$prdx_cmd"
    [ "$status" -eq 0 ]
}

@test "prdx.md contains review status decision gate" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should have Step 3a for review status
    run grep "Step 3a: Review Status Decision" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should have Create PR/Fix issues/View summary options
    run grep -E "(Create PR|Fix issues|View implementation summary)" "$prdx_cmd"
    [ "$status" -eq 0 ]
}

@test "prdx.md contains push confirmation gate" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should have confirmation before creating PR
    run grep -A 5 "Step 4: Create Pull Request" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should confirm before running push
    run grep "Confirm before creating PR" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should have Yes/No options
    run grep -E "(Yes, create PR|No, wait)" "$prdx_cmd"
    [ "$status" -eq 0 ]
}

@test "prdx.md contains multi-platform decision gate" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should have decision gate between platforms
    run grep "more platforms remain" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should have Continue/Stop/Skip options
    run grep -E "(Continue to \{next_platform\}|Stop here|Skip \{next_platform\})" "$prdx_cmd"
    [ "$status" -eq 0 ]
}

@test "prdx.md contains publish decision gate" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should have decision after publish
    run grep -A 3 "After issue is created" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should have Yes/No implementation options
    run grep -E "(Yes, start implementation|No, I'll implement later)" "$prdx_cmd"
    [ "$status" -eq 0 ]
}

@test "prdx.md has at least 6 decision gates" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Count AskUserQuestion mentions
    local count=$(grep -c "AskUserQuestion" "$prdx_cmd")

    # Should have at least 6 decision gates
    [ "$count" -ge 6 ]
}

@test "prdx.md enforces STOP at each decision point" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should explicitly say STOP
    run grep -i "STOP" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should mention never auto-proceed
    run grep -i "never.*auto-proceed" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should mention always use AskUserQuestion
    run grep -i "ALWAYS use AskUserQuestion" "$prdx_cmd"
    [ "$status" -eq 0 ]
}

@test "implement.md calls hooks correctly" {
    local impl_cmd="$REPO_ROOT/commands/implement.md"

    # Should call pre-implement hook
    run grep "pre-implement" "$impl_cmd"
    [ "$status" -eq 0 ]

    # Should call post-implement hook
    run grep "post-implement" "$impl_cmd"
    [ "$status" -eq 0 ]
}

@test "push.md has status transition to implemented" {
    local push_cmd="$REPO_ROOT/commands/push.md"

    # Should update status to implemented
    run grep -i "status.*implemented" "$push_cmd"
    [ "$status" -eq 0 ]
}

@test "all decision gates use AskUserQuestion pattern" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Extract all AskUserQuestion sections
    local gates=$(grep -B 2 -A 5 "AskUserQuestion" "$prdx_cmd")

    # Each gate should have options
    echo "$gates" | grep -q "Option"
    [ "$?" -eq 0 ]
}
