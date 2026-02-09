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

### Phase 1: Detect Mode

**If slug provided:**
```bash
ls ~/.claude/plans/prdx-*[slug]*.md
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
4. Not found → **Standalone mode**

---

## PRD Mode

When a matching PRD is found, use the full PRDX workflow.

### Phase 2a: Confirm Ready for PR

**If PRD status is `review`:**

Use AskUserQuestion to confirm the implementation is ready:

- Option 1: "Yes, implementation is ready" (Recommended)
- Option 2: "No, I found issues to fix"

**If user confirms ready:**
- Update PRD status to `implemented` by editing the `**Status:**` line in the PRD file
- Continue to Phase 3

**If user found issues:**
- Tell user to describe the issues for fixing
- End workflow (they can resume with `/prdx:prdx [slug]` after fixing)

**If PRD status is already `implemented`:**
- Skip confirmation, proceed to Phase 3

### Phase 3a: Validate Git State (PRD Mode)

```bash
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

# Check not on main
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  echo "Cannot create PR from default branch"
  exit 1
fi

# Check for commits
COMMITS=$(git log main..HEAD --oneline)
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
Draft: {DRAFT_FLAG}

Read the PRD, analyze commits, create comprehensive PR description,
execute gh pr create, and update PRD with PR metadata.

Return only the PR summary (number, URL, title)."
```

### Phase 5a: Display Summary (PRD Mode)

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

---

## Standalone Mode

When no PRD exists, create a PR purely from branch analysis.

### Phase 2b: Validate Git State (Standalone)

```bash
# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Check not on main
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  echo "Cannot create PR from default branch"
  exit 1
fi

# Check for commits
COMMITS=$(git log main..HEAD --oneline)
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
Draft: {DRAFT_FLAG}

Analyze commits and changes to create a clear PR description.
Execute gh pr create.

Return only the PR summary (number, URL, title)."
```

### Phase 4b: Display Summary (Standalone)

```
Pull Request Created!

PR: #{PR_NUMBER}
URL: {PR_URL}

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
→ Status is "review" - confirms implementation is ready
→ User confirms → Status updated to "implemented"
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

### Example 4: Draft PR

```
User: /prdx:push --draft

→ Standalone mode (or PRD mode if PRD found)
→ Creates draft PR

Draft Pull Request Created!

PR: #44 (Draft)
URL: https://github.com/user/repo/pull/44

To mark ready: gh pr ready 44
```
