---
description: "Set up GitHub Actions workflow for PRDX CI mode"
argument-hint: "[--force]"
---

# /prdx:setup-github-actions - Install CI Workflow

> Sets up the PRDX GitHub Actions workflow in the current repository.
> Copies the reference workflow and guides through secrets configuration.
> Use `--force` to overwrite without prompts and auto-push.

## Steps

### Step 0: Parse Flags

- Strip `--force` from arguments if present
- If `--force` is present: set `FORCE=true`
- If `--force` is NOT present: set `FORCE=false`

### Step 1: Verify Prerequisites

```bash
# Must be a git repo with a GitHub remote
git remote get-url origin 2>/dev/null
gh repo view --json name --jq '.name' 2>/dev/null
```

If either fails, error:
```
This command requires a git repository with a GitHub remote.
```

### Step 2: Check for Existing Workflow

```bash
ls .github/workflows/mention.claude-code.yml 2>/dev/null
```

If the file exists and `FORCE=true`: skip to Step 3 (overwrite silently).

If the file exists and `FORCE=false`, use AskUserQuestion to ask the user what to do:
```
A Claude Code workflow already exists at .github/workflows/mention.claude-code.yml.

What would you like to do?
1. Overwrite with the latest PRDX reference workflow
2. Show a diff between your current workflow and the latest reference
3. Skip — keep the existing workflow
```

- Option 1: Continue to Step 3 (overwrite)
- Option 2: Fetch the reference workflow content, display a diff comparison, then ask again (option 1 or 3)
- Option 3: Stop

### Step 3: Find and Copy the Workflow

Locate the PRDX plugin directory and copy the reference workflow:

```bash
# Create workflows directory if needed
mkdir -p .github/workflows
```

Read the reference workflow from the PRDX plugin's `examples/workflows/mention.claude-code.yml` file. The plugin could be installed at:
- `~/.claude/plugins/prdx/examples/workflows/mention.claude-code.yml`
- Or findable via: `find ~/.claude/plugins -name "mention.claude-code.yml" -path "*/prdx/examples/*" 2>/dev/null`

If the reference file cannot be found, fetch it from GitHub:
```bash
gh api repos/kuuuurt/prdx/contents/examples/workflows/mention.claude-code.yml --jq '.content' | base64 -d > .github/workflows/mention.claude-code.yml
```

### Step 4: Verify Secrets

Check if the required secret exists:
```bash
gh secret list 2>/dev/null | grep -q CLAUDE_CODE_OAUTH_TOKEN
```

If not found, display setup instructions:
```
The workflow requires a CLAUDE_CODE_OAUTH_TOKEN secret.

To set it up:
1. Go to https://console.anthropic.com/ and create an OAuth token
2. Run: gh secret set CLAUDE_CODE_OAUTH_TOKEN
3. Paste your token when prompted

Or set it in your repo settings: Settings → Secrets and variables → Actions → New repository secret
```

### Step 5: Ensure PRDX Plans Directory is Configured

```bash
ls .prdx/plans-setup-done 2>/dev/null
```

If not found:
```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CONFIG_FILE=""
SEARCH_DIR="$PROJECT_ROOT"
while [ "$SEARCH_DIR" != "/" ]; do
  [ -f "$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/prdx.json" && break
  [ -f "$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done
PLANS_SUBDIR=$(jq -r '.plansDirectory // ".prdx/plans"' "$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="$PROJECT_ROOT/$PLANS_SUBDIR"

mkdir -p .claude .prdx "$PLANS_DIR"
if [ -f .claude/settings.json ]; then
  jq --arg dir "$PLANS_SUBDIR" '. + {plansDirectory: $dir}' .claude/settings.json > .claude/settings.json.tmp && mv .claude/settings.json.tmp .claude/settings.json
else
  echo "{\"plansDirectory\": \"$PLANS_SUBDIR\"}" > .claude/settings.json
fi
echo "local" > .prdx/plans-setup-done
```

### Step 6: Ensure Gitignore

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
GITIGNORE="$PROJECT_ROOT/.gitignore"
if echo "$PLANS_SUBDIR" | grep -q "^\.prdx/"; then
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF '.prdx/*' "$GITIGNORE"; then
    # Neither rule exists — add both
    echo '' >> "$GITIGNORE"
    echo '# PRDX - only track plans (ignore state, markers, etc.)' >> "$GITIGNORE"
    echo '.prdx/*' >> "$GITIGNORE"
    echo "!$PLANS_SUBDIR/" >> "$GITIGNORE"
  elif ! grep -qxF "!$PLANS_SUBDIR/" "$GITIGNORE"; then
    # .prdx/* exists but exception is wrong/missing — add correct exception
    echo "!$PLANS_SUBDIR/" >> "$GITIGNORE"
  fi
else
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF '.prdx/*' "$GITIGNORE"; then
    echo '' >> "$GITIGNORE"
    echo '# PRDX state (ignore all)' >> "$GITIGNORE"
    echo '.prdx/*' >> "$GITIGNORE"
  fi
fi
```

### Step 7: Offer Cleanup Workflow

If `FORCE=true`: install the cleanup workflow automatically (skip to copying).

If `FORCE=false`: use AskUserQuestion:
```
Also install the weekly cleanup workflow?
(Captures lessons from merged PRs + removes completed PRD plan files)

1. Yes — install cleanup.claude-code.yml
2. No — skip
```

If yes (or `FORCE=true`):

Locate and copy the cleanup workflow from the PRDX plugin's `examples/workflows/cleanup.claude-code.yml` (same lookup logic as Step 3). If not found locally, fetch from GitHub:
```bash
gh api repos/kuuuurt/prdx/contents/examples/workflows/cleanup.claude-code.yml --jq '.content' | base64 -d > .github/workflows/cleanup.claude-code.yml
```

### Step 8: Display Summary

```
GitHub Actions workflow installed!

  Workflows:
    .github/workflows/mention.claude-code.yml  — CI commands
    .github/workflows/cleanup.claude-code.yml  — Weekly cleanup (if installed)

  Available commands (comment on issues/PRs):
    @claude plan       — Generate PRD from issue (creates draft PR)
    @claude revise     — Revise PRD based on feedback
    @claude implement  — Implement the PRD
    @claude review     — Code review the implementation

  Cleanup:
    Runs weekly (Monday midnight UTC) or manually via workflow_dispatch.
    Captures lessons from merged PRs, then removes PRD plan + state files.

  Flow:
    Issue → @claude plan → Draft PR → @claude implement → @claude review → Human review

  Required secret: CLAUDE_CODE_OAUTH_TOKEN
```

Commit the workflow file(s):
```bash
git add .github/workflows/mention.claude-code.yml
git add .github/workflows/cleanup.claude-code.yml 2>/dev/null
git commit -m "ci: add PRDX Claude Code workflow"
```

If `FORCE=true`: push immediately without asking:
```bash
git push
```

If `FORCE=false`: ask if they want to push:
```
Push the workflow to GitHub? (y/n)
```

If yes:
```bash
git push
```
