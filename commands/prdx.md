---
description: "Complete PRD workflow: plan → implement → push"
argument-hint: "[--quick] [--ci] [--issue <number>] [--plan-only] [--requested-by <user>] [feature description or PRD slug]"
---

# /prdx:prdx - Complete Feature Workflow

> **Main entry point for PRDX.**
> Orchestrates the complete feature development workflow with decision points.
> Use `--quick` for ephemeral tasks that need the full pipeline but not a permanent PRD.

## Workflow

Execute the following phases based on the argument provided:

### Resolve Plans Directory

Read the configured plans directory from `prdx.json`, falling back to `.prdx/plans` if not set:

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
```

**Use `$PLANS_DIR` throughout this command.**

### Step 0: Auto-Capture Lessons from Merged PRs

**Before any other logic, check if this is the first PRDX run in this project (Plans Directory Setup).**

Check if plans directory has been configured:

```bash
ls .prdx/plans-setup-done 2>/dev/null
```

If the file does NOT exist (first PRDX run in this project):

**If `CI_MODE=true`:** Skip to Step 1 — CI mode validates plans-setup-done separately and never prompts.

1. Auto-configure project-local plans (no user prompt):
   ```bash
   PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
   mkdir -p .claude .prdx "$PLANS_DIR"
   if [ -f .claude/settings.local.json ]; then
     jq --arg dir "$PLANS_SUBDIR" '. + {plansDirectory: $dir}' .claude/settings.local.json > .claude/settings.local.json.tmp && mv .claude/settings.local.json.tmp .claude/settings.local.json
   else
     echo "{\"plansDirectory\": \"$PLANS_SUBDIR\"}" > .claude/settings.local.json
   fi
   echo "local" > .prdx/plans-setup-done
   ```

2. Re-resolve PLANS_DIR after setup.

If the file DOES exist, skip this step entirely and proceed with the gitignore check below.

**After the setup check (or if already configured), ensure `.prdx/` is fully ignored (runs every time):**

```bash
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ ! -f "$GITIGNORE" ] || ! { grep -qxF '.prdx/' "$GITIGNORE" || grep -qxF '.prdx/*' "$GITIGNORE"; }; then
  echo '' >> "$GITIGNORE"
  echo '# PRDX' >> "$GITIGNORE"
  echo '.prdx/' >> "$GITIGNORE"
fi
```

**Lesson capture and plan cleanup are handled by the scheduled CI workflow (`/prdx:cleanup`).** No startup scan is performed.

---

### Step 1: Determine Entry Point

**First, check for active workflow state:**

```bash
ls .prdx/state/*.json 2>/dev/null
```

If state files exist and **no argument was provided**, auto-resume if exactly one active (non-pushed, non-completed) state file exists; otherwise list and let user pick.

If exactly one active state file exists, route by `phase`:

| phase | action |
|-------|--------|
| `"planning"` | Fall through to normal Step 1 logic below |
| `"post-planning"` | Show post-planning decision via AskUserQuestion (see options below) |
| `"implementing"` | Jump to Phase 3, using slug from state file |
| `"post-implement"` | Jump to Phase 3a (review decision), using slug from state file |
| `"reviewing"` | Jump to Step 3b (reviewing loop), using slug + pr_number |
| `"pushing"` | Check if PR was actually created: `gh pr list --head {BRANCH} --json number --jq '.[0].number'`. If PR exists → transition to `"pushed"` + inform user. If no PR → transition to `"post-implement"` + offer to retry with `/prdx:push {slug}` |
| `"pushed"` | Inform user PR isn't merged yet. Ignore this state file and continue with normal Step 1 logic. |
| `"completed"` | Delete stale state file and continue with normal Step 1 logic |

**Post-planning decision point** (AskUserQuestion):
- **Normal mode**: Option 1: "Publish to GitHub" → Phase 2a | Option 2: "Implement now" → Phase 3 | Option 3: "Stop here"
- **Quick mode**: Option 1: "Implement now" (Recommended) | Option 2: "Stop here"

If no active state file qualifies (or no state files exist), continue with normal logic below.

---

**Next, parse `--quick` flag:**
- Strip `--quick` from arguments if present (can appear anywhere in the argument string)
- If `--quick` is present:
  - Remaining text MUST be a description (not a slug) — error if empty
  - Error: `--quick requires a description. Usage: /prdx:prdx --quick "fix login validation"`
  - Set `QUICK_MODE=true`, skip PRD matching, go directly to Phase 2 (planning)
- If `--quick` is NOT present, continue with normal entry point logic below

**Next, parse `--ci`, `--issue`, and `--requested-by` flags:**
Strip `--ci`, `--issue {number}`, `--requested-by {user}`, and `--plan-only` from the argument string, capturing their values.

**If `--issue` present:** Set `HAS_ISSUE=true`, `ISSUE_NUMBER`. Fetch: `gh issue view {ISSUE_NUMBER} --json title,body,labels`. Error if not found. Store `ISSUE_TITLE` + `ISSUE_BODY` as feature description.

**If `--ci` present:** Set `CI_MODE=true`. Require `--issue` (error: `--ci requires --issue`). Configure git author if `--requested-by` provided:
```bash
REQUESTOR_NAME=$(gh api "users/${REQUESTOR}" --jq '.name // .login' 2>/dev/null || echo "$REQUESTOR")
export GIT_AUTHOR_NAME="$REQUESTOR_NAME"
export GIT_AUTHOR_EMAIL="${REQUESTOR}@users.noreply.github.com"
```
Skip state-file resume scan. Require `.prdx/plans-setup-done` (error if missing). Validate `gh auth status`. Route: `PLAN_ONLY=true` → Step 2-CI | `PLAN_ONLY=false` → Step 3-CI.

**If `--plan-only` present:** Set `PLAN_ONLY=true`. Require both `--ci` and `--issue` (error: `--plan-only requires --ci and --issue`).

**If `--ci` NOT present:** Continue with normal entry point logic (issue data available via `HAS_ISSUE` if `--issue` was provided).

**If the argument matches an existing PRD** (resolve using enhanced matching: exact → substring → word-boundary → disambiguation; see `/prdx:implement` for full algorithm):
- Read PRD and check its `**Status:**` field
- **Detect quick mode from PRD:** If the PRD contains `**Quick:** true`, set `QUICK_MODE=true` internally
- **For parent PRDs** (has `## Children` section): Read child state files from `.prdx/state/` to determine progress. Display the child progress table (same as implement.md Step 2b). If all children are at `review` or beyond, ask if user wants to push each child. Otherwise, show which children still need work and display session instructions.
- **For single-platform and child PRDs**, resume from the appropriate phase:
  - `planning` → Continue planning (Phase 2)
  - `in-progress` → Continue implementation (Phase 3)
  - `review` → Ask user: Fix issues OR Create PR? (Phase 3a)
  - `implemented` → Check PRD for `## Pull Request` section with PR metadata. If PR exists, enter reviewing loop (Step 3b) with PR number from PRD. If no PR, inform user and suggest `/prdx:push`
  - `completed` → Inform user the PRD is done

**If the argument is a feature description** (not an existing PRD):
- Proceed to Phase 2 (planning)

**If no argument provided**:

Scan `.prdx/state/*.json` for active state files (phase NOT `"pushed"` or `"completed"`). Present via AskUserQuestion:
- One active state file: "Continue {slug}" (Recommended) | "Choose a different PRD" | "Start a new feature"
- Multiple active: list all (slug, phase, quick) + "Start a new feature"
- None: list existing project PRDs (`grep -rl "^\*\*Project:\*\* $PROJECT_NAME" {PLANS_DIR}/*.md`) and ask: "Start a new feature or continue an existing PRD?"

---

### Step 2: Planning

**⛔ SCOPE: This step ONLY creates a PRD document. No application code, no branches, no implementation.** `/prdx:plan` enters plan mode to write a document. When the user approves the document, plan mode exits and a decision point is shown. Implementation happens in Step 3 — ONLY if the user chooses "Implement now".

**If QUICK_MODE:**

Run the planning command with the `--quick` flag:

```
/prdx:plan --quick [description]
```

This enters plan mode with a lightweight template (Problem, Goal, Acceptance Criteria, Approach only). The PRD is saved as `prdx-quick-{slug}.md`. Plan.md derives the slug from the description early (Step 0) and writes the state file immediately — no tentative IDs needed.

> **MANDATORY:** During planning, ALL codebase exploration MUST use `prdx:code-explorer` and `prdx:docs-explorer` agents via the Task tool. NEVER use the built-in `Explore` subagent, Glob, Grep, or Read for exploration. See `/prdx:plan` for details.

**IMPORTANT: Stop here and wait.** Plan mode is interactive. Do NOT proceed until:
1. Plan mode has completed (user approved the plan and ExitPlanMode was called)
2. The PRD file exists in `{PLANS_DIR}/prdx-quick-{slug}.md`

**⛔ AFTER PLAN MODE EXITS: Plan.md will show an AskUserQuestion decision point. Wait for the user's choice. DO NOT start implementing.**

Route based on the user's choice from plan.md:
- Implement → Phase 3
- Stop → End workflow. Tell user they can resume with `/prdx:prdx quick-{slug}`

**⛔ SAFETY CHECK:** If you find yourself about to call `/prdx:implement` or start writing code without the user explicitly choosing "Implement now" from the decision point above — STOP. You have skipped a mandatory decision point. Go back and ask the user.

**If NOT QUICK_MODE (normal mode):**

Run the planning command with the feature description:

```
/prdx:plan [description]
```

**If `HAS_ISSUE=true`:** Pass the issue context to plan mode as the description: `"{ISSUE_TITLE}. {ISSUE_BODY}"`. This gives plan mode the full issue content to work with.

This enters native plan mode and creates a PRD following the PRDX template format. Plan.md derives the slug from the description early (Step 0) and writes the state file immediately — no tentative IDs needed.

> **MANDATORY:** During planning, ALL codebase exploration MUST use `prdx:code-explorer` and `prdx:docs-explorer` agents via the Task tool. NEVER use the built-in `Explore` subagent, Glob, Grep, or Read for exploration. See `/prdx:plan` for details.

**IMPORTANT: Stop here and wait.** Plan mode is an interactive process where the user reviews and iterates on the PRD. Do NOT proceed to implementation until:
1. Plan mode has completed (user approved the plan and ExitPlanMode was called)
2. The PRD file exists in `{PLANS_DIR}/prdx-{slug}.md`

**⛔ AFTER PLAN MODE EXITS: Plan.md will show an AskUserQuestion decision point. Wait for the user's choice. DO NOT start implementing.**

**If `HAS_ISSUE=true`:** After plan mode exits and before showing the decision point, automatically comment the PRD on the issue:

```bash
gh issue comment {ISSUE_NUMBER} --body "$(cat <<'PRDBODY'
## PRDX: Generated PRD

---

{FULL PRD CONTENT}
PRDBODY
)"
```

Display: `PRD commented on issue #{ISSUE_NUMBER}`

Route based on the user's choice from plan.md:
- Publish → Phase 2a (then ask about implementation)
- Implement → Phase 3
- Stop → End workflow. Tell user they can resume with `/prdx:prdx [slug]`

**⛔ SAFETY CHECK:** If you find yourself about to call `/prdx:implement` or start writing code without the user explicitly choosing "Implement now" from the decision point above — STOP. You have skipped a mandatory decision point. Go back and ask the user.

---

### Step 2a: Publish (Optional)

If user chose to publish:

```
/prdx:publish [slug]
```

After issue is created, use AskUserQuestion:
- Option 1: "Yes, start implementation"
- Option 2: "No, I'll implement later"

Route based on choice:
- Yes → Phase 3
- No → End workflow (keep state file for future resume)

---

### Step 2-CI: Plan-Only Path (CI Mode)

**This step runs ONLY when `CI_MODE=true` and `PLAN_ONLY=true`.** It generates a PRD and posts it as an issue comment.

**CI progress comment helper** (used throughout CI steps):
```bash
# POST_PROGRESS: post a progress comment and store its ID
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
RUN_URL="${GITHUB_SERVER_URL}/${REPO}/actions/runs/${GITHUB_RUN_ID}"
PROGRESS_COMMENT_ID=$(gh issue comment "$ISSUE_NUMBER" --body "> {MESSAGE} 🔨
>
> [View job run]($RUN_URL)" | grep -o 'https://[^ ]*' | grep -o '[0-9]*$')

# UPDATE_PROGRESS: update an existing progress comment
gh api "repos/$REPO/issues/comments/$PROGRESS_COMMENT_ID" -X PATCH -f body="{DONE_MESSAGE}"
```

Use this pattern wherever a progress comment is posted or updated. Substitute `{MESSAGE}` / `{DONE_MESSAGE}` with the relevant status text.

**2-CI.1: Derive slug, detect platform and project:**

- `{SLUG}`: Extract core concept from `ISSUE_TITLE` (2-4 words max, kebab-case). Strip filler words (add, implement, create, update, fix, refactor, improve) and prepositions — keep domain nouns and key verbs. Examples: "Read monthly report from Firestore" → `monthly-report-read`, "Add biometric authentication" → `biometric-auth`.
- Platform: check directories, config files, issue title keywords (single-platform only — CI mode does not support multi-platform).
- Project: `PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)`

**2-CI.2: Check for existing PRD comment:**

```bash
PRD_COMMENT=$(gh issue view "$ISSUE_NUMBER" --json comments --jq '[.comments[] | select(.body | contains("<!-- prdx-prd -->"))] | last' 2>/dev/null)
```

- **No PRD comment (fresh plan):** Post progress comment (`Planning...`), then continue to 2-CI.3.
- **PRD comment exists (revision):** Jump to 2-CI.6.

**2-CI.3: Explore codebase** via `prdx:code-explorer` agent. Pass `ISSUE_TITLE` + `ISSUE_BODY`. Ask for patterns, architecture, and conventions relevant to the issue.

**2-CI.4: Generate PRD content** using the full PRD template (do NOT write a file):

```markdown
# {ISSUE_TITLE}

**Type:** {auto-detected}
**Project:** {PROJECT_NAME}
**Platform:** {DETECTED_PLATFORM}
**Status:** planning
**Created:** {TODAY}

## Problem
{From ISSUE_BODY — problem statement}

## Goal
{From issue title/body — desired outcome}

## Acceptance Criteria
{From ISSUE_BODY checkboxes/lists, or derive 2-3 testable criteria}

## Approach
{From codebase exploration — high-level strategy}

## Risks & Considerations
{1-2 risks from codebase exploration}
```

**2-CI.5: Post PRD as issue comment:**

```bash
PRD_COMMENT_ID=$(gh issue comment "$ISSUE_NUMBER" --body "$(cat <<'PRDBODY'
<!-- prdx-prd -->
{FULL PRD CONTENT}
PRDBODY
)" | grep -o 'https://[^ ]*' | grep -o '[0-9]*$')
```

Update progress comment: `"Planning complete. PRD posted above — review it and comment \`@claude implement\` when ready, or \`@claude revise\` with feedback."`

Display: `CI Planning Complete! PRD posted on issue #{ISSUE_NUMBER}. Comment \`@claude implement\` when ready.`

---

**2-CI.6: Revision path (existing PRD comment):**

Runs when `--plan-only` is used and a PRD comment already exists.

1. Post progress comment: `Revising PRD...`
2. Fetch existing PRD comment and content:
   ```bash
   PRD_COMMENT=$(gh issue view "$ISSUE_NUMBER" --json comments --jq '[.comments[] | select(.body | contains("<!-- prdx-prd -->"))] | last' 2>/dev/null)
   PRD_COMMENT_ID=$(echo "$PRD_COMMENT" | jq -r '.databaseId // .id' 2>/dev/null)
   PRD_COMMENT_BODY=$(echo "$PRD_COMMENT" | jq -r '.body' 2>/dev/null)
   ```
3. Read feedback comments posted after the PRD comment:
   ```bash
   gh issue view "$ISSUE_NUMBER" --json comments --jq \
     --argjson prd_id "$PRD_COMMENT_ID" \
     '[.comments[] | select((.databaseId // .id) > $prd_id) | .body] | join("\n---\n")' 2>/dev/null
   ```
4. Re-explore codebase if needed (same as 2-CI.3).
5. Generate revised PRD incorporating feedback (keep `<!-- prdx-prd -->` marker).
6. Update PRD comment in-place:
   ```bash
   gh api "repos/$REPO/issues/comments/$PRD_COMMENT_ID" -X PATCH -f body="<!-- prdx-prd -->
   {REVISED PRD CONTENT}"
   ```
7. Update progress comment: `"PRD revised. Review the updated comment and comment \`@claude implement\` when ready."`

Display: `PRD Revised! PRD comment updated on issue #{ISSUE_NUMBER}.`

---

### Step 3-CI: Implement Path (CI Mode)

**This step runs ONLY when `CI_MODE=true` and `PLAN_ONLY=false`.** It reads the PRD from an issue comment and implements it, creating a new branch and PR. If a PR already exists for the branch, it applies fixes to the existing branch instead.

**3-CI.1: Derive slug and detect platform:**

Derive `{SLUG}` from `ISSUE_TITLE` by extracting the core concept (2-4 words max, same logic as 2-CI.1).

Determine branch name:
```bash
# Auto-detect type from issue title/body
BRANCH="{TYPE_PREFIX}/{SLUG}"
```

Detect platform same as 2-CI.1. Detect `REPO` and `PROJECT_NAME`:
```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
PROJECT_NAME=$(echo "$REPO" | cut -d'/' -f2)
```

**3-CI.2: Find PRD from issue comment:**

```bash
PRD_COMMENT=$(gh issue view "$ISSUE_NUMBER" --json comments --jq '[.comments[] | select(.body | contains("<!-- prdx-prd -->"))] | last' 2>/dev/null)
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null)
```

| condition | action |
|-----------|--------|
| PRD found + PR exists | Fix iteration path (below) |
| PRD found + no PR | Fresh implementation — post progress comment (`Implementing...`), continue to 3-CI.3 |
| No PRD + PR exists | Find linked issue from PR body (`Closes #N`), fetch PRD from that issue |
| No PRD + no PR | Error: `No PRD found for issue #{ISSUE_NUMBER}. Run \`@claude plan\` first.` |

**3-CI.3: Write PRD locally and set up branch:**

```bash
PRD_BODY=$(echo "$PRD_COMMENT" | jq -r '.body' 2>/dev/null)
mkdir -p "$PLANS_DIR"
echo "$PRD_BODY" | sed 's/<!-- prdx-prd -->//' > "$PLANS_DIR/prdx-${SLUG}.md"
git checkout -b "$BRANCH"
```

**3-CI.4: Run implement:**

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

**3-CI.5: Push and create PR:**

```bash
git push -u origin "$BRANCH"
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
```

Invoke `prdx:pr-author` agent: create a real (non-draft) PR. Include `Closes #{ISSUE_NUMBER}` in body. Footer: `Comment \`@claude review\` for code review.` After creation, add `$REQUESTOR` as reviewer if set.

**3-CI.6: Finalize:**

Update progress comment: `"Implementation complete. PR #${PR_NUMBER} created. Comment \`@claude review\` for code review."`

Write state: `{"slug": "${SLUG}", "phase": "review", "quick": false, "pr_number": ${PR_NUMBER}}`

Display: `CI Implementation Complete! Issue: #{ISSUE_NUMBER} | Branch: {BRANCH} | PR: #{PR_NUMBER}`

---

**Fix Iteration Path (PR already exists):**

1. Checkout branch: `git fetch origin "$BRANCH" && git checkout "$BRANCH" && git pull origin "$BRANCH"`
2. Write PRD locally (same as 3-CI.3 — `PRD_BODY` already fetched).
3. Post progress comment: `Applying fixes...`
4. Run: `export CI=true` then `/prdx:implement {SLUG}`
5. Push: `git push origin "$BRANCH"`
6. Update progress comment: `"Fixes applied to PR #${PR_NUMBER}. Comment \`@claude review\` for another code review."`

Display: `CI Fix Iteration Complete! Issue: #{ISSUE_NUMBER} | Branch: {BRANCH} | PR: #{PR_NUMBER} (fixes pushed)`

---

### Step 3: Implementation

**Update workflow state:**
```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "implementing", "quick": {QUICK_MODE}}
EOF
```

**Detect PRD type and route accordingly:**

**For parent PRDs** (has `## Children` section):

Parent PRDs delegate implementation to child PRDs in separate sessions. Run `/prdx:implement {slug}` which will display the child progress table and session instructions (see implement.md Step 2b). Then stop — do not proceed to review decision. The user resumes with `/prdx:prdx {slug}` after children are done.

```
/prdx:implement [slug]
```

After displaying instructions, end workflow. The user manages child sessions independently.

**For single-platform PRDs and child PRDs:**

```
/prdx:implement [slug]
```
Wait for implementation to complete, then proceed to review decision.

Write state: `{"slug": "{SLUG}", "phase": "post-implement", "quick": {QUICK_MODE}}`

**IMPORTANT: STOP and use AskUserQuestion:**

Do NOT proceed to create PR automatically. The user must test first.

**Quick mode options:** "Create PR" (Recommended) | "Create Draft PR" | "Done" (no PR) | "Test first"
- Create PR → `/prdx:push quick-{slug}` then Phase 5
- Create Draft PR → `/prdx:push quick-{slug} --draft` → state `"reviewing"` → Step 3b
- Done → Phase 5 immediately
- Test first → End workflow, resume with `/prdx:prdx quick-{slug}`

**Normal mode options:** "Test first" (Recommended) | "Create PR now" | "Create Draft PR"
- Test first → End workflow, resume with `/prdx:prdx [slug]`
- Create PR now → `/prdx:push [slug]` (no re-confirmation)
- Create Draft PR → `/prdx:push [slug] --draft` → state `"reviewing"` → Step 3b

---

### Step 3a: Review Status Decision

**When PRD status is `review`** — implementation complete but user hasn't confirmed readiness. Use AskUserQuestion:

**Quick mode:** "Create PR" (Recommended) | "Create Draft PR" | "Done" | "Fix issues"
- Create PR → `/prdx:push quick-{slug}` then Phase 5
- Create Draft PR → `/prdx:push quick-{slug} --draft` → state `"reviewing"` → Step 3b
- Done → Phase 5
- Fix issues → same as normal mode

**Normal mode:** "Create PR" (Recommended) | "Create Draft PR" | "Fix issues" | "View implementation summary"
- Create PR → `/prdx:push [slug]` (no re-confirmation)
- Create Draft PR → `/prdx:push [slug] --draft` → state `"reviewing"` → Step 3b
- Fix issues → ask user to describe; fix directly in conversation; commit; ask again (do NOT re-run `/prdx:implement`)
- View summary → show implementation notes from PRD, ask again

---

### Step 3b: Reviewing (Fix-Iterate Loop)

**When state file has phase `"reviewing"`, or PRD status is `implemented` with `## Pull Request` section:**

This loop lets the user iterate on PR review comments without leaving the workflow.

1. **Fetch PR context:**
   ```bash
   gh pr view {PR_NUMBER} --json state,isDraft,reviews,comments,title
   ```

2. **Fetch review comments (unresolved):**
   ```bash
   gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/comments --jq '[.[] | select(.position != null)] | sort_by(.created_at) | .[] | "- \(.path):\(.position) — \(.body | split("\n") | first)"'
   ```

3. **Fetch PR-level review comments:**
   ```bash
   gh pr view {PR_NUMBER} --json reviews --jq '.reviews[] | select(.state != "APPROVED") | "[\(.state)] \(.body | split("\n") | first)"'
   ```

4. **Display summary:**
   ```
   PR #{PR_NUMBER}: {TITLE}
   Status: {Draft/Open}
   Reviews: {count pending/changes-requested/approved}
   Comments: {count unresolved}

   Recent comments:
   - path/file.ts:42 — "This should validate the input..."
   - path/other.ts:15 — "Consider using the existing helper..."
   ```

5. **Decision point via AskUserQuestion:**

   **If draft PR:**
   - Option 1: "Fix from PR comments" — Auto-fetch and fix review comments
   - Option 2: "Fix manually" — Describe issues to fix
   - Option 3: "Mark ready for review" — Run `gh pr ready`, end workflow
   - Option 4: "Done" — End workflow without further action

   **If non-draft (entered via PRD resume):**
   - Option 1: "Fix from PR comments" — Auto-fetch and fix review comments
   - Option 2: "Fix manually" — Describe issues to fix
   - Option 3: "Done" — End workflow

6. **Fix routing:**

   **"Fix from PR comments":**
   - Fetch full comment details via `gh api`
   - Read the referenced files
   - Fix issues directly in conversation
   - Commit fixes (using prdx.json commit config — same as `/prdx:implement` Step 5 commit logic)
   - Push: `git push`
   - Loop back to step 1 of this phase (re-fetch, re-ask)

   **"Fix manually":**
   - Ask user to describe the issues
   - Fix directly in conversation
   - Commit fixes (using prdx.json commit config)
   - Push: `git push`
   - Loop back to step 1 of this phase

   **"Mark ready for review":**
   - Run `gh pr ready {PR_NUMBER}`
   - Update PRD status to `implemented`
   - Write state: `{"slug": "{SLUG}", "phase": "pushed", "quick": {QUICK_MODE}, "pr_number": {PR_NUMBER}}` (do NOT delete — enables lesson capture)
   - Display: `PR #{PR_NUMBER} marked ready for review. Lessons will be captured automatically after merge.`

   **"Done":**
   - Write state: `{"slug": "{SLUG}", "phase": "pushed", "quick": {QUICK_MODE}, "pr_number": {PR_NUMBER}}` (do NOT delete — PR exists, enables lesson capture)
   - Display: `Lessons will be captured automatically after PR #{PR_NUMBER} is merged.`

---

### Step 4: Create Pull Request

**Confirm before creating PR** — but only if the user hasn't already explicitly chosen "Create PR", "Create PR now", or "Create Draft PR" in a previous step. If they have, skip this confirmation and run `/prdx:push` directly (with `--draft` if they chose draft).

Use AskUserQuestion to confirm:
- Option 1: "Yes, create PR" - Ready to submit for review
- Option 2: "Yes, create Draft PR" — Mark as draft, not human-reviewed yet
- Option 3: "No, wait" - Need more time

Route based on choice:
- Create PR → Run `/prdx:push [slug]`
- Create Draft PR → Run `/prdx:push [slug] --draft`
- Wait → End workflow (keep state file for future resume)

**If `HAS_ISSUE=true`:** When invoking `/prdx:push`, ensure the pr-author agent includes `Closes #{ISSUE_NUMBER}` in the PR body to link and auto-close the issue on merge. Pass this as additional context in the agent prompt.

Write state: `{"slug": "{SLUG}", "phase": "pushing", "quick": {QUICK_MODE}}`

**After PR is created:**
- Draft PR → write state `"reviewing"` with `pr_number` → Step 3b
- Non-draft PR → write state `"pushed"` with `pr_number` (do NOT delete — enables lesson capture)
  - Quick mode: inform user lessons captured automatically after merge; do NOT run Phase 5 yet
  - Normal mode: display `Feature complete! PRD: {PRD_FILE} | PR: #{pr-number}. Lessons will be captured automatically after PR is merged.`

---

### Step 5: Cleanup (Quick Mode Only)

**Only runs when QUICK_MODE is true.**

- **"Done" (no PR):** Delete `{PLANS_DIR}/prdx-quick-{slug}.md` and `.prdx/state/quick-{slug}.json`. Display: `Done! Changes committed on {BRANCH}. Push when ready: git push -u origin {BRANCH}`
- **PR created (non-draft):** Do NOT run cleanup now. State transitions to `"pushed"` (Step 4). Cleanup happens automatically after merge. Display: `Done! PR: #{pr-number}. Lessons and cleanup will happen automatically after merge.`

---

## Important Guidelines

**CRITICAL: Never skip user decision points. ALWAYS use AskUserQuestion.**
- **⛔ #1 FAILURE MODE: After plan mode exits, Claude starts implementing without asking.** This is WRONG. After ExitPlanMode, you MUST show the post-planning decision point (Publish/Implement/Stop) and WAIT for the user's choice. The plan.md Step 5.5 handles this — follow it.
- After planning completes → STOP, ask before implementing
- After implementation completes → STOP, ask before creating PR (recommend testing first)
- Each phase transition requires explicit user consent via AskUserQuestion
- When in doubt, STOP and ask - never auto-proceed
- **Never ask twice for the same decision.** If the user already chose "Create PR" in one step, do NOT ask for PR confirmation again. Respect prior choices within the same workflow run.

**Use AskUserQuestion tool** at each decision point with clear options.

**Always show context:**
- Current PRD status
- What was just completed
- What comes next

**Respect user choice:**
- Never auto-proceed to the next phase without asking
- "Stop here" is always a valid option
- Always show how to resume later with `/prdx:prdx [slug]`

**Status tracking:**
- Read status from PRD file's `**Status:**` field
- Update status by editing the PRD file directly
- Status flow: planning → in-progress → review → implemented → completed (publish adds issue metadata but doesn't change status)

**Error handling:**
- If any phase fails, show clear error message
- Don't auto-proceed after errors
- Offer: retry, stop, or skip options

**Workflow state (`.prdx/state/{slug}.json`):**
- Written at phase transitions to enable resume after context clear
- Read at Step 1 to detect interrupted workflows
- **Never deleted when user pauses** (stop, test first, wait) — state files persist for resume and future lesson capture
- Only deleted in two cases: (1) Step 0 lesson capture after PR merge, (2) Quick mode "Done" cleanup (no PR, nothing to capture)
- Non-draft PR creation transitions to `"pushed"` phase to enable automatic lesson capture
- `"pushed"` state files are processed at next `/prdx:prdx` startup: merged PRs trigger lesson capture, then state file is deleted
