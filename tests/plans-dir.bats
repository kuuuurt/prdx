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

@test "gitignore gets .prdx/* exception when plans under .prdx/" {
    local fake_root="$TEST_TEMP_DIR/gitignore-test"
    mkdir -p "$fake_root"

    local gitignore="$fake_root/.gitignore"
    local plans_subdir=".prdx/plans"

    # Simulate the conditional gitignore logic
    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
GITIGNORE="$gitignore"
PLANS_SUBDIR="$plans_subdir"

if echo "\$PLANS_SUBDIR" | grep -q "^\.prdx/"; then
  if [ ! -f "\$GITIGNORE" ] || ! grep -qxF '.prdx/*' "\$GITIGNORE"; then
    echo '' >> "\$GITIGNORE"
    echo '# PRDX - only track plans (ignore state, markers, etc.)' >> "\$GITIGNORE"
    echo '.prdx/*' >> "\$GITIGNORE"
    echo "!\$PLANS_SUBDIR/" >> "\$GITIGNORE"
  fi
else
  if [ ! -f "\$GITIGNORE" ] || ! grep -qxF '.prdx/*' "\$GITIGNORE"; then
    echo '' >> "\$GITIGNORE"
    echo '# PRDX state (ignore all)' >> "\$GITIGNORE"
    echo '.prdx/*' >> "\$GITIGNORE"
  fi
fi
SCRIPT
    chmod +x "$driver"
    bash "$driver"

    # Should have .prdx/* and exception
    grep -qxF '.prdx/*' "$gitignore"
    [ "$?" -eq 0 ]

    grep -qxF '!.prdx/plans/' "$gitignore"
    [ "$?" -eq 0 ]
}

@test "gitignore gets only .prdx/* when plans outside .prdx/" {
    local fake_root="$TEST_TEMP_DIR/gitignore-custom-test"
    mkdir -p "$fake_root"

    local gitignore="$fake_root/.gitignore"
    local plans_subdir="docs/plans"

    local driver
    driver="$(mktemp "$TEST_TEMP_DIR/driver.XXXXXX.sh")"
    cat > "$driver" <<SCRIPT
#!/bin/bash
GITIGNORE="$gitignore"
PLANS_SUBDIR="$plans_subdir"

if echo "\$PLANS_SUBDIR" | grep -q "^\.prdx/"; then
  if [ ! -f "\$GITIGNORE" ] || ! grep -qxF '.prdx/*' "\$GITIGNORE"; then
    echo '' >> "\$GITIGNORE"
    echo '# PRDX - only track plans (ignore state, markers, etc.)' >> "\$GITIGNORE"
    echo '.prdx/*' >> "\$GITIGNORE"
    echo "!\$PLANS_SUBDIR/" >> "\$GITIGNORE"
  fi
else
  if [ ! -f "\$GITIGNORE" ] || ! grep -qxF '.prdx/*' "\$GITIGNORE"; then
    echo '' >> "\$GITIGNORE"
    echo '# PRDX state (ignore all)' >> "\$GITIGNORE"
    echo '.prdx/*' >> "\$GITIGNORE"
  fi
fi
SCRIPT
    chmod +x "$driver"
    bash "$driver"

    # Should have .prdx/*
    grep -qxF '.prdx/*' "$gitignore"
    [ "$?" -eq 0 ]

    # Should NOT have the exception line
    run grep -qxF '!docs/plans/' "$gitignore"
    [ "$status" -ne 0 ]
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
