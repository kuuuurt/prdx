#!/usr/bin/env bats
# Tests for PRDX command structure and decision gates

load helpers/test_helper

@test "prdx.md contains post-plan decision gate" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should have post-planning decision gate via workflow.json resume
    run grep "post-planning" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should mention AskUserQuestion
    run grep "AskUserQuestion" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should have Publish/Implement/Stop options
    run grep -E "(Publish to GitHub|Implement now|Stop here)" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # plan.md should also have the decision point
    local plan_cmd="$REPO_ROOT/commands/plan.md"
    run grep "post-planning" "$plan_cmd"
    [ "$status" -eq 0 ]
}

@test "prdx.md contains post-implement decision gate" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should have post-implement state transition
    run grep "post-implement" "$prdx_cmd"
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

@test "prdx.md contains multi-platform session instructions" {
    local prdx_cmd="$REPO_ROOT/commands/prdx.md"

    # Should have parent PRD handling via separate sessions
    run grep -E "(parent PRD|Parent PRD)" "$prdx_cmd"
    [ "$status" -eq 0 ]

    # Should instruct users to open separate sessions for child PRDs
    run grep -E "(separate.*session|session.*instruction)" "$prdx_cmd"
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

@test "plan.md includes Project field in all PRD templates" {
    local plan_cmd="$REPO_ROOT/commands/plan.md"

    # Should have Project field in templates
    run grep -c "Project.*PROJECT_NAME" "$plan_cmd"
    [ "$status" -eq 0 ]
    # All 4 templates (quick, single, multi, child) should have it
    [ "${lines[0]}" -ge 4 ]
}

@test "plan.md detects project from git remote" {
    local plan_cmd="$REPO_ROOT/commands/plan.md"

    # Should detect project via gh repo view
    run grep "gh repo view.*--json name" "$plan_cmd"
    [ "$status" -eq 0 ]

    # Should have fallback to directory name
    run grep "git rev-parse --show-toplevel" "$plan_cmd"
    [ "$status" -eq 0 ]
}

@test "show.md supports --project and --all flags" {
    local show_cmd="$REPO_ROOT/commands/show.md"

    # Should support --project filter
    run grep "\-\-project" "$show_cmd"
    [ "$status" -eq 0 ]

    # Should support --all flag
    run grep "\-\-all" "$show_cmd"
    [ "$status" -eq 0 ]

    # Should filter by project by default
    run grep "scoped to project" "$show_cmd"
    [ "$status" -eq 0 ]
}

@test "PRD discovery filters by project" {
    local impl_cmd="$REPO_ROOT/commands/implement.md"

    # implement.md should grep for Project field
    run grep 'Project.*PROJECT_NAME' "$impl_cmd"
    [ "$status" -eq 0 ]
}

@test "plan.md has scope boundary preventing implementation" {
    local plan_cmd="$REPO_ROOT/commands/plan.md"

    # Should state this command only creates PRD documents
    run grep "ONLY creates a PRD document" "$plan_cmd"
    [ "$status" -eq 0 ]

    # Should clarify approval means document is ready, not start implementing
    run grep "Approval.*means.*PRD document is ready" "$plan_cmd"
    [ "$status" -eq 0 ]
}

@test "CLAUDE.md includes Project field in PRD templates" {
    local claude_md="$REPO_ROOT/CLAUDE.md"

    # Should have Project field documented
    run grep "Project.*git remote repo name" "$claude_md"
    [ "$status" -eq 0 ]

    # Should explain auto-detection
    run grep "Auto-detected.*gh repo view" "$claude_md"
    [ "$status" -eq 0 ]
}
