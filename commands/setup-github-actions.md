---
description: "Set up GitHub Actions workflow for PRDX CI mode"
argument-hint: ""
---

# /prdx:setup-github-actions - Install CI Workflow

> Sets up the PRDX GitHub Actions workflow in the current repository.
> Copies the reference workflow and guides through secrets configuration.

## Steps

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

If the file exists, use AskUserQuestion to ask the user what to do:
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
mkdir -p .claude .prdx .prdx/plans
if [ -f .claude/settings.local.json ]; then
  jq '. + {plansDirectory: ".prdx/plans"}' .claude/settings.local.json > .claude/settings.local.json.tmp && mv .claude/settings.local.json.tmp .claude/settings.local.json
else
  echo '{"plansDirectory": ".prdx/plans"}' > .claude/settings.local.json
fi
echo "local" > .prdx/plans-setup-done
```

### Step 6: Ensure Gitignore

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
GITIGNORE="$PROJECT_ROOT/.gitignore"

if [ ! -f "$GITIGNORE" ] || ! grep -qxF '.prdx/*' "$GITIGNORE"; then
  echo '' >> "$GITIGNORE"
  echo '# PRDX - only track plans (ignore state, markers, etc.)' >> "$GITIGNORE"
  echo '.prdx/*' >> "$GITIGNORE"
  echo '!.prdx/plans/' >> "$GITIGNORE"
fi
```

### Step 7: Display Summary

```
GitHub Actions workflow installed!

  Workflow: .github/workflows/mention.claude-code.yml

  Available commands (comment on issues/PRs):
    @claude plan       — Generate PRD from issue (creates draft PR)
    @claude revise     — Revise PRD based on feedback
    @claude implement  — Implement the PRD
    @claude review     — Code review the implementation

  Flow:
    Issue → @claude plan → Draft PR → @claude implement → @claude review → Human review

  Required secret: CLAUDE_CODE_OAUTH_TOKEN
```

Commit the workflow file:
```bash
git add .github/workflows/mention.claude-code.yml
git commit -m "ci: add PRDX Claude Code workflow"
```

Ask if they want to push:
```
Push the workflow to GitHub? (y/n)
```

If yes:
```bash
git push
```
