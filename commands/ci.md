---
description: "Run PRDX in CI mode (plan-only or implement from issue)"
argument-hint: "--issue <number> [--plan-only] [--requested-by <user>]"
---

## Pre-Computed Context

```bash
echo "=== Git Context ==="
echo "Branch: $(git branch --show-current)"
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-plans-dir.sh"
echo "PLANS_DIR=$PLANS_DIR"
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-default-branch.sh"
echo "DEFAULT_BRANCH=$DEFAULT_BRANCH"
echo "PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)"
```

# /prdx:ci - CI Mode Workflow

Runs PRDX in non-interactive CI mode. Requires `--issue`. Supports `--plan-only` (generate PRD as issue comment) or full implement (PRD → branch → PR).

## Prerequisites

- `--issue {number}` is required
- `.prdx/plans-setup-done` must exist (error if missing)
- `gh auth status` must pass

## Setup

Parse flags from arguments: `--issue {number}`, `--requested-by {user}`, `--plan-only`.

If `--requested-by` provided, configure git author:
```bash
REQUESTOR_NAME=$(gh api "users/${REQUESTOR}" --jq '.name // .login' 2>/dev/null || echo "$REQUESTOR")
export GIT_AUTHOR_NAME="$REQUESTOR_NAME"
export GIT_AUTHOR_EMAIL="${REQUESTOR}@users.noreply.github.com"
```

Fetch issue: `gh issue view {ISSUE_NUMBER} --json title,body,labels`. Store `ISSUE_TITLE` + `ISSUE_BODY`.

Route: `--plan-only` → Step 1 | otherwise → Step 2.

---

## CI Progress Comment Helper

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
RUN_URL="${GITHUB_SERVER_URL}/${REPO}/actions/runs/${GITHUB_RUN_ID}"
PROGRESS_COMMENT_ID=$(gh issue comment "$ISSUE_NUMBER" --body "> {MESSAGE} 🔨
>
> [View job run]($RUN_URL)" | grep -o 'https://[^ ]*' | grep -o '[0-9]*$')

# To update:
gh api "repos/$REPO/issues/comments/$PROGRESS_COMMENT_ID" -X PATCH -f body="{DONE_MESSAGE}"
```

---

## Step 1: Plan-Only Path

Generates a PRD and posts it as an issue comment.

**1.1: Derive slug, detect platform and project:**

- `{SLUG}`: Extract core concept from `ISSUE_TITLE` (2-4 words max, kebab-case). Strip filler words (add, implement, create, update, fix, refactor, improve) and prepositions — keep domain nouns and key verbs.
- Platform: check directories, config files, issue title keywords (single-platform only).
- Project: from Pre-Computed Context `PROJECT_NAME`.

**1.2: Check for existing PRD comment:**

```bash
PRD_COMMENT=$(gh issue view "$ISSUE_NUMBER" --json comments --jq '[.comments[] | select(.body | contains("<!-- prdx-prd -->"))] | last' 2>/dev/null)
```

- **No PRD comment (fresh plan):** Post progress comment (`Planning...`), continue to 1.3.
- **PRD comment exists (revision):** Jump to 1.6.

**1.3: Explore codebase** via `prdx:code-explorer` agent. Pass `ISSUE_TITLE` + `ISSUE_BODY`.

**1.4: Generate PRD content** using the full PRD template (do NOT write a file):

```markdown
# {ISSUE_TITLE}

**Type:** {auto-detected}
**Project:** {PROJECT_NAME}
**Platform:** {DETECTED_PLATFORM}
**Status:** planning
**Created:** {TODAY}

## Problem
{From ISSUE_BODY}

## Goal
{From issue title/body}

## Acceptance Criteria
{From ISSUE_BODY checkboxes/lists, or derive 2-3 testable criteria}

## Approach
{From codebase exploration}

## Risks & Considerations
{1-2 risks from codebase exploration}
```

**1.5: Post PRD as issue comment:**

```bash
PRD_COMMENT_ID=$(gh issue comment "$ISSUE_NUMBER" --body "$(cat <<'PRDBODY'
<!-- prdx-prd -->
{FULL PRD CONTENT}
PRDBODY
)" | grep -o 'https://[^ ]*' | grep -o '[0-9]*$')
```

Update progress comment: `"Planning complete. PRD posted above — comment \`@claude implement\` when ready, or \`@claude revise\` with feedback."`

---

**1.6: Revision path (existing PRD comment):**

1. Post progress comment: `Revising PRD...`
2. Fetch existing PRD comment:
   ```bash
   PRD_COMMENT_ID=$(echo "$PRD_COMMENT" | jq -r '.databaseId // .id' 2>/dev/null)
   PRD_COMMENT_BODY=$(echo "$PRD_COMMENT" | jq -r '.body' 2>/dev/null)
   ```
3. Read feedback comments posted after the PRD comment:
   ```bash
   gh issue view "$ISSUE_NUMBER" --json comments --jq \
     --argjson prd_id "$PRD_COMMENT_ID" \
     '[.comments[] | select((.databaseId // .id) > $prd_id) | .body] | join("\n---\n")' 2>/dev/null
   ```
4. Re-explore codebase if needed.
5. Generate revised PRD (keep `<!-- prdx-prd -->` marker).
6. Update in-place:
   ```bash
   gh api "repos/$REPO/issues/comments/$PRD_COMMENT_ID" -X PATCH -f body="<!-- prdx-prd -->
   {REVISED PRD CONTENT}"
   ```
7. Update progress comment: `"PRD revised. Comment \`@claude implement\` when ready."`

---

## Step 2: Implement Path

Reads PRD from issue comment, implements it, creates branch and PR. If PR already exists, applies fixes.

**2.1: Derive slug and detect platform:**

Derive `{SLUG}` from `ISSUE_TITLE` (same logic as 1.1). Determine branch: `BRANCH="{TYPE_PREFIX}/{SLUG}"`.

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
PROJECT_NAME=$(echo "$REPO" | cut -d'/' -f2)
```

**2.2: Find PRD from issue comment:**

```bash
PRD_COMMENT=$(gh issue view "$ISSUE_NUMBER" --json comments --jq '[.comments[] | select(.body | contains("<!-- prdx-prd -->"))] | last' 2>/dev/null)
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null)
```

| condition | action |
|-----------|--------|
| PRD found + PR exists | Fix iteration path (below) |
| PRD found + no PR | Fresh implementation — post progress (`Implementing...`), continue to 2.3 |
| No PRD + PR exists | Find linked issue from PR body (`Closes #N`), fetch PRD from that issue |
| No PRD + no PR | Error: `No PRD found for issue #{ISSUE_NUMBER}. Run \`@claude plan\` first.` |

**2.3: Write PRD locally and set up branch:**

```bash
PRD_BODY=$(echo "$PRD_COMMENT" | jq -r '.body' 2>/dev/null)
mkdir -p "$PLANS_DIR"
echo "$PRD_BODY" | sed 's/<!-- prdx-prd -->//' > "$PLANS_DIR/prdx-${SLUG}.md"
git checkout -b "$BRANCH"
```

**2.4: Run implement:**

```bash
mkdir -p .prdx/state
cat > .prdx/state/${SLUG}.json << EOF
{"slug": "${SLUG}", "phase": "implementing", "quick": false}
EOF
export CI=true
```
```
/prdx:implement {SLUG}
```

**2.5: Push and create PR:**

```bash
git push -u origin "$BRANCH"
```

Invoke `prdx:pr-author` agent: create a real (non-draft) PR. Include `Closes #{ISSUE_NUMBER}` in body. Footer: `Comment \`@claude review\` for code review.` After creation, add `$REQUESTOR` as reviewer if set.

**2.6: Finalize:**

Update progress comment: `"Implementation complete. PR #${PR_NUMBER} created. Comment \`@claude review\` for code review."`

Write state: `{"slug": "${SLUG}", "phase": "review", "quick": false, "pr_number": ${PR_NUMBER}}`

---

**Fix Iteration Path (PR already exists):**

1. Checkout branch: `git fetch origin "$BRANCH" && git checkout "$BRANCH" && git pull origin "$BRANCH"`
2. Write PRD locally (same as 2.3).
3. Post progress comment: `Applying fixes...`
4. Run: `export CI=true` then `/prdx:implement {SLUG}`
5. Push: `git push origin "$BRANCH"`
6. Update progress comment: `"Fixes applied to PR #${PR_NUMBER}. Comment \`@claude review\` for another code review."`
