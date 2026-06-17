---
description: "Run PRDX in auto (non-interactive) mode (plan-only or implement from issue/prompt/file)"
argument-hint: "(--issue <n> | --prompt <text> | --file <path>) [--slug <slug>] [--plan-only] [--requested-by <user>]"
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

Runs PRDX in non-interactive mode. Takes input from **one** of `--issue`, `--prompt`, or `--file`. Supports `--plan-only` (generate PRD) or full implement (PRD → branch → PR).

Two surfaces share one orchestration core; they differ only in **input adapter** (where the PRD request comes from) and **output adapter** (where status/results go):

| Surface | Detected by | Input | Output |
|---------|-------------|-------|--------|
| **GitHub** (Action) | `GITHUB_ACTIONS=true` | `--issue N` | reactions + issue comment + PR; **empty final text** |
| **Headless** (local `claude -p`) | not under Action | `--prompt` / `--file` / `--issue` | PRD file in PLANS_DIR + plain-text stdout summary + (optional) PR |

## Prerequisites

- Exactly one input adapter: `--issue {number}` | `--prompt "{text}"` | `--file {path}`
- `.prdx/plans-setup-done` must exist (error if missing)
- `gh auth status` must pass (required for `--issue` and for PR creation; optional for `--prompt`/`--file` plan-only)

## Setup

Parse flags: `--issue {number}` | `--prompt "{text}"` | `--file {path}` (exactly one), plus `--slug {slug}`, `--requested-by {user}`, `--plan-only`.

**Detect the surface** — this drives every adapter choice below:
```bash
if [ "$GITHUB_ACTIONS" = "true" ]; then SURFACE="github"; else SURFACE="headless"; export PRDX_HEADLESS=1; fi
export CI=true   # bypass interactive hook prompts on both surfaces
```

**Input adapter** — resolve `ISSUE_TITLE` + `ISSUE_BODY` (the PRD request) from whichever flag was given:
- `--issue N`: `gh issue view {ISSUE_NUMBER} --json title,body,labels` → `ISSUE_TITLE` + `ISSUE_BODY`. (Only this adapter participates in the GitHub reaction/comment flow.)
- `--prompt "..."`: `ISSUE_BODY` = the prompt text; `ISSUE_TITLE` = first line (or a 3-6 word summary). No issue, no reactions.
- `--file path.md`: read the file; `ISSUE_TITLE` = first `# ` heading or filename; `ISSUE_BODY` = file contents.

Derive `{SLUG}`: use `--slug` if given, else derive from `ISSUE_TITLE` (same rule as Step 1.1).

If `--requested-by` provided, configure git author:
```bash
REQUESTOR_NAME=$(gh api "users/${REQUESTOR}" --jq '.name // .login' 2>/dev/null || echo "$REQUESTOR")
export GIT_AUTHOR_NAME="$REQUESTOR_NAME"
export GIT_AUTHOR_EMAIL="${REQUESTOR}@users.noreply.github.com"
```

**GitHub surface only** — capture the working reaction ID (posts `eyes` on the trigger comment or issue — see Reactions & Output Discipline):
```bash
[ "$SURFACE" = "github" ] && WORKING_REACTION_ID=$(react_working)
```
On the GitHub surface, every successful flow ends with `react_done "$WORKING_REACTION_ID"`. On the headless surface, reactions are no-ops — see Output Adapters.

**Session resume (headless):** if resuming a prior conversation, the operator's wrapper invokes `claude -p --resume <id>` (see Headless Output Adapters for the contract) — that restores context *before* this command runs, so no special handling here. This command's job is only to *record* its session id after a fresh run, which the wrapper does via `session_store`.

Route: `--plan-only` → Step 1 | otherwise → Step 2.

---

## Output Adapters

The output adapter is chosen by `SURFACE` (set in Setup). The orchestration core is identical; only reporting differs.

### Headless surface (`SURFACE=headless`)

No GitHub, no reactions. Report results to the local filesystem + stdout:

- **Plan-only:** write the PRD to `$PLANS_DIR/prdx-{SLUG}.md` (do NOT post an issue comment). Final stdout = a one-line confirmation + the PRD path.
- **Implement:** after the loop, emit a plain-text summary to stdout — slug, branch, AC pass/fail, any `## Items Requiring Input` review findings (from `reviews/code-review.md`), and the PR URL if one was created. Unlike the GitHub surface, **the final text response is the deliverable** — do not suppress it.
- **Session id:** the operator's wrapper captures `session_id` from `claude -p --output-format json` and persists it via `session_store {SLUG} {id}` (see contract below). This command does not capture its own id.

`react_working` / `react_done` are no-ops here (they early-return when no repo/issue context applies), so the GitHub steps below are simply skipped.

**Headless resume contract (operator wrapper):**
```bash
# First run — capture and store the session id:
OUT=$(claude -p "/prdx:auto --prompt 'Add rate limiting' --slug rate-limit" --output-format json)
SID=$(echo "$OUT" | jq -r '.session_id')
source hooks/prdx/resolve-plans-dir.sh && source hooks/prdx/resolve-session.sh
session_store rate-limit "$SID"

# Later — user replied; resume the SAME conversation (context restored, no re-explore):
session_resolve rate-limit
case "$SESSION_MODE" in
  resumable)   claude -p --resume "$SESSION_ID" "User reply: prefer a token bucket" ;;
  reconstruct) claude -p "/prdx:auto --slug rate-limit" ;;   # rebuild from shards
  cold)        claude -p "/prdx:auto --prompt '...' --slug rate-limit" ;;
esac
```
prdx supplies `session_store`/`session_resolve` and detects whether the session survived; the wrapper owns invoking `claude -p` and whether `~/.claude/projects/` persists.

### GitHub surface (`SURFACE=github`)

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

### Final text output — CRITICAL (GitHub surface only)

This rule applies **only when `SURFACE=github`**. On the headless surface the final text IS the deliverable (see Headless surface above) — emit the summary.

On the GitHub surface: `anthropics/claude-code-action@v1` posts your final text response as an issue comment automatically. Your final response **MUST be empty** — emit nothing. No words, no emoji, no summary, no "here's what I did", no tables, no links. Reactions carry all status; any final text becomes visible noise on the issue.

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

**1.5: Emit the PRD (output adapter):**

**Headless surface:** write the PRD to the local plan file and finish — no issue comment.
```bash
mkdir -p "$PLANS_DIR"
printf '%s\n' "{FULL PRD CONTENT}" > "$PLANS_DIR/prdx-${SLUG}.md"
```
Final stdout: one-line confirmation + the path `$PLANS_DIR/prdx-${SLUG}.md`. Done.

**GitHub surface:** post PRD as issue comment (upsert):
```bash
PRD_BODY="{FULL PRD CONTENT}"
source "$(git rev-parse --show-toplevel)/hooks/prdx/upsert-prd-comment.sh"
upsert_prd_comment "$ISSUE_NUMBER" "$PRD_BODY"
# PRD_COMMENT_ID and PRD_COMMENT_URL are now exported
```
The helper prepends `<!-- prdx-prd -->` idempotently and PATCHes any existing marker comment in place, falling back to POST when none exists. Then transition the reaction and emit empty final text:
```bash
react_done "$WORKING_REACTION_ID"
```
(empty final response — see Reactions & Output Discipline)

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

> This revision path is GitHub-specific (it edits the issue's PRD comment). On the headless surface, "revision" is just re-running plan-only with the same `--slug` — Step 1.5's headless branch overwrites `$PLANS_DIR/prdx-${SLUG}.md` in place, or the operator resumes the session (`--resume`) to revise with full context.

---

## Step 2: Implement Path

Reads PRD from issue comment, implements it, creates branch and PR. If PR already exists, applies fixes.

**2.1: Derive slug and detect platform:**

Derive `{SLUG}` from `ISSUE_TITLE` (same logic as 1.1). Determine branch: `BRANCH="{TYPE_PREFIX}/{SLUG}"`.

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
PROJECT_NAME=$(echo "$REPO" | cut -d'/' -f2)
```

**2.2: Find the PRD (input adapter):**

**Headless surface** (`--prompt`/`--file`, no issue): the PRD lives locally at `$PLANS_DIR/prdx-${SLUG}.md`.
- `--file path.md`: copy it into place if not already there: `cp path.md "$PLANS_DIR/prdx-${SLUG}.md"`.
- `--prompt` with no existing plan file: run the Step 1 plan-generation logic first to produce `$PLANS_DIR/prdx-${SLUG}.md`, then continue.
- A plan file already present (e.g. prior `--plan-only` run): use it as-is.

Set `PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null)` (empty if no remote), then skip to 2.3 using the local file as the PRD source.

**GitHub surface** (`--issue`): fetch the PRD from the issue comment:
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
{"slug": "${SLUG}", "phase": "implementing", "lite": false}
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

Write state: `{"slug": "${SLUG}", "phase": "review", "lite": false, "pr_number": ${PR_NUMBER}}` (preserve any existing `session_id` key — merge, don't overwrite the file).

**Headless surface:** emit the stdout summary (slug, branch, AC status, `## Items Requiring Input` findings from `reviews/code-review.md`, PR URL if created). The final text is the deliverable.

**GitHub surface:** do NOT post a status comment — the PR is auto-linked to the issue via `Closes #{ISSUE_NUMBER}` in the PR body. Transition the reaction: `react_done "$WORKING_REACTION_ID"`. Final text response must be empty — see Reactions & Output Discipline.

---

**Fix Iteration Path (PR already exists):**

1. Checkout branch: `git fetch origin "$BRANCH" && git checkout "$BRANCH" && git pull origin "$BRANCH"`
2. Write PRD locally (same as 2.3).
3. Run: `export CI=true` then `/prdx:implement {SLUG}`
4. Push: `git push origin "$BRANCH"`
5. **Headless:** emit the stdout summary (slug, branch, PR URL). **GitHub:** transition the reaction `react_done "$WORKING_REACTION_ID"`; final text response must be empty — see Reactions & Output Discipline.
