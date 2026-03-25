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

Plans are always stored in `.prdx/plans/` relative to the project root:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PLANS_DIR="$PROJECT_ROOT/.prdx/plans"
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
   mkdir -p .claude .prdx .prdx/plans
   if [ -f .claude/settings.local.json ]; then
     jq '. + {plansDirectory: ".prdx/plans"}' .claude/settings.local.json > .claude/settings.local.json.tmp && mv .claude/settings.local.json.tmp .claude/settings.local.json
   else
     echo '{"plansDirectory": ".prdx/plans"}' > .claude/settings.local.json
   fi
   echo "local" > .prdx/plans-setup-done
   ```

2. Re-resolve PLANS_DIR after setup.

If the file DOES exist, skip this step entirely and proceed with the gitignore check below.

**After the setup check (or if already configured), ensure `.prdx/state/` is gitignored (runs every time):**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
GITIGNORE="$PROJECT_ROOT/.gitignore"

# Ensure only .prdx/plans/ is tracked — everything else in .prdx/ is ignored
if [ ! -f "$GITIGNORE" ] || ! grep -qxF '.prdx/*' "$GITIGNORE"; then
  echo '' >> "$GITIGNORE"
  echo '# PRDX - only track plans (ignore state, markers, etc.)' >> "$GITIGNORE"
  echo '.prdx/*' >> "$GITIGNORE"
  echo '!.prdx/plans/' >> "$GITIGNORE"
fi
```

This ensures plans are committed (tracked in git) while everything else under `.prdx/` stays local.

**Lesson capture and plan cleanup are handled by the scheduled CI workflow (`/prdx:cleanup`).** No startup scan is performed.

---

### Step 1: Determine Entry Point

**First, check for active workflow state:**

Check for state files in `.prdx/state/`:
```bash
ls .prdx/state/*.json 2>/dev/null
```

If state files exist and **no argument was provided**, check if there is exactly one active (non-pushed, non-completed) state file. If so, auto-resume it. If multiple active state files exist, list them and let the user pick (see "no argument provided" section below).

If exactly one active state file exists, read it and route based on `phase`:
- `"planning"` → Fall through to normal Step 1 logic below (plan mode may still be active or needs restart)
- `"post-planning"` → Show the post-planning decision point via AskUserQuestion:
  - **Normal mode** (quick=false):
    - Option 1: "Publish to GitHub" (create issue for team visibility)
    - Option 2: "Implement now" (start coding immediately)
    - Option 3: "Stop here" (review PRD later)
  - **Quick mode** (quick=true):
    - Option 1: "Implement now" (Recommended)
    - Option 2: "Stop here" (review plan later)
  - Route: Publish → Phase 2a, Implement → Phase 3, Stop → end workflow (keep state file for future resume/lesson capture)
- `"implementing"` → Jump to Phase 3 (implementation), using the slug from state file
- `"post-implement"` → Jump to Phase 3a (review decision), using the slug from state file
- `"reviewing"` → Jump to Step 3b (reviewing loop), using slug + pr_number from state file
- `"pushing"` → PR creation was interrupted. Check if PR was actually created: `gh pr list --head {BRANCH} --json number --jq '.[0].number' 2>/dev/null`. If a PR exists, transition state to `"pushed"` with the pr_number and inform user. If no PR, transition state back to `"post-implement"` and offer to retry with `/prdx:push {slug}`.
- `"pushed"` → Already handled by Step 0 startup scan (which processes all pushed files). If it reaches here (e.g., PR not yet merged), inform user: `PR #{pr_number} is not merged yet. Lessons will be captured automatically after merge.` Then ignore this state file (do NOT use its slug) and continue with normal Step 1 logic below, processing command arguments as if no state file was found.
- `"completed"` → Stale state file (should have been deleted after lesson capture). Delete it (`rm -f .prdx/state/{slug}.json`) and continue with normal Step 1 logic below.

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
- Strip `--ci` from arguments if present
- Strip `--issue {number}` from arguments if present (captures the number)
- Strip `--requested-by {user}` from arguments if present (captures the GitHub username)
- If `--issue` is present (with or without `--ci`):
  - Store `ISSUE_NUMBER` from the `--issue` flag
  - Set `HAS_ISSUE=true`
  - **Fetch issue:**
    ```bash
    gh issue view {ISSUE_NUMBER} --json title,body,labels
    ```
    If issue not found, error:
    ```
    Issue #{ISSUE_NUMBER} not found or not accessible.
    ```
    Store the issue title as `ISSUE_TITLE` and body as `ISSUE_BODY`
  - Use `ISSUE_TITLE` + `ISSUE_BODY` as the feature description for planning (replaces any text argument)
- If `--ci` is present:
  - Set `CI_MODE=true`
  - `--issue` is required when `--ci` is set — error if missing:
    ```
    --ci requires --issue. Usage: /prdx:prdx --ci --issue 42
    ```
  - **Resolve requestor for commit authorship:**
    If `--requested-by {user}` was provided, configure git author so commits are authored by the requestor:
    ```bash
    REQUESTOR="{user}"
    # Fetch display name from GitHub (falls back to username)
    REQUESTOR_NAME=$(gh api "users/${REQUESTOR}" --jq '.name // .login' 2>/dev/null || echo "$REQUESTOR")
    export GIT_AUTHOR_NAME="$REQUESTOR_NAME"
    export GIT_AUTHOR_EMAIL="${REQUESTOR}@users.noreply.github.com"
    ```
    If `--requested-by` is not provided, `REQUESTOR` is empty and git uses the default committer (GitHub Actions bot).
  - **Skip the state-file resume scan entirely** (do not check `.prdx/state/` for active workflows)
  - **Skip the plans-directory setup prompt** — require `.prdx/plans-setup-done` to exist:
    ```bash
    if [ ! -f .prdx/plans-setup-done ]; then
      echo "CI mode requires plans directory to be pre-configured."
      echo "Run /prdx:config plans local interactively first."
      exit 1
    fi
    ```
  - **Validate GitHub CLI:**
    ```bash
    if ! gh auth status >/dev/null 2>&1; then
      echo "CI mode requires authenticated GitHub CLI."
      echo "Run: gh auth login"
      exit 1
    fi
    ```
  - **If `PLAN_ONLY=true`:** Jump to Step 2-CI (plan-only path)
  - **If `PLAN_ONLY=false`:** Jump to Step 3-CI (implement path — reads PRD from existing branch)
- If `--ci` is NOT present, continue with normal entry point logic below (issue data is available via `HAS_ISSUE` if `--issue` was provided)

**Next, parse `--plan-only` flag:**
- Strip `--plan-only` from arguments if present
- If `--plan-only` is present:
  - Set `PLAN_ONLY=true`
  - `--ci` and `--issue` are required when `--plan-only` is set — error if either is missing:
    ```
    --plan-only requires --ci and --issue. Usage: /prdx:prdx --ci --issue 42 --plan-only
    ```
- If `--plan-only` is NOT present, set `PLAN_ONLY=false`

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
- Scan `.prdx/state/*.json` for active state files (phase is NOT `"pushed"` and NOT `"completed"`):
  ```bash
  if [ -d .prdx/state ]; then
    for f in .prdx/state/*.json; do
      [ -f "$f" ] || continue
      # Read phase, skip pushed/completed
    done
  fi
  ```
- If exactly one active state file exists, offer to resume it via AskUserQuestion:
  - Option 1: "Continue {slug}" (Recommended) — Resume the in-progress PRD
  - Option 2: "Choose a different PRD" — List all PRDs to pick from
  - Option 3: "Start a new feature" — Create a new PRD
- If multiple active state files exist, list them all and let the user pick via AskUserQuestion:
  - One option per active PRD (showing slug, phase, and quick status)
  - Plus: "Start a new feature" — Create a new PRD
- If no active state files, list existing PRDX plans for the current project:
  ```bash
  PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
  grep -rl "^\*\*Project:\*\* $PROJECT_NAME" {PLANS_DIR}/*.md 2>/dev/null
  ```
  - Ask: "Start a new feature or continue an existing PRD?"

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

**This step runs ONLY when `CI_MODE=true` and `PLAN_ONLY=true`.** It generates a PRD and opens a draft PR for review.

**2-CI.1: Derive slug and detect platform:**

Derive `{SLUG}` from `ISSUE_TITLE` by extracting the **core concept** (2-4 words max) and converting to kebab-case. Strip filler words (add, implement, create, update, fix, refactor, improve), prepositions (the, a, for, from, to, in, on, of, with), and implementation details — keep only the domain-specific nouns and key verbs. Examples: "Read monthly report directly from Firestore instead of aggregating daily reports" → `monthly-report-read`, "Add biometric authentication" → `biometric-auth`.

Detect platform from codebase (same logic as `/prdx:plan` Step 1 — check directories, config files, issue title keywords). Use single-platform detection only (CI mode does not support multi-platform).

Detect project name:
```bash
PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
```

Determine branch name from type:
```bash
# Auto-detect type: "bug-fix" if title/body contains "bug"/"fix"/"broken", "refactor" if "refactor"/"cleanup", else "feature"
# Branch prefix: feature → feat/, bug-fix → fix/, refactor → refactor/
BRANCH="{TYPE_PREFIX}/{SLUG}"
```

**2-CI.2: Check for existing branch (revision detection):**

```bash
git fetch origin "$BRANCH" 2>/dev/null
BRANCH_EXISTS=$?
```

**If branch does NOT exist (fresh plan):** Continue to 2-CI.3.

**If branch exists (revision):** Jump to 2-CI.6.

**2-CI.2b: Post progress comment on issue:**

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
RUN_URL="${GITHUB_SERVER_URL}/${REPO}/actions/runs/${GITHUB_RUN_ID}"
PROGRESS_COMMENT_ID=$(gh issue comment "$ISSUE_NUMBER" --body "> Planning... 🔨
>
> [View job run]($RUN_URL)" | grep -o 'https://[^ ]*' | grep -o '[0-9]*$')
```

Store `PROGRESS_COMMENT_ID` for editing when done.

**2-CI.3: Explore codebase:**

Use `prdx:code-explorer` agent to understand the codebase context relevant to the issue:

```
subagent_type: "prdx:code-explorer"

prompt: "Explore this codebase to understand patterns and architecture relevant to this task:

Title: {ISSUE_TITLE}
Description: {ISSUE_BODY}

Focus on: existing patterns, relevant files, architecture layers, and conventions that would inform implementation. Return a concise summary."
```

**2-CI.4: Write PRD file and create branch:**

```bash
git checkout -b "$BRANCH"
```

Use the Write tool to create `{PLANS_DIR}/prdx-{SLUG}.md` with the full PRD template:

```markdown
# {ISSUE_TITLE}

**Type:** {auto-detected type}
**Project:** {PROJECT_NAME}
**Platform:** {DETECTED_PLATFORM}
**Status:** planning
**Created:** {TODAY's DATE}
**Branch:** {BRANCH}

## Problem

{Extract from ISSUE_BODY — the problem statement or first paragraph}

## Goal

{Derive from issue title and body — the desired outcome}

## Acceptance Criteria

{Extract from ISSUE_BODY if present (look for checkboxes, "acceptance criteria", numbered lists), otherwise derive 2-3 testable criteria from the issue description}

## Approach

{Generate based on codebase exploration results — high-level strategy for implementation}

## Risks & Considerations

{Generate 1-2 risks based on codebase exploration and issue complexity}
```

Use the codebase exploration results from step 2-CI.3 to inform the Approach and Risks sections.

**2-CI.5: Commit PRD and push branch:**

```bash
git add .prdx/plans/prdx-{SLUG}.md
git commit -m "$(cat <<'EOF'
docs: add PRD for {SLUG}

Co-Authored-By: claude[bot] <209825114+claude[bot]@users.noreply.github.com>
Co-Authored-By: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>
EOF
)"
git push -u origin "$BRANCH"
```

When `REQUESTOR` is set (via `--requested-by`), `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL` are already exported, so the commit author is the requestor while Claude Code and GitHub Actions appear as co-authors.

Write state file:
```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "planning", "quick": false}
EOF
```

**2-CI.5b: Create draft PR and comment on issue:**

Detect default branch:
```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
```

Invoke the `prdx:pr-author` agent to create a draft PR:

```
subagent_type: "prdx:pr-author"

prompt: "Create a draft pull request for this PRD.

Mode: prd
CI: true
PRD Slug: {SLUG}
PRD File: {PLANS_DIR}/prdx-{SLUG}.md
Branch: {BRANCH}
Base Branch: {DEFAULT_BRANCH}
Draft: true
Issue: {ISSUE_NUMBER}

This is a plan-only draft PR for PRD review. The footer should say:
'Comment `@claude implement` when ready, or `@claude revise` with feedback.'

Read the PRD, create the PR via gh pr create --draft, and return only the PR summary (number, URL, title)."
```

After PR creation, edit the progress comment to show completion:
```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
gh api "repos/$REPO/issues/comments/$PROGRESS_COMMENT_ID" -X PATCH -f body="Planning complete. A draft PR has been created — review the PRD and comment \`@claude implement\` when ready."
```

Update state file with PR number:
```bash
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "planning", "quick": false, "pr_number": {PR_NUMBER}}
EOF
```

Add requester as assignee to the draft PR:
```bash
if [ -n "$REQUESTOR" ]; then
  gh pr edit "$PR_NUMBER" --add-assignee "$REQUESTOR" 2>/dev/null || true
fi
```

Display:
```
CI Plan-Only Complete!

PRD: {PLANS_DIR}/prdx-{SLUG}.md
Branch: {BRANCH}
Issue: #{ISSUE_NUMBER}
Draft PR: #{PR_NUMBER}
```

---

**2-CI.6: Revision path (existing branch + PRD):**

This runs when `--plan-only` is used and the branch already exists — it means the user wants to revise the PRD based on feedback.

```bash
git checkout "$BRANCH"
git pull origin "$BRANCH"
```

**Post progress comment on PR:**

```bash
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null)
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
RUN_URL="${GITHUB_SERVER_URL}/${REPO}/actions/runs/${GITHUB_RUN_ID}"
if [ -n "$PR_NUMBER" ]; then
  PROGRESS_COMMENT_ID=$(gh pr comment "$PR_NUMBER" --body "> Revising PRD... 🔨
>
> [View job run]($RUN_URL)" | grep -o 'https://[^ ]*' | grep -o '[0-9]*$')
fi
```

**Read existing PRD:**
```bash
cat {PLANS_DIR}/prdx-{SLUG}.md
```

If the PRD file does not exist on the branch, error:
```
Branch {BRANCH} exists but no PRD file found at .prdx/plans/prdx-{SLUG}.md.
Cannot revise — create a fresh PRD instead by deleting the branch and re-running.
```

**Fetch PR review comments:**

```bash
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null)
```

If no PR found, warn but continue (PRD can still be revised without PR comments).

If PR exists, fetch review feedback:
```bash
# PR-level review bodies
REVIEW_BODIES=$(gh pr view "$PR_NUMBER" --json reviews --jq '[.reviews[] | .body | select(length > 0)] | join("\n---\n")' 2>/dev/null)

# Inline code review comments
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
REVIEW_COMMENTS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/comments" --jq '[.[] | "[\(.path):\(.line // .position)] \(.body)"] | join("\n---\n")' 2>/dev/null)

# PR conversation comments
PR_COMMENTS=$(gh pr view "$PR_NUMBER" --json comments --jq '[.comments[] | .body] | join("\n---\n")' 2>/dev/null)
```

**Re-explore codebase if needed** (use `prdx:code-explorer` same as 2-CI.3).

**Revise PRD:**

Use the Write tool to update the PRD file, incorporating the review feedback. The revised PRD should address all review comments while maintaining the same format.

**Commit and push revision:**
```bash
git add .prdx/plans/prdx-{SLUG}.md
git commit -m "$(cat <<'EOF'
docs: revise PRD for {SLUG}

Co-Authored-By: claude[bot] <209825114+claude[bot]@users.noreply.github.com>
Co-Authored-By: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>
EOF
)"
git push origin "$BRANCH"
```

**Update PR body after revision:**

```bash
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
```

If PR exists, invoke `prdx:pr-author` agent to update:

```
subagent_type: "prdx:pr-author"

prompt: "Update the PR body for a revised PRD.

Mode: prd
CI: true
PR Number: {PR_NUMBER}
PRD Slug: {SLUG}
PRD File: {PLANS_DIR}/prdx-{SLUG}.md
Branch: {BRANCH}
Base Branch: {DEFAULT_BRANCH}
Issue: {ISSUE_NUMBER}

Read the updated PRD and regenerate the PR title and body. Use gh pr edit to update the existing PR.
The footer should say: 'Comment `@claude implement` when ready, or `@claude revise` with feedback.'

Return confirmation of the update."
```

**Edit progress comment to show completion:**

```bash
if [ -n "$PROGRESS_COMMENT_ID" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
  gh api "repos/$REPO/issues/comments/$PROGRESS_COMMENT_ID" -X PATCH -f body="PRD revised. Review the updated PR description and comment \`@claude implement\` when ready."
fi
```

Display:
```
PRD Revised!

PRD: {PLANS_DIR}/prdx-{SLUG}.md
Branch: {BRANCH}
PR: #{PR_NUMBER} (body updated)
```

---

### Step 3-CI: Implement Path (CI Mode)

**This step runs ONLY when `CI_MODE=true` and `PLAN_ONLY=false`.** It reads an existing PRD from the branch and implements it.

**3-CI.1: Derive slug and check for existing PRD:**

Derive `{SLUG}` from `ISSUE_TITLE` by extracting the core concept (2-4 words max, same logic as 2-CI.1).

Determine branch name:
```bash
# Auto-detect type from issue title/body
BRANCH="{TYPE_PREFIX}/{SLUG}"
```

**Check that the branch exists:**
```bash
git fetch origin "$BRANCH" 2>/dev/null
```

If the branch does NOT exist, error:
```
No PRD found for issue #{ISSUE_NUMBER}.

Branch {BRANCH} does not exist. Run with --plan-only first:
  /prdx:prdx --ci --issue {ISSUE_NUMBER} --plan-only
```

**Check out the existing branch:**
```bash
git checkout "$BRANCH"
git pull origin "$BRANCH"
```

**Verify PRD file exists:**
```bash
ls {PLANS_DIR}/prdx-{SLUG}.md
```

If the PRD file does not exist, error:
```
Branch {BRANCH} exists but no PRD file found at .prdx/plans/prdx-{SLUG}.md.

Run with --plan-only first to generate the PRD:
  /prdx:prdx --ci --issue {ISSUE_NUMBER} --plan-only
```

**3-CI.2: Implement:**

Update state file:
```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "implementing", "quick": false}
EOF
```

Run `/prdx:implement {SLUG}` — this invokes the full implementation pipeline (dev-planner → platform agent → ac-verifier → code-reviewer) non-interactively. The `CI=true` env var must be set in the runner environment (GitHub Actions sets this automatically) so that `pre-implement.sh` auto-answers prompts.

**Ensure `CI=true` is set** before invoking implement:
```bash
export CI=true
```

```
/prdx:implement {SLUG}
```

Wait for implementation to complete.

**3-CI.3: Push implementation:**

After implementation completes, push the implementation commits:
```bash
git push origin "$BRANCH"
```

**3-CI.4: Update state and display completion:**

```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "review", "quick": false}
EOF
```

**3-CI.4b: Update PR body with implementation:**

```bash
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
```

If PR exists, invoke `prdx:pr-author` agent to update:

```
subagent_type: "prdx:pr-author"

prompt: "Update the PR body for a completed implementation.

Mode: prd
CI: true
PR Number: {PR_NUMBER}
PRD Slug: {SLUG}
PRD File: {PLANS_DIR}/prdx-{SLUG}.md
Branch: {BRANCH}
Base Branch: {DEFAULT_BRANCH}
Issue: {ISSUE_NUMBER}

Read the PRD (now including Implementation Notes), analyze commits on this branch, and update the PR title and body with full implementation details. Use gh pr edit to update the existing PR.
The footer should say: 'Comment `@claude review` for code review.'

Return confirmation of the update."
```

Mark PR as ready and add requester as reviewer:
```bash
gh pr ready "$PR_NUMBER" 2>/dev/null || true
if [ -n "$REQUESTOR" ]; then
  gh pr edit "$PR_NUMBER" --add-reviewer "$REQUESTOR" 2>/dev/null || true
fi
```

Display:
```
CI Implementation Complete!

PRD: {PLANS_DIR}/prdx-{SLUG}.md
Branch: {BRANCH}
Issue: #{ISSUE_NUMBER}
PR: #{PR_NUMBER} (body updated with implementation details)
```

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

**After implementation completes, update workflow state:**
```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "post-implement", "quick": {QUICK_MODE}}
EOF
```

**IMPORTANT: STOP and use AskUserQuestion:**

Do NOT proceed to create PR automatically. The user must test the implementation first.

**If QUICK_MODE:**
- Option 1: "Create PR" (Recommended) — Ready for review
- Option 2: "Create Draft PR" — Mark as draft, not human-reviewed yet
- Option 3: "Done" — Commit only, no PR needed
- Option 4: "Test first" — Let me verify first

Route based on choice:
- Create PR → Run `/prdx:push quick-{slug}` directly, then proceed to Phase 5 (cleanup)
- Create Draft PR → Run `/prdx:push quick-{slug} --draft` directly. After PR created, update `.prdx/state/quick-{slug}.json` to `"reviewing"` phase with `pr_number`, then proceed to Step 3b (reviewing loop)
- Done → Proceed to Phase 5 (cleanup) immediately — no PR
- Test first → End workflow. Tell user to test and resume with `/prdx:prdx quick-{slug}` when ready

**If NOT QUICK_MODE (normal mode):**
- Option 1: "Test first" (Recommended) - Let me verify the implementation works
- Option 2: "Create PR now" - Skip testing, go straight to PR
- Option 3: "Create Draft PR" — Mark as draft, not human-reviewed yet

Route based on choice:
- Test first → End workflow, tell user to test and resume with `/prdx:prdx [slug]` when ready
- Create PR now → Run `/prdx:push [slug]` directly (do NOT ask for confirmation again — user already confirmed)
- Create Draft PR → Run `/prdx:push [slug] --draft` directly. After PR created, update `.prdx/state/{slug}.json` to `"reviewing"` phase with `pr_number`, then proceed to Step 3b (reviewing loop)

---

### Step 3a: Review Status Decision

**When PRD status is `review`:**

The implementation is complete but user hasn't confirmed it's ready for PR. Use AskUserQuestion:

**If QUICK_MODE:**
- Option 1: "Create PR" (Recommended) — Ready for review
- Option 2: "Create Draft PR" — Mark as draft, not human-reviewed yet
- Option 3: "Done" — Commit only, no PR needed
- Option 4: "Fix issues" — Found bugs or need changes

Route:
- Create PR → Run `/prdx:push quick-{slug}` directly, then proceed to Phase 5 (cleanup)
- Create Draft PR → Run `/prdx:push quick-{slug} --draft` directly. After PR created, update `.prdx/state/quick-{slug}.json` to `"reviewing"` phase with `pr_number`, then proceed to Step 3b (reviewing loop)
- Done → Proceed to Phase 5 (cleanup) immediately
- Fix issues → Same as normal mode below

**If NOT QUICK_MODE (normal mode):**
- Option 1: "Create PR" (Recommended) - Implementation looks good, ready for review
- Option 2: "Create Draft PR" — Mark as draft, not human-reviewed yet
- Option 3: "Fix issues" - Found bugs or need changes
- Option 4: "View implementation summary" - Review what was done

**Route based on choice:**
- Create PR → Run `/prdx:push [slug]` directly (do NOT ask for confirmation again — user already confirmed)
- Create Draft PR → Run `/prdx:push [slug] --draft` directly. After PR created, update `.prdx/state/{slug}.json` to `"reviewing"` phase with `pr_number`, then proceed to Step 3b (reviewing loop)
- Fix issues → Tell user to describe the issues. Claude will fix them in the current conversation (no need to re-run full implement). After fixes are committed, ask again.
- View summary → Show the implementation notes from the PRD, then ask again

**Important:** When user chooses "Fix issues", do NOT re-run `/prdx:implement`. Instead:
1. Ask user to describe the bugs/issues
2. Fix them directly in the conversation
3. Commit the fixes
4. Ask the review decision again

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
   - Update PRD status to `implemented` (if not already)
   - Transition state file to `"pushed"` phase (do NOT delete — enables automatic lesson capture on next startup):
     ```bash
     mkdir -p .prdx/state
     cat > .prdx/state/{SLUG}.json << EOF
     {"slug": "{SLUG}", "phase": "pushed", "quick": {QUICK_MODE}, "pr_number": {PR_NUMBER}}
     EOF
     ```
   - Display: `PR #{PR_NUMBER} marked ready for review. Lessons will be captured automatically after merge.`

   **"Done":**
   - Transition state file to `"pushed"` phase (do NOT delete — PR exists, enables automatic lesson capture on next startup):
     ```bash
     mkdir -p .prdx/state
     cat > .prdx/state/{SLUG}.json << EOF
     {"slug": "{SLUG}", "phase": "pushed", "quick": {QUICK_MODE}, "pr_number": {PR_NUMBER}}
     EOF
     ```
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

**Update workflow state before PR creation:**
```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "pushing", "quick": {QUICK_MODE}}
EOF
```

**After PR is created:**

**If draft PR:**
- Update state file to `"reviewing"` phase with `pr_number`:
  ```bash
  mkdir -p .prdx/state
  cat > .prdx/state/{SLUG}.json << EOF
  {"slug": "{SLUG}", "phase": "reviewing", "quick": {QUICK_MODE}, "pr_number": {PR_NUMBER}}
  EOF
  ```
- Proceed to Step 3b (reviewing loop)

**If non-draft PR:**
- Transition state file to `"pushed"` phase (do NOT delete — enables automatic lesson capture on next startup):
  ```bash
  mkdir -p .prdx/state
  cat > .prdx/state/{SLUG}.json << EOF
  {"slug": "{SLUG}", "phase": "pushed", "quick": {QUICK_MODE}, "pr_number": {PR_NUMBER}}
  EOF
  ```
- **If QUICK_MODE:** Display completion and inform user that lessons will be captured automatically on next `/prdx:prdx` startup after PR is merged. Do NOT run Phase 5 cleanup yet — cleanup happens after lesson capture on next startup.
- **If NOT QUICK_MODE:** Display completion message:
  ```
  Feature complete!

  PRD: {PLANS_DIR}/[slug].md
  PR: #[pr-number]

  The feature is ready for review.
  Lessons will be captured automatically after PR is merged.
  ```

---

### Step 5: Cleanup (Quick Mode Only)

**This step only runs when QUICK_MODE is true.** It runs in two scenarios:

**Scenario A: User chose "Done" (no PR created):**
Run cleanup immediately — no lessons to capture.

1. **Delete the temporary PRD file:**
   ```bash
   rm {PLANS_DIR}/prdx-quick-{slug}.md
   ```

2. **Delete workflow state:**
   ```bash
   rm -f .prdx/state/quick-{slug}.json
   ```

3. **Display completion message:**
   ```
   Done! Changes committed on branch {BRANCH}.

   Quick task cleaned up — no PRD artifact left behind.
   Push when ready: git push -u origin {BRANCH}
   ```

**Scenario B: PR was created (non-draft):**
Do NOT run cleanup now. The state file transitions to `"pushed"` phase (Step 4). Cleanup happens automatically on next `/prdx:prdx` startup after the PR is merged and lessons are captured (see Step 0).

Display:
```
Done! PR: #[pr-number]

Lessons and cleanup will happen automatically after merge.
```

---

## Important Guidelines

**CRITICAL: Never skip user decision points. ALWAYS use AskUserQuestion.**
- **⛔ #1 FAILURE MODE: After plan mode exits, Claude starts implementing without asking.** This is WRONG. After ExitPlanMode, you MUST show the post-planning decision point (Publish/Implement/Stop) and WAIT for the user's choice. The plan.md Step 5.5 handles this — follow it.
- After planning completes → STOP, ask before implementing
- After implementing completes → STOP, ask before creating PR (recommend testing first)
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
