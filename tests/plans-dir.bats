#!/usr/bin/env bats
# Tests for resolve-plans-dir.sh helper

load helpers/test_helper

# ---------------------------------------------------------------------------
# Helper: invoke resolve_plans_dir in an isolated subshell.
#
# Uses PRDX_PROJECT_ROOT to point the helper at a temp directory, avoiding
# any dependency on a real git repository.
# ---------------------------------------------------------------------------
run_resolve() {
    local fake_root="$1"          # directory that acts as the project root
    local settings_content="$2"  # JSON string; empty → no settings file written
    local jq_available="${3:-yes}"

    # Write settings file when content provided
    if [ -n "$settings_content" ]; then
        mkdir -p "$fake_root/.claude"
        printf '%s\n' "$settings_content" > "$fake_root/.claude/settings.local.json"
    fi

    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"

    if [ "$jq_available" = "no" ]; then
        # Stub jq that always exits non-zero
        local fake_bin
        fake_bin="$(mktemp -d "$TEST_TEMP_DIR/fakebin.XXXXXX")"
        printf '#!/bin/bash\nexit 127\n' > "$fake_bin/jq"
        chmod +x "$fake_bin/jq"

        printf '#!/bin/bash\nexport PATH="%s:$PATH"\nexport PRDX_PROJECT_ROOT="%s"\nsource "%s"\nresolve_plans_dir\n' \
            "$fake_bin" "$fake_root" "$REPO_ROOT/hooks/prdx/resolve-plans-dir.sh" > "$driver"
    else
        printf '#!/bin/bash\nexport PRDX_PROJECT_ROOT="%s"\nsource "%s"\nresolve_plans_dir\n' \
            "$fake_root" "$REPO_ROOT/hooks/prdx/resolve-plans-dir.sh" > "$driver"
    fi

    chmod +x "$driver"
    run bash "$driver"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "resolves plansDirectory when set to relative path" {
    local fake_root="$TEST_TEMP_DIR/project"
    mkdir -p "$fake_root"
    run_resolve "$fake_root" '{"plansDirectory": ".prdx/plans"}'

    [ "$status" -eq 0 ]
    [ "$output" = "$fake_root/.prdx/plans" ]
}

@test "falls back to ~/.claude/plans when plansDirectory key is absent" {
    local fake_root="$TEST_TEMP_DIR/project"
    mkdir -p "$fake_root"
    run_resolve "$fake_root" '{}'

    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.claude/plans" ]
}

@test "falls back to ~/.claude/plans when settings file does not exist" {
    local fake_root="$TEST_TEMP_DIR/project"
    mkdir -p "$fake_root"
    # Pass empty string so no settings file is written
    run_resolve "$fake_root" ""

    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.claude/plans" ]
}

@test "falls back to ~/.claude/plans when jq is unavailable" {
    local fake_root="$TEST_TEMP_DIR/project"
    mkdir -p "$fake_root"
    run_resolve "$fake_root" '{"plansDirectory": ".prdx/plans"}' "no"

    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.claude/plans" ]
}

@test "returns absolute path unchanged when plansDirectory is absolute" {
    local fake_root="$TEST_TEMP_DIR/project"
    local abs_plans="/tmp/my-custom-plans"
    mkdir -p "$fake_root"
    run_resolve "$fake_root" "{\"plansDirectory\": \"$abs_plans\"}"

    [ "$status" -eq 0 ]
    [ "$output" = "$abs_plans" ]
}
