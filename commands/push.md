---
description: "Create pull request for implemented feature"
argument-hint: "[slug]"
---

# /prdx:push - Create Pull Request

Delegates to `prdx:pr-author` agent to create a pull request with comprehensive description.

The agent runs in an **isolated context** to minimize main conversation context usage.

**Supports two modes:**
- **PRD mode** — When a matching PRD exists, creates a rich PR with acceptance criteria, scope, and approach from the PRD
- **Standalone mode** — When no PRD exists, creates a PR purely from commits and diff analysis

## Usage

```
/prdx:push                    # Auto-detect: PRD mode if matching PRD found, standalone otherwise
/prdx:push backend-auth       # PRD mode: specify PRD slug
/prdx:push --draft            # Standalone draft PR from current branch
/prdx:push backend-auth --draft  # PRD mode: draft PR
```

## How It Works

This command is a **thin wrapper** that:
1. Detects mode (PRD or standalone)
2. Validates git state (branch, commits)
3. If PRD mode: confirms readiness, updates status
4. Pushes branch to remote
5. Invokes `prdx:pr-author` agent (isolated context)
6. Agent creates PR (with or without PRD context)
7. Returns only PR URL and number

## Workflow

### Step 0: Validate GitHub CLI

**Before any GitHub operations, verify `gh` is available and authenticated:**

1. Check if `gh` CLI is installed:
   ```bash
   command -v gh
   ```
   If not found, show error and stop:
   ```
   GitHub CLI (gh) not found.

   This command requires the GitHub CLI to create pull requests.

   Install:
     macOS: brew install gh
     Linux: See https://github.com/cli/cli#installation
     Windows: winget install GitHub.cli
   ```

2. Check authentication status:
   ```bash
   gh auth status
   ```
   If not authenticated, show error and stop:
   ```
   Not authenticated with GitHub.

   Please authenticate:
     gh auth login

   Then try again.
   ```

---

### Phase 1: Detect Mode

**First, parse `--draft` flag:**
- Strip `--draft` from arguments if present (can appear anywhere in the argument string)
- If `--draft` is present: set `DRAFT_FLAG=true`
- If `--draft` is NOT present: set `DRAFT_FLAG=false`
- Continue with remaining arguments for slug matching below

**If slug provided:**

Resolve slug using enhanced matching (exact → substring → word-boundary → disambiguation):
```bash
# 1. Exact: ~/.claude/plans/prdx-{slug}.md
# 2. Substring: ls ~/.claude/plans/prdx-*{slug}*.md
# 3. Word-boundary: split slug into words, find PRDs containing all words
# 4. Multiple matches → ask user to select
```
- Found → **PRD mode**
- Not found → Error: "PRD not found: {slug}. Did you mean to run without a PRD? Use `/prdx:push` with no arguments from your feature branch."

**If no slug provided:**
1. Get current branch: `git branch --show-current`
2. Search for PRD matching the branch:
   ```bash
   grep -rl "^\*\*Branch:\*\*.*$(git branch --show-current)" ~/.claude/plans/prdx-*.md 2>/dev/null
   ```
3. Found → **PRD mode** (use that PRD)
4. Not found → Check last-used slug as fallback:
   ```bash
   LAST_SLUG=$(cat .prdx/last-slug 2>/dev/null)
   ```
   - If last slug exists and matching PRD file (`~/.claude/plans/prdx-{LAST_SLUG}.md`) exists → **PRD mode** (use that PRD, confirm with user first)
   - State for the last-used PRD is at `.prdx/state/{LAST_SLUG}.json` (if needed)
   - If no last slug or no matching PRD → **Standalone mode**

---

## PRD Mode

When a matching PRD is found, use the full PRDX workflow.

### Phase 1b: Check for Parent PRD

Before proceeding, check if the resolved PRD is a parent PRD (multi-platform coordinator):

```bash
grep -q "^## Children" "$PRD_FILE"
```

If the PRD has a `## Children` section, it is a parent PRD. Show an error and stop:

```
Cannot push parent PRD directly.

Parent PRDs are orchestration-only and have no branch or implementation.
Push each child PRD individually:

  /prdx:push {child-slug-1}    (branch: {child-1-branch})
  /prdx:push {child-slug-2}    (branch: {child-2-branch})
```

Where `{child-slug-N}` and `{child-N-branch}` are extracted from the `## Children` section of the parent PRD.

If the PRD does not have a `## Children` section, continue normally (including child PRDs, which work like regular single-platform PRDs for push purposes).

---

### Phase 2a: Verify Status

**If PRD status is `review` or `implemented`:**
- Continue to Phase 3 (status update happens after successful PR creation in Phase 5a)

**If PRD status is `planning` or `in-progress`:**
- Warn: "PRD status is `{status}`. Implementation may not be complete. Continue anyway?"
- If user confirms, continue to Phase 3

### Phase 3a: Validate Git State (PRD Mode)

```bash
# Detect default branch
DEFAULT_BRANCH=$(cat prdx.json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('defaultBranch',''))" 2>/dev/null || true)
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Read expected branch from PRD
EXPECTED_BRANCH=$(grep "^\*\*Branch:\*\*" "$PRD_FILE" | sed 's/\*\*Branch:\*\* //')

# Validate branch matches PRD
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "⚠️  Branch mismatch"
  echo ""
  echo "Current branch: $CURRENT_BRANCH"
  echo "PRD expects:    $EXPECTED_BRANCH"
  echo ""
  echo "Each PRD = 1 branch = 1 PR"
  echo ""
  echo "Options:"
  echo "1. Switch to correct branch: git checkout $EXPECTED_BRANCH"
  echo "2. Cancel and verify you're working on the right PRD"
  exit 1
fi

# Check not on default branch
if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
  echo "Cannot create PR from default branch"
  exit 1
fi

# Check for commits
COMMITS=$(git log "$DEFAULT_BRANCH"..HEAD --oneline)
if [ -z "$COMMITS" ]; then
  echo "No commits on this branch"
  exit 1
fi

# Push if needed
git push -u origin "$CURRENT_BRANCH"
```

### Phase 4a: Invoke PR Author Agent (PRD Mode)

```
subagent_type: "prdx:pr-author"

prompt: "Create a pull request for this PRD.

Mode: prd
PRD Slug: {SLUG}
PRD File: {PRD_FILE}
Branch: {BRANCH}
Base Branch: {DEFAULT_BRANCH}
Draft: {DRAFT_FLAG}

Read the PRD, analyze commits, create comprehensive PR description,
execute gh pr create, and update PRD with PR metadata.

Return only the PR summary (number, URL, title)."
```

### Phase 5a: Update Status and Display Summary (PRD Mode)

**After successful PR creation, update status:**
- If PRD status is not already `implemented`: Update PRD status to `implemented` by editing the `**Status:**` line in the PRD file
- If PR creation failed: Do NOT update status — it stays at `review`

**If DRAFT_FLAG is false:**
```
Pull Request Created!

PRD: ~/.claude/plans/{SLUG}.md
PR: #{PR_NUMBER}
URL: {PR_URL}

Next steps:
1. Review the PR in GitHub
2. Request reviewers
3. Address feedback
4. Merge when approved
5. Close PRD: /prdx:close {SLUG}

To view PR: gh pr view {PR_NUMBER} --web
```

**If DRAFT_FLAG is true:**
```
Draft Pull Request Created!

PRD: ~/.claude/plans/{SLUG}.md
PR: #{PR_NUMBER} (Draft)
URL: {PR_URL}

Note: PR body includes notice that it has not been human-reviewed.
To mark ready: gh pr ready {PR_NUMBER}
To view PR: gh pr view {PR_NUMBER} --web
```

---

## Standalone Mode

When no PRD exists, create a PR purely from branch analysis.

### Phase 2b: Validate Git State (Standalone)

```bash
# Detect default branch
DEFAULT_BRANCH=$(cat prdx.json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('defaultBranch',''))" 2>/dev/null || true)
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Check not on default branch
if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
  echo "Cannot create PR from default branch"
  exit 1
fi

# Check for commits
COMMITS=$(git log "$DEFAULT_BRANCH"..HEAD --oneline)
if [ -z "$COMMITS" ]; then
  echo "No commits on this branch"
  exit 1
fi

# Push if needed
git push -u origin "$CURRENT_BRANCH"
```

### Phase 3b: Invoke PR Author Agent (Standalone)

```
subagent_type: "prdx:pr-author"

prompt: "Create a pull request from branch analysis (no PRD).

Mode: standalone
Branch: {BRANCH}
Base Branch: {DEFAULT_BRANCH}
Draft: {DRAFT_FLAG}

Analyze commits and changes to create a clear PR description.
Execute gh pr create.

Return only the PR summary (number, URL, title)."
```

### Phase 4b: Display Summary (Standalone)

**If DRAFT_FLAG is false:**
```
Pull Request Created!

PR: #{PR_NUMBER}
URL: {PR_URL}

To view PR: gh pr view {PR_NUMBER} --web
```

**If DRAFT_FLAG is true:**
```
Draft Pull Request Created!

PR: #{PR_NUMBER} (Draft)
URL: {PR_URL}

Note: PR body includes notice that it has not been human-reviewed.
To mark ready: gh pr ready {PR_NUMBER}
To view PR: gh pr view {PR_NUMBER} --web
```

---

## Error Handling

### GitHub CLI Not Available

```
GitHub CLI (gh) not found.

This command requires the GitHub CLI to create pull requests.

Install:
  - macOS: brew install gh
  - Linux: See https://github.com/cli/cli#installation
  - Windows: winget install GitHub.cli

Then authenticate:
  gh auth login
```

### Not Authenticated

```
Not authenticated with GitHub.

Please authenticate:
  gh auth login

Then try again.
```

### PR Already Exists

```
PR already exists for this branch:
#42: feat: Add authentication endpoints
https://github.com/user/repo/pull/42
State: open

Options:
1. Update existing PR description
2. View PR
3. Cancel
```

### No Commits

```
No commits found on this branch.

Please make and commit changes first.
```

### On Default Branch

```
Cannot create PR from main/master.

Create a feature branch first:
  git checkout -b feat/my-feature
```

## Context Efficiency

The `prdx:pr-author` agent runs in an **isolated context**:

| What stays in agent context | What returns to main conversation |
|-----------------------------|-----------------------------------|
| PRD file content (if PRD mode) | PR number |
| Commit history analysis | PR URL |
| File change analysis | PR title |

This keeps the main conversation context minimal.

## Examples

### Example 1: PRD Mode (slug provided)

```
User: /prdx:push backend-auth

→ Finds PRD: ~/.claude/plans/prdx-backend-auth.md
→ Status is "review" → will update to "implemented" after PR creation
→ Validates git state
→ prdx:pr-author agent invoked (PRD mode)
→ Agent reads PRD, analyzes commits
→ Agent creates PR via gh CLI
→ Agent updates PRD with PR metadata
→ Returns PR summary

Pull Request Created!

PRD: ~/.claude/plans/prdx-backend-auth.md
PR: #42
URL: https://github.com/user/repo/pull/42

To view PR: gh pr view 42 --web
```

### Example 2: Standalone (no PRD)

```
User: /prdx:push

→ No slug provided
→ Current branch: fix/typo-in-readme
→ No matching PRD found → standalone mode
→ Validates git state
→ prdx:pr-author agent invoked (standalone mode)
→ Agent analyzes commits and changes
→ Agent creates PR via gh CLI
→ Returns PR summary

Pull Request Created!

PR: #43
URL: https://github.com/user/repo/pull/43

To view PR: gh pr view 43 --web
```

### Example 3: Auto-detect PRD

```
User: /prdx:push

→ No slug provided
→ Current branch: feat/backend-auth
→ Found PRD with Branch: feat/backend-auth → PRD mode
→ (continues as PRD mode workflow)
```

### Example 4: Draft PR (Standalone)

```
User: /prdx:push --draft

→ Standalone mode (no PRD found)
→ Draft: true → passes --draft to agent
→ Agent adds "not human-reviewed" notice to PR body
→ Creates draft PR via gh pr create --draft

Draft Pull Request Created!

PR: #44 (Draft)
URL: https://github.com/user/repo/pull/44

Note: PR body includes notice that it has not been human-reviewed.
To mark ready: gh pr ready 44
```

### Example 5: Draft PR (PRD Mode)

```
User: /prdx:push backend-auth --draft

→ Finds PRD: ~/.claude/plans/prdx-backend-auth.md
→ Status is "review" → will update to "implemented" after PR creation
→ Draft: true → passes --draft to agent
→ Agent adds "not human-reviewed" notice to PR body
→ Creates draft PR via gh pr create --draft

Draft Pull Request Created!

PRD: ~/.claude/plans/prdx-backend-auth.md
PR: #45 (Draft)
URL: https://github.com/user/repo/pull/45

Note: PR body includes notice that it has not been human-reviewed.
To mark ready: gh pr ready 45
```
