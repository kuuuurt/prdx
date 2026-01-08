---
description: "Create pull request for implemented feature"
argument-hint: "[slug]"
---

# /prdx:push - Create Pull Request

Delegates to `prdx:pr-author` agent to create a pull request with comprehensive description.

The agent runs in an **isolated context** to minimize main conversation context usage.

## Usage

```
/prdx:push                    # Use current PRD from context
/prdx:push backend-auth       # Specify PRD slug
/prdx:push --draft            # Create as draft PR
```

## How It Works

This command is a **thin wrapper** that:
1. Finds and validates the PRD file
2. **Confirms implementation is ready** (if status is `review`)
3. Validates git state (branch, commits, pushed)
4. Updates PRD status to `implemented`
5. Invokes `prdx:pr-author` agent (isolated context)
6. Agent creates PR and updates PRD
7. Returns only PR URL and number

## Workflow

### Phase 1: Find PRD

**If slug provided:**
```bash
ls .prdx/prds/*[slug]*.md
```

**If not provided:**
List all PRDs with status "review" or "implemented":
```
PRDs ready for PR:
1. backend-auth (review)
2. android-biometric (implemented)

Which PRD? (enter number or slug)
```

### Phase 1a: Confirm Ready for PR

**If PRD status is `review`:**

Use AskUserQuestion to confirm the implementation is ready:

- Option 1: "Yes, implementation is ready" (Recommended)
- Option 2: "No, I found issues to fix"

**If user confirms ready:**
- Update PRD status to `implemented`:
  ```bash
  sed -i '' 's/^\*\*Status:\*\* review/\*\*Status:\*\* implemented/' "$PRD_FILE"
  ```
- Continue to Phase 2

**If user found issues:**
- Tell user to describe the issues for fixing
- End workflow (they can resume with `/prdx [slug]` after fixing)

**If PRD status is already `implemented`:**
- Skip confirmation, proceed to Phase 2

### Phase 2: Validate Git State

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

**Important:** Each PRD corresponds to exactly one branch and one PR. The push command validates that you're on the correct branch before creating the PR.

### Phase 3: Invoke PR Author Agent

```
subagent_type: "prdx:pr-author"

prompt: "Create a pull request for this PRD.

PRD Slug: {SLUG}
PRD File: {PRD_FILE}
Branch: {BRANCH}
Draft: {DRAFT_FLAG}

Read the PRD, analyze commits, create comprehensive PR description,
execute gh pr create, and update PRD with PR metadata.

Return only the PR summary (number, URL, title)."
```

**Agent runs in isolated context:**
- Reads PRD file
- Analyzes commits with `git log`
- Creates PR description
- Executes `gh pr create`
- Updates PRD with PR metadata
- Returns only: PR number, URL, title (~100B)

### Phase 4: Display Summary

After agent returns:

```
Pull Request Created!

PRD: .prdx/prds/{SLUG}.md
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

Please implement and commit changes first:
  /prdx:implement {SLUG}
```

## Context Efficiency

The `prdx:pr-author` agent runs in an **isolated context**:

| What stays in agent context | What returns to main conversation |
|-----------------------------|-----------------------------------|
| PRD file content | PR number |
| Commit history analysis | PR URL |
| File change analysis | PR title |

This keeps the main conversation context minimal.

## Examples

### Example 1: Basic Usage

```
User: /prdx:push backend-auth

→ Finds PRD: .prdx/prds/backend-auth.md
→ Status is "review" - confirms implementation is ready
→ User confirms → Status updated to "implemented"
→ Validates git state
→ prdx:pr-author agent invoked (isolated context)
→ Agent reads PRD, analyzes commits
→ Agent creates PR via gh CLI
→ Agent updates PRD with PR metadata
→ Returns PR summary

Pull Request Created!

PRD: .prdx/prds/backend-auth.md
PR: #42
URL: https://github.com/user/repo/pull/42

To view PR: gh pr view 42 --web
```

### Example 2: Draft PR

```
User: /prdx:push android-biometric --draft

→ Creates draft PR
→ Can be marked ready later

Draft Pull Request Created!

PR: #43 (Draft)
URL: https://github.com/user/repo/pull/43

To mark ready: gh pr ready 43
```

## Implementation Notes

### Agent vs Direct Bash

| Before | After |
|--------|-------|
| Inline bash in command | prdx:pr-author agent |
| PRD content in main context | PRD content in agent context |
| Full git analysis visible | Only PR summary visible |

### Division of Labor

```
/prdx:push
└── prdx:pr-author (isolated)
    ├── Read PRD
    ├── Analyze commits
    ├── Create PR
    ├── Update PRD
    └── Return: PR #, URL, title
```
