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

## Reactions

The workflow's `Acknowledge comment` step already reacts `eyes` on the triggering comment before Claude Code starts, so `ci.md` only needs to post the `rocket` reaction when work completes. All reactions target the triggering comment (not the issue) so the user sees the emoji on the exact comment they typed.

The trigger comment is passed via the `TRIGGER_COMMENT_ID` env var. If it is unset (e.g., running outside the workflow), skip reactions silently.

```bash
react_rocket() {
  [ -z "$TRIGGER_COMMENT_ID" ] && return 0
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
  gh api "repos/$REPO/issues/comments/$TRIGGER_COMMENT_ID/reactions" -X POST -f content="rocket" >/dev/null 2>&1 || true
}
```

Call `react_rocket` at the end of each successful flow below.

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

- **No PRD comment (fresh plan):** Continue to 1.3. (The workflow has already reacted `eyes` on the trigger comment.)
- **PRD comment exists (revision):** Jump to 1.6.

**1.3: Explore codebase** via `prdx:code-explorer` agent. Pass `ISSUE_TITLE` + `ISSUE_BODY`.

**1.4: Generate PRD content** using the full PRD template (do NOT write a file).

**Writing style:** Lead with the point. Problem: 1-3 sentences. Goal: 1 sentence. ACs: start with verb, testable, no explanations. Approach: 1-3 sentences. Risks: bullet list, max 3. No throat-clearing, hedging, or preambles.

```markdown
# {ISSUE_TITLE}

**Type:** {auto-detected}
**Project:** {PROJECT_NAME}
**Platform:** {DETECTED_PLATFORM}
**Status:** planning
**Created:** {TODAY}

## Problem
{1-3 sentences: what is broken/missing and why it matters}

## Goal
{1 sentence: desired end state in user/business terms}

## Acceptance Criteria
{From ISSUE_BODY checkboxes/lists, or derive 2-3 testable criteria}

## Approach
{1-3 sentences or numbered steps. Direction only}

## Risks & Considerations
{Bullet list. Risk → consequence. Max 2}
```

**1.5: Post PRD as issue comment:**

```bash
PRD_COMMENT_ID=$(gh issue comment "$ISSUE_NUMBER" --body "$(cat <<'PRDBODY'
<!-- prdx-prd -->
{FULL PRD CONTENT}
PRDBODY
)" | grep -o 'https://[^ ]*' | grep -o '[0-9]*$')
```

Call `react_rocket` to signal the PRD is ready.

---

**1.6: Revision path (existing PRD comment):**

1. Fetch existing PRD comment:
   ```bash
   REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
   PRD_COMMENT_ID=$(echo "$PRD_COMMENT" | jq -r '.databaseId // .id' 2>/dev/null)
   PRD_COMMENT_BODY=$(echo "$PRD_COMMENT" | jq -r '.body' 2>/dev/null)
   ```
2. Read feedback comments posted after the PRD comment. `TRIGGER_COMMENT_ID` (from env) is the specific comment that triggered this revision; treat everything newer than the PRD comment as feedback:
   ```bash
   gh issue view "$ISSUE_NUMBER" --json comments --jq \
     --argjson prd_id "$PRD_COMMENT_ID" \
     '[.comments[] | select((.databaseId // .id) > $prd_id) | .body] | join("\n---\n")' 2>/dev/null
   ```
3. Re-explore codebase if needed.
4. Generate revised PRD (keep `<!-- prdx-prd -->` marker).
5. Update in-place:
   ```bash
   gh api "repos/$REPO/issues/comments/$PRD_COMMENT_ID" -X PATCH -f body="<!-- prdx-prd -->
   {REVISED PRD CONTENT}"
   ```
6. Call `react_rocket` to signal revision is complete.

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
| PRD found + no PR | Fresh implementation — continue to 2.3 |
| No PRD + PR exists | Find linked issue from PR body (`Closes #N`), fetch PRD from that issue |
| No PRD + no PR | Error: `No PRD found for issue #{ISSUE_NUMBER}. Run \`@claude plan\` first.` |

(The workflow has already reacted `eyes` on the trigger comment.)

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

Post a single short comment on the issue with the PR link:
```bash
gh issue comment "$ISSUE_NUMBER" --body "Created PR #${PR_NUMBER}."
```

Write state: `{"slug": "${SLUG}", "phase": "review", "quick": false, "pr_number": ${PR_NUMBER}}`

Call `react_rocket` to signal implementation is complete.

---

**Fix Iteration Path (PR already exists):**

1. Checkout branch: `git fetch origin "$BRANCH" && git checkout "$BRANCH" && git pull origin "$BRANCH"`
2. Write PRD locally (same as 2.3).
3. Run: `export CI=true` then `/prdx:implement {SLUG}`
4. Push: `git push origin "$BRANCH"`
5. Call `react_rocket` to signal fixes are applied. (The workflow already reacted `eyes` on the trigger comment.)
