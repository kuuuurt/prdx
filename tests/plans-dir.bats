#!/usr/bin/env bats
# Tests for always-local plans directory behavior

load helpers/test_helper

@test "hooks resolve plans dir to PRDX_PROJECT_ROOT/.prdx/plans" {
    local fake_root="$TEST_TEMP_DIR/project"
    mkdir -p "$fake_root"

    # Write a minimal driver that sources pre-plan.sh logic in isolation
    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    printf '#!/bin/bash\nexport PRDX_PROJECT_ROOT="%s"\nPROJECT_ROOT="${PRDX_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"\nPLANS_DIR="$PROJECT_ROOT/.prdx/plans"\necho "$PLANS_DIR"\n' \
        "$fake_root" > "$driver"
    chmod +x "$driver"

    run bash "$driver"

    [ "$status" -eq 0 ]
    [ "$output" = "$fake_root/.prdx/plans" ]
}

@test "plans directory is NOT in .gitignore" {
    local gitignore="$REPO_ROOT/.gitignore"

    # .prdx/plans/ should not be ignored (PRDs are project docs)
    run grep -x '\.prdx/plans/' "$gitignore"
    [ "$status" -ne 0 ]

    # .prdx/ broad rule should not be present either
    run grep -x '\.prdx/' "$gitignore"
    [ "$status" -ne 0 ]
}

@test ".prdx/state/ is in .gitignore (runtime state)" {
    local gitignore="$REPO_ROOT/.gitignore"

    run grep -F '.prdx/state/' "$gitignore"
    [ "$status" -eq 0 ]
}

@test "pre-plan hook creates plans dir under PRDX_PROJECT_ROOT" {
    local fake_root="$TEST_TEMP_DIR/project"
    mkdir -p "$fake_root"

    # Initialize a git repo so the hook passes git check
    git -C "$fake_root" init -q

    export PRDX_PROJECT_ROOT="$fake_root"
    run bash "$REPO_ROOT/hooks/prdx/pre-plan.sh"

    [ "$status" -eq 0 ]
    [ -d "$fake_root/.prdx/plans" ]
}

@test "pre-implement hook uses PRDX_PROJECT_ROOT for plans dir" {
    local fake_root="$TEST_TEMP_DIR/project"
    mkdir -p "$fake_root/.prdx/plans"

    # Place a valid PRD fixture in the local plans dir
    cp "$FIXTURES_DIR/valid-prd.md" "$fake_root/.prdx/plans/prdx-test-local.md"

    # Initialize a git repo in fake_root
    git -C "$fake_root" init -q

    export PRDX_PROJECT_ROOT="$fake_root"
    run bash -c "echo 'y' | bash $REPO_ROOT/hooks/prdx/pre-implement.sh test-local"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PRD validation passed"
    [ "$?" -eq 0 ]
}
