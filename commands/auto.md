---
description: "Run PRDX in auto (non-interactive) mode (plan-only or implement from issue)"
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

# /prdx:auto - Auto (Non-Interactive) Mode Workflow

Runs PRDX in non-interactive mode. Requires `--issue`. Supports `--plan-only` (generate PRD as issue comment) or full implement (PRD → branch → PR).

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

Capture the working reaction ID (posts `eyes` on the trigger comment or issue — see Reactions & Output Discipline):
```bash
WORKING_REACTION_ID=$(react_working)
```
Remember this value — every successful flow below ends with `react_done "$WORKING_REACTION_ID"`.

Route: `--plan-only` → Step 1 | otherwise → Step 2.

---

## Reactions & Output Discipline

Status is communicated **only** through GitHub reactions. The reaction transitions `eyes` 👀 (working) → `rocket` 🚀 (done) on a single target. That target is the **triggering comment** if `TRIGGER_COMMENT_ID` is set (e.g., a user's `@claude revise` comment), otherwise the **issue itself** (e.g., an external watcher tool running `/prdx:auto --issue N --plan-only` on a fresh issue with no trigger comment).

**Never post status comments on the issue** — no "Planning complete", no "PRD revised", no "Created PR #X", no changelogs. The only Claude-authored comment on the issue should be the PRD body itself (step 1.5 / 1.6). Everything else is a reaction transition.

**GitHub reaction limitation:** only 8 values are accepted — `+1`, `-1`, `laugh`, `confused`, `heart`, `hooray`, `rocket`, `eyes`. Hammer, wrench, and check are not available at the API level.

### Helpers

```bash
# POST an "eyes" reaction on the trigger comment (if set) or the issue.
# Prints the reaction's numeric ID to stdout (empty on failure).
# Idempotent: POSTing the same reaction twice from the same user returns the
# existing reaction's ID, so this works even if the workflow's
# `Acknowledge comment` step already reacted eyes.
react_working() {
  local repo
  repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
  [ -z "$repo" ] && return 0
  if [ -n "$TRIGGER_COMMENT_ID" ]; then
    gh api "repos/$repo/issues/comments/$TRIGGER_COMMENT_ID/reactions" \
      -X POST -f content="eyes" --jq '.id' 2>/dev/null
  elif [ -n "$ISSUE_NUMBER" ]; then
    gh api "repos/$repo/issues/$ISSUE_NUMBER/reactions" \
      -X POST -f content="eyes" --jq '.id' 2>/dev/null
  fi
}

# DELETE the given eyes reaction (by ID), then POST a rocket reaction on the
# same target. Same target-selection rules as react_working.
# Args: $1 = working reaction ID (optional — if empty, just posts rocket)
react_done() {
  local working_id="$1"
  local repo
  repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
  [ -z "$repo" ] && return 0
  if [ -n "$TRIGGER_COMMENT_ID" ]; then
    [ -n "$working_id" ] && gh api "repos/$repo/issues/comments/$TRIGGER_COMMENT_ID/reactions/$working_id" -X DELETE >/dev/null 2>&1 || true
    gh api "repos/$repo/issues/comments/$TRIGGER_COMMENT_ID/reactions" -X POST -f content="rocket" >/dev/null 2>&1 || true
  elif [ -n "$ISSUE_NUMBER" ]; then
    [ -n "$working_id" ] && gh api "repos/$repo/issues/$ISSUE_NUMBER/reactions/$working_id" -X DELETE >/dev/null 2>&1 || true
    gh api "repos/$repo/issues/$ISSUE_NUMBER/reactions" -X POST -f content="rocket" >/dev/null 2>&1 || true
  fi
}
```

### Usage pattern

Early in Setup, capture the working reaction's ID:
```bash
WORKING_REACTION_ID=$(react_working)
```
Do the work. At the end of each successful flow, transition to done:
```bash
react_done "$WORKING_REACTION_ID"
```

### Final text output — CRITICAL

`anthropics/claude-code-action@v1` posts your final text response as an issue comment automatically. Your final response **MUST be empty** — emit nothing. No words, no emoji, no summary, no "here's what I did", no tables, no links. Reactions carry all status; any final text becomes visible noise on the issue.

Bad final response:
> PRD revised with iOS parity (#65, PR #77). Key changes: matched iOS string copy across all 4 locales...

Good final response:
> *(empty)*

---

## Step 1: Plan-Only Path

Generates a PRD and posts it as an issue comment.

**1.1: Derive slug, detect platform and project:**

- `{SLUG}`: Extract core concept from `ISSUE_TITLE` (2-4 words max, kebab-case). Strip filler words (add, implement, create, update, fix, refactor, improve) and prepositions — keep domain nouns and key verbs.
- Platform: check directories, config files, issue title keywords (single-platform only).
- Project: from Pre-Computed Context `PROJECT_NAME`.

**1.2: Check for existing PRD comment:**

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
PRD_COMMENT=$(gh api "repos/$REPO/issues/$ISSUE_NUMBER/comments" --paginate \
  --jq '[.[] | select(.body | contains("<!-- prdx-prd -->"))] | last' 2>/dev/null)
```

- **No PRD comment (fresh plan):** Continue to 1.3. (The workflow has already reacted `eyes` on the trigger comment.)
- **PRD comment exists (revision):** Jump to 1.6.

**1.3: Explore codebase** via `prdx:code-explorer` agent. Pass `ISSUE_TITLE` + `ISSUE_BODY`.

**1.4: Generate PRD content** using the full PRD template (do NOT write a file).

**Writing style — compress prose, keep technical substance exact:**

- **Drop:** articles, filler (just/really/basically/actually/simply/currently), pleasantries, hedging, preambles, connective fluff (however/furthermore/additionally), "in order to" → "to". Don't restate the title in Problem.
- **Preserve exactly:** code blocks, inline `backticks`, file paths, function/API names, tables, numbers, error messages (quoted exact).
- **Style:** fragments OK, active voice, short synonyms. Pattern: `[thing] [action] [reason]. [next step].`
- **Budgets:** Problem 1-3 sentences. Goal 1 sentence. ACs start with a verb, testable, no inline explanation. Approach 1-3 sentences or numbered list (direction only). Risks `risk → consequence`, max 2.

**Before / after — AC:**
- Verbose: *When a B2B user attempts to take an asset outside its home location's configured geofence zone, the API returns a 400 error with message "Cannot take asset outside permitted area"*
- Compressed: *Reject B2B take outside geofence → 400 "Cannot take asset outside permitted area"*

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

**1.5: Post PRD as issue comment (upsert):**

```bash
PRD_BODY="{FULL PRD CONTENT}"
source "$(git rev-parse --show-toplevel)/hooks/prdx/upsert-prd-comment.sh"
upsert_prd_comment "$ISSUE_NUMBER" "$PRD_BODY"
# PRD_COMMENT_ID and PRD_COMMENT_URL are now exported
```

The helper prepends `<!-- prdx-prd -->` idempotently and PATCHes any existing marker comment in place, falling back to POST when none exists.

Transition the reaction:
```bash
react_done "$WORKING_REACTION_ID"
```
Your final text response must be empty — see Reactions & Output Discipline.

---

**1.6: Revision path (existing PRD comment):**

1. Fetch existing PRD comment:
   ```bash
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
4. Generate revised PRD content (without the marker — the helper adds it).
5. Update the PRD comment in place via the upsert helper. If the previously-detected comment was deleted between detection and write, the helper falls back to creating a new comment:
   ```bash
   # NOTE: feedback query above (sub-step 2) must run before this upsert — uses pre-upsert PRD_COMMENT_ID
   PRD_BODY="{REVISED PRD CONTENT}"
   source "$(git rev-parse --show-toplevel)/hooks/prdx/upsert-prd-comment.sh"
   upsert_prd_comment "$ISSUE_NUMBER" "$PRD_BODY"
   # PRD_COMMENT_ID and PRD_COMMENT_URL are now exported
   ```
6. Transition the reaction: `react_done "$WORKING_REACTION_ID"`. Your final text response must be empty — see Reactions & Output Discipline.

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
PRD_COMMENT=$(gh api "repos/$REPO/issues/$ISSUE_NUMBER/comments" --paginate \
  --jq '[.[] | select(.body | contains("<!-- prdx-prd -->"))] | last' 2>/dev/null)
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

Write state: `{"slug": "${SLUG}", "phase": "review", "quick": false, "pr_number": ${PR_NUMBER}}`

Do NOT post a status comment — the PR is automatically linked to the issue via `Closes #{ISSUE_NUMBER}` in the PR body, which creates a cross-reference in the issue timeline. Transition the reaction: `react_done "$WORKING_REACTION_ID"`. Your final text response must be empty — see Reactions & Output Discipline.

---

**Fix Iteration Path (PR already exists):**

1. Checkout branch: `git fetch origin "$BRANCH" && git checkout "$BRANCH" && git pull origin "$BRANCH"`
2. Write PRD locally (same as 2.3).
3. Run: `export CI=true` then `/prdx:implement {SLUG}`
4. Push: `git push origin "$BRANCH"`
5. Transition the reaction: `react_done "$WORKING_REACTION_ID"`. Your final text response must be empty — see Reactions & Output Discipline.
