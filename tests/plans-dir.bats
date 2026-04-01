#!/usr/bin/env bats
# Tests for plans directory resolution behavior

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

@test ".prdx/ is fully gitignored" {
    local gitignore="$REPO_ROOT/.gitignore"

    # .prdx/ should be fully ignored
    run grep -x '\.prdx/' "$gitignore"
    [ "$status" -eq 0 ]

    # No exception for .prdx/plans/ should be present
    run grep -xF '!.prdx/plans/' "$gitignore"
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

# --- New tests for plansDirectory config support ---

@test "resolve_plans_dir uses custom plansDirectory from prdx.json" {
    local fake_root="$TEST_TEMP_DIR/custom-project"
    mkdir -p "$fake_root"

    # Write prdx.json with custom plansDirectory
    cat > "$fake_root/prdx.json" <<'EOF'
{
  "version": "1.0",
  "plansDirectory": "docs/plans",
  "commits": {
    "coAuthor": {"enabled": true},
    "extendedDescription": {"enabled": true},
    "format": "conventional"
  }
}
EOF

    # Driver using the canonical resolution snippet
    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
export PRDX_PROJECT_ROOT="$fake_root"
PROJECT_ROOT="\${PRDX_PROJECT_ROOT:-\$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE=""
SEARCH_DIR="\$PROJECT_ROOT"
while [ "\$SEARCH_DIR" != "/" ]; do
  [ -f "\$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/prdx.json" && break
  [ -f "\$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="\$(dirname "\$SEARCH_DIR")"
done
PLANS_SUBDIR=\$(jq -r '.plansDirectory // ".prdx/plans"' "\$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="\$PROJECT_ROOT/\$PLANS_SUBDIR"
echo "\$PLANS_DIR"
SCRIPT
    chmod +x "$driver"

    run bash "$driver"

    [ "$status" -eq 0 ]
    [ "$output" = "$fake_root/docs/plans" ]
}

@test "resolve_plans_dir falls back to .prdx/plans when plansDirectory not set" {
    local fake_root="$TEST_TEMP_DIR/default-project"
    mkdir -p "$fake_root"

    # Write prdx.json WITHOUT plansDirectory
    cat > "$fake_root/prdx.json" <<'EOF'
{
  "version": "1.0",
  "commits": {
    "coAuthor": {"enabled": true},
    "extendedDescription": {"enabled": true},
    "format": "conventional"
  }
}
EOF

    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
export PRDX_PROJECT_ROOT="$fake_root"
PROJECT_ROOT="\${PRDX_PROJECT_ROOT:-\$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE=""
SEARCH_DIR="\$PROJECT_ROOT"
while [ "\$SEARCH_DIR" != "/" ]; do
  [ -f "\$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/prdx.json" && break
  [ -f "\$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="\$(dirname "\$SEARCH_DIR")"
done
PLANS_SUBDIR=\$(jq -r '.plansDirectory // ".prdx/plans"' "\$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="\$PROJECT_ROOT/\$PLANS_SUBDIR"
echo "\$PLANS_DIR"
SCRIPT
    chmod +x "$driver"

    run bash "$driver"

    [ "$status" -eq 0 ]
    [ "$output" = "$fake_root/.prdx/plans" ]
}

@test "resolve_plans_dir falls back to .prdx/plans when no prdx.json exists" {
    local fake_root="$TEST_TEMP_DIR/no-config-project"
    mkdir -p "$fake_root"

    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
export PRDX_PROJECT_ROOT="$fake_root"
PROJECT_ROOT="\${PRDX_PROJECT_ROOT:-\$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE=""
SEARCH_DIR="\$PROJECT_ROOT"
while [ "\$SEARCH_DIR" != "/" ]; do
  [ -f "\$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/prdx.json" && break
  [ -f "\$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="\$(dirname "\$SEARCH_DIR")"
done
PLANS_SUBDIR=\$(jq -r '.plansDirectory // ".prdx/plans"' "\$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="\$PROJECT_ROOT/\$PLANS_SUBDIR"
echo "\$PLANS_DIR"
SCRIPT
    chmod +x "$driver"

    run bash "$driver"

    [ "$status" -eq 0 ]
    [ "$output" = "$fake_root/.prdx/plans" ]
}

@test "resolve_plans_dir finds prdx.json in .prdx/ subdirectory" {
    local fake_root="$TEST_TEMP_DIR/dotprdx-config-project"
    mkdir -p "$fake_root/.prdx"

    # Write prdx.json inside .prdx/
    cat > "$fake_root/.prdx/prdx.json" <<'EOF'
{
  "version": "1.0",
  "plansDirectory": "my-plans",
  "commits": {
    "coAuthor": {"enabled": true},
    "extendedDescription": {"enabled": true},
    "format": "conventional"
  }
}
EOF

    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
export PRDX_PROJECT_ROOT="$fake_root"
PROJECT_ROOT="\${PRDX_PROJECT_ROOT:-\$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE=""
SEARCH_DIR="\$PROJECT_ROOT"
while [ "\$SEARCH_DIR" != "/" ]; do
  [ -f "\$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/prdx.json" && break
  [ -f "\$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="\$(dirname "\$SEARCH_DIR")"
done
PLANS_SUBDIR=\$(jq -r '.plansDirectory // ".prdx/plans"' "\$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="\$PROJECT_ROOT/\$PLANS_SUBDIR"
echo "\$PLANS_DIR"
SCRIPT
    chmod +x "$driver"

    run bash "$driver"

    [ "$status" -eq 0 ]
    [ "$output" = "$fake_root/my-plans" ]
}

@test "gitignore gets .prdx/ entry" {
    local fake_root="$TEST_TEMP_DIR/gitignore-test"
    mkdir -p "$fake_root"

    local gitignore="$fake_root/.gitignore"

    # Simulate the simplified gitignore logic
    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
GITIGNORE="$gitignore"
if [ ! -f "\$GITIGNORE" ] || ! grep -qxF '.prdx/' "\$GITIGNORE"; then
  echo '' >> "\$GITIGNORE"
  echo '# PRDX' >> "\$GITIGNORE"
  echo '.prdx/' >> "\$GITIGNORE"
fi
SCRIPT
    chmod +x "$driver"
    bash "$driver"

    # Should have .prdx/ entry
    grep -qxF '.prdx/' "$gitignore"
    [ "$?" -eq 0 ]

    # Should NOT have a plans exception line
    run grep -qxF '!.prdx/plans/' "$gitignore"
    [ "$status" -ne 0 ]
}

@test "gitignore .prdx/ entry is idempotent" {
    local fake_root="$TEST_TEMP_DIR/gitignore-idempotent-test"
    mkdir -p "$fake_root"

    local gitignore="$fake_root/.gitignore"
    # Pre-populate with the entry
    printf '\n# PRDX\n.prdx/\n' > "$gitignore"

    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
GITIGNORE="$gitignore"
if [ ! -f "\$GITIGNORE" ] || ! grep -qxF '.prdx/' "\$GITIGNORE"; then
  echo '' >> "\$GITIGNORE"
  echo '# PRDX' >> "\$GITIGNORE"
  echo '.prdx/' >> "\$GITIGNORE"
fi
SCRIPT
    chmod +x "$driver"
    bash "$driver"

    # Entry appears exactly once
    local count
    count=$(grep -cxF '.prdx/' "$gitignore")
    [ "$count" -eq 1 ]
}

@test "first-run setup with custom plansDirectory creates configured dir and writes sentinel" {
    local fake_root="$TEST_TEMP_DIR/first-run-custom"
    mkdir -p "$fake_root/.prdx"
    git -C "$fake_root" init -q

    # Write prdx.json with custom plansDirectory
    cat > "$fake_root/prdx.json" <<'EOF'
{
  "version": "1.0",
  "plansDirectory": "docs/plans",
  "commits": {
    "coAuthor": {"enabled": true},
    "extendedDescription": {"enabled": true},
    "format": "conventional"
  }
}
EOF

    # No sentinel file yet (first run)

    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
set -e
export PRDX_PROJECT_ROOT="$fake_root"
PROJECT_ROOT="\${PRDX_PROJECT_ROOT:-\$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE=""
SEARCH_DIR="\$PROJECT_ROOT"
while [ "\$SEARCH_DIR" != "/" ]; do
  [ -f "\$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/prdx.json" && break
  [ -f "\$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="\$(dirname "\$SEARCH_DIR")"
done
PLANS_SUBDIR=\$(jq -r '.plansDirectory // ".prdx/plans"' "\$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="\$PROJECT_ROOT/\$PLANS_SUBDIR"

# First-run setup (sentinel absent)
if ! ls "\$PROJECT_ROOT/.prdx/plans-setup-done" 2>/dev/null; then
  mkdir -p "\$PROJECT_ROOT/.claude" "\$PROJECT_ROOT/.prdx" "\$PLANS_DIR"
  if [ -f "\$PROJECT_ROOT/.claude/settings.local.json" ]; then
    jq --arg dir "\$PLANS_SUBDIR" '. + {plansDirectory: \$dir}' "\$PROJECT_ROOT/.claude/settings.local.json" > "\$PROJECT_ROOT/.claude/settings.local.json.tmp" && mv "\$PROJECT_ROOT/.claude/settings.local.json.tmp" "\$PROJECT_ROOT/.claude/settings.local.json"
  else
    echo "{\\"plansDirectory\\": \\"\$PLANS_SUBDIR\\"}" > "\$PROJECT_ROOT/.claude/settings.local.json"
  fi
  echo "local" > "\$PROJECT_ROOT/.prdx/plans-setup-done"
fi

# Output results for assertions
echo "plans_dir:\$PLANS_DIR"
echo "sentinel:\$(cat "\$PROJECT_ROOT/.prdx/plans-setup-done")"
echo "settings_value:\$(jq -r '.plansDirectory' "\$PROJECT_ROOT/.claude/settings.local.json")"
SCRIPT
    chmod +x "$driver"

    run bash "$driver"

    [ "$status" -eq 0 ]
    # Custom directory created (not .prdx/plans)
    [ -d "$fake_root/docs/plans" ]
    # Sentinel created
    [ -f "$fake_root/.prdx/plans-setup-done" ]
    # settings.local.json has the configured value
    echo "$output" | grep -q "settings_value:docs/plans"
    [ "$?" -eq 0 ]
    # .prdx/plans should NOT have been created
    [ ! -d "$fake_root/.prdx/plans" ]
}

@test "first-run setup is skipped when sentinel already exists" {
    local fake_root="$TEST_TEMP_DIR/first-run-skip"
    mkdir -p "$fake_root/.prdx" "$fake_root/.claude"
    git -C "$fake_root" init -q

    # Pre-existing sentinel — setup should be skipped entirely
    echo "local" > "$fake_root/.prdx/plans-setup-done"
    echo '{"plansDirectory": ".prdx/plans"}' > "$fake_root/.claude/settings.local.json"

    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
export PRDX_PROJECT_ROOT="$fake_root"
PROJECT_ROOT="\${PRDX_PROJECT_ROOT:-\$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PLANS_SUBDIR=".prdx/plans"
PLANS_DIR="\$PROJECT_ROOT/\$PLANS_SUBDIR"

SETUP_RAN=0
if ! ls "\$PROJECT_ROOT/.prdx/plans-setup-done" 2>/dev/null; then
  SETUP_RAN=1
  mkdir -p "\$PLANS_DIR"
fi
echo "setup_ran:\$SETUP_RAN"
SCRIPT
    chmod +x "$driver"

    run bash "$driver"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "setup_ran:0"
    [ "$?" -eq 0 ]
}

@test "config plans local writes configured plansDirectory to settings.local.json" {
    local fake_root="$TEST_TEMP_DIR/config-plans-local"
    mkdir -p "$fake_root/.prdx" "$fake_root/.claude"

    # prdx.json with custom plansDirectory
    cat > "$fake_root/prdx.json" <<'EOF'
{
  "version": "1.0",
  "plansDirectory": "docs/plans",
  "commits": {
    "coAuthor": {"enabled": true},
    "extendedDescription": {"enabled": true},
    "format": "conventional"
  }
}
EOF

    # Pre-existing settings.local.json with other keys
    echo '{"env": {"TEST": "1"}}' > "$fake_root/.claude/settings.local.json"

    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
set -e
export PRDX_PROJECT_ROOT="$fake_root"
PROJECT_ROOT="\${PRDX_PROJECT_ROOT:-\$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SETTINGS_FILE="\$PROJECT_ROOT/.claude/settings.local.json"
CONFIG_FILE=""
SEARCH_DIR="\$PROJECT_ROOT"
while [ "\$SEARCH_DIR" != "/" ]; do
  [ -f "\$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/prdx.json" && break
  [ -f "\$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="\$(dirname "\$SEARCH_DIR")"
done
PLANS_SUBDIR=\$(jq -r '.plansDirectory // ".prdx/plans"' "\$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
CONFIGURED_PLANS_DIR="\$PROJECT_ROOT/\$PLANS_SUBDIR"

# Simulate: config plans local
mkdir -p "\$PROJECT_ROOT/.claude"
if [ ! -f "\$SETTINGS_FILE" ]; then
  echo '{}' > "\$SETTINGS_FILE"
fi

jq --arg dir "\$PLANS_SUBDIR" '. + {"plansDirectory": \$dir}' "\$SETTINGS_FILE" > "\${SETTINGS_FILE}.tmp"
mv "\${SETTINGS_FILE}.tmp" "\$SETTINGS_FILE"

mkdir -p "\$CONFIGURED_PLANS_DIR"
echo "local" > "\$PROJECT_ROOT/.prdx/plans-setup-done"

echo "\$(jq -r '.plansDirectory' "\$SETTINGS_FILE")"
SCRIPT
    chmod +x "$driver"

    run bash "$driver"

    [ "$status" -eq 0 ]
    # Must write the configured value (docs/plans), NOT the hardcoded .prdx/plans
    [ "$output" = "docs/plans" ]
    # Directory created
    [ -d "$fake_root/docs/plans" ]
    # Sentinel written
    [ -f "$fake_root/.prdx/plans-setup-done" ]
    # Pre-existing keys in settings.local.json must be preserved
    run bash -c "jq -r '.env.TEST' \"$fake_root/.claude/settings.local.json\""
    [ "$output" = "1" ]
}

@test "settings.local.json plansDirectory is synced with configured value" {
    local fake_root="$TEST_TEMP_DIR/settings-sync-test"
    mkdir -p "$fake_root"

    # Write prdx.json with custom plansDirectory
    cat > "$fake_root/prdx.json" <<'EOF'
{
  "version": "1.0",
  "plansDirectory": "docs/plans",
  "commits": {
    "coAuthor": {"enabled": true},
    "extendedDescription": {"enabled": true},
    "format": "conventional"
  }
}
EOF

    # Simulate settings sync using the resolved plans subdir
    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
export PRDX_PROJECT_ROOT="$fake_root"
PROJECT_ROOT="\${PRDX_PROJECT_ROOT:-\$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE=""
SEARCH_DIR="\$PROJECT_ROOT"
while [ "\$SEARCH_DIR" != "/" ]; do
  [ -f "\$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/prdx.json" && break
  [ -f "\$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="\$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="\$(dirname "\$SEARCH_DIR")"
done
PLANS_SUBDIR=\$(jq -r '.plansDirectory // ".prdx/plans"' "\$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')

# Sync to settings.local.json
SETTINGS_DIR="\$PROJECT_ROOT/.claude"
mkdir -p "\$SETTINGS_DIR"
SETTINGS_FILE="\$SETTINGS_DIR/settings.local.json"
if [ -f "\$SETTINGS_FILE" ]; then
  jq --arg d "\$PLANS_SUBDIR" '.plansDirectory = \$d' "\$SETTINGS_FILE" > "\$SETTINGS_FILE.tmp" && mv "\$SETTINGS_FILE.tmp" "\$SETTINGS_FILE"
else
  echo "{\"plansDirectory\": \"\$PLANS_SUBDIR\"}" > "\$SETTINGS_FILE"
fi
jq -r '.plansDirectory' "\$SETTINGS_FILE"
SCRIPT
    chmod +x "$driver"

    run bash "$driver"

    [ "$status" -eq 0 ]
    [ "$output" = "docs/plans" ]
}
