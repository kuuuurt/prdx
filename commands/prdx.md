---
description: "Complete PRD workflow: plan → implement → push"
argument-hint: "[--quick] [--ci] [--issue <number>] [--plan-only] [feature description or PRD slug]"
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

If the file DOES exist, skip this step entirely and proceed with lesson capture below.

**After the setup check (or if already configured), scan for completed workflows that need lesson capture.**

**Before any other logic, scan for completed workflows that need lesson capture.**

This runs silently at startup and does not block the user's intent.

1. **Scan for pushed-phase state files:**
   ```bash
   # Check directory exists first, then iterate safely
   if [ -d .prdx/state ]; then
     for f in .prdx/state/*.json; do
       [ -f "$f" ] || continue
       # process each file in steps 2-8 below
     done
   fi
   ```
   If no state files exist or directory is absent, skip to Step 1.

2. **For each state file found**, read it and check if `phase` is `"pushed"`:
   ```bash
   cat .prdx/state/{file}.json
   ```
   If `phase` is not `"pushed"`, skip this file.

3. **Check if the PR is merged:**
   ```bash
   gh pr view {pr_number} --json state --jq '.state' 2>/dev/null
   ```
   - If the command fails or returns anything other than `"MERGED"`, skip this file (leave it for next startup).
   - If `"MERGED"`, proceed with lesson capture below.

4. **Display status line:**
   ```
   Capturing lessons from merged PR #{pr_number} ({slug})...
   ```

5. **Gather lesson sources:**

   a. Read the PRD file to extract title, platform, and `## Implementation Notes` section(s):
   ```bash
   cat {PLANS_DIR}/prdx-{slug}.md
   ```
   (For quick-mode slugs: `{PLANS_DIR}/prdx-{slug}.md` — the `quick-` prefix is part of the slug itself)

   b. Fetch PR body:
   ```bash
   gh pr view {pr_number} --json body --jq '.body' 2>/dev/null
   ```

   c. Fetch PR review comments (inline code review comments):
   ```bash
   REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
   gh api "repos/$REPO/pulls/{pr_number}/comments" --jq '[.[] | "[\(.path):\(.line // .position)] \(.body)"] | join("\n---\n")' 2>/dev/null
   ```

   d. Fetch PR-level review bodies:
   ```bash
   gh pr view {pr_number} --json reviews --jq '[.reviews[] | .body | select(length > 0)] | join("\n---\n")' 2>/dev/null
   ```

6. **Extract learnings using a general-purpose agent:**

   ```
   subagent_type: "general-purpose"

   prompt: "Extract ONLY repository-wide learnings from this completed PRD.

   Platform: {PLATFORM}
   Title: {TITLE}

   Implementation Notes:
   {IMPLEMENTATION_NOTES from PRD}

   PR Description:
   {PR_BODY}

   PR Review Comments:
   {PR_REVIEW_COMMENTS}

   PR Review Bodies:
   {PR_REVIEW_BODIES}

   IMPORTANT: Only extract learnings that are broadly applicable to the ENTIRE repository — patterns, conventions, or insights that would help ANY future feature in this codebase. Do NOT include learnings that are specific to this particular PR, feature, or task. Skip observations that only matter for this one change.

   Extract concise learnings (1-5 bullet points total, fewer is better). Prioritize DO NOT DO entries — anti-patterns, mistakes, and things to avoid are the most valuable learnings. Use these categories:

   **Do NOT:** What mistakes, anti-patterns, or approaches should be avoided repo-wide? (highest priority — always check for these first)
   **Patterns:** What reusable patterns or conventions were established that apply repo-wide?
   **Challenges & Solutions:** What problems came up that could recur in unrelated features?

   If no learnings are broadly applicable to the repository, respond with exactly: NO_LEARNINGS

   Format your response as markdown bullet points, grouped by category. Only include categories that have learnings. Each bullet should be one line, starting with a dash.

   Keep entries specific and actionable. Skip generic observations and anything specific to this PR's feature."
   ```

7. **Append learnings to the project's CLAUDE.md (if any):**

   If the agent responded with `NO_LEARNINGS`, skip this step entirely and go to step 8.

   Read the project's `CLAUDE.md` (in the repository root).

   - If `CLAUDE.md` doesn't exist, create it with just the `## Lessons Learned` section
   - If `CLAUDE.md` exists but has no `## Lessons Learned` section, append the section at the end of the file
   - If the section already exists, append the new entry under it

   Use Edit tool to append the entry:

   ```markdown
   ### {TITLE} ({DATE}) - {PLATFORM}
   {EXTRACTED_LEARNINGS}
   ```

   If the `## Lessons Learned` section exceeds ~200 lines, trim the oldest entries (remove earliest `###` subsections) to stay under the limit.

   **Commit the CLAUDE.md update:**
   ```bash
   git add CLAUDE.md
   git commit -m "chore: update lessons learned from {SLUG}"
   ```

8. **Clean up state file and PRD (if quick mode):**

   - If `quick` is `true` in the state file:
     - Delete the temporary PRD file: `rm {PLANS_DIR}/prdx-{slug}.md`
   - Delete the state file (both quick and normal mode):
     ```bash
     rm -f .prdx/state/{slug}.json
     ```

9. **Display confirmation:**
   ```
   Lessons captured for "{TITLE}" in CLAUDE.md
   ```

**Process all pushed-phase state files sequentially** (one at a time, not in parallel). After all are processed, continue to Step 1.

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

**Next, parse `--ci` and `--issue` flags:**
- Strip `--ci` from arguments if present
- Strip `--issue {number}` from arguments if present (captures the number)
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

### Step 2-CI: Direct PRD Generation (CI Mode)

**This step runs ONLY when `CI_MODE=true`.** It replaces the interactive plan mode (Step 2) with direct PRD generation.

**2-CI.1: Derive slug and detect platform:**

Derive `{SLUG}` from `ISSUE_TITLE` by converting to kebab-case (lowercase, spaces/special chars to hyphens, strip leading/trailing hyphens, collapse multiple hyphens).

Detect platform from codebase (same logic as `/prdx:plan` Step 1 — check directories, config files, issue title keywords). Use single-platform detection only (CI mode does not support multi-platform).

Detect project name:
```bash
PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
```

**2-CI.2: Explore codebase:**

Use `prdx:code-explorer` agent to understand the codebase context relevant to the issue:

```
subagent_type: "prdx:code-explorer"

prompt: "Explore this codebase to understand patterns and architecture relevant to this task:

Title: {ISSUE_TITLE}
Description: {ISSUE_BODY}

Focus on: existing patterns, relevant files, architecture layers, and conventions that would inform implementation. Return a concise summary."
```

**2-CI.3: Write PRD file:**

Use the Write tool to create `{PLANS_DIR}/prdx-{SLUG}.md` with the full PRD template:

```markdown
# {ISSUE_TITLE}

**Type:** {auto-detect from issue: "bug-fix" if title/body contains "bug"/"fix"/"broken", "refactor" if contains "refactor"/"cleanup", else "feature"}
**Project:** {PROJECT_NAME}
**Platform:** {DETECTED_PLATFORM}
**Status:** planning
**Created:** {TODAY's DATE}
**Branch:** {TYPE_PREFIX}/{SLUG}

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

Use the codebase exploration results from step 2-CI.2 to inform the Approach and Risks sections.

**2-CI.4: Comment PRD on issue:**

Post the generated PRD as a comment on the originating issue:

```bash
gh issue comment {ISSUE_NUMBER} --body "$(cat <<'PRDBODY'
## PRDX: Auto-Generated PRD

_This PRD was automatically generated by PRDX CI mode. Implementation will begin shortly._

---

{FULL PRD CONTENT}
PRDBODY
)"
```

**2-CI.5: Write state file:**

```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "implementing", "quick": false}
EOF
```

**2-CI.6: Proceed directly to Step 3-CI.**

---

### Step 3-CI: Implement and Push (CI Mode)

**This step runs ONLY when `CI_MODE=true`.** It replaces the interactive Steps 3-4 with a straight-line execution path.

**3-CI.1: Set up git branch:**

Create and checkout the feature branch from the PRD:

```bash
BRANCH=$(grep "^\*\*Branch:\*\*" {PLANS_DIR}/prdx-{SLUG}.md | sed 's/\*\*Branch:\*\* //')
git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
```

**3-CI.2: Implement:**

Run `/prdx:implement {SLUG}` — this invokes the full implementation pipeline (dev-planner → platform agent → code reviewer) non-interactively. The `CI=true` env var must be set in the runner environment (GitHub Actions sets this automatically) so that `pre-implement.sh` auto-answers prompts.

**Ensure `CI=true` is set** before invoking implement:
```bash
export CI=true
```

```
/prdx:implement {SLUG}
```

Wait for implementation to complete.

**3-CI.3: Push PR with issue reference:**

After implementation completes, create a draft PR that references the originating issue.

Update state file:
```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "pushing", "quick": false}
EOF
```

Invoke the pr-author agent with the issue reference:

```
subagent_type: "prdx:pr-author"

prompt: "Create a pull request for this PRD.

Mode: prd
PRD Slug: {SLUG}
PRD File: {PLANS_DIR}/prdx-{SLUG}.md
Branch: {BRANCH}
Base Branch: {DEFAULT_BRANCH}
Draft: true

IMPORTANT: Include 'Closes #{ISSUE_NUMBER}' in the PR body to link and auto-close the GitHub issue.

Read the PRD, analyze commits, create comprehensive PR description,
execute gh pr create, and update PRD with PR metadata.

Return only the PR summary (number, URL, title)."
```

**3-CI.4: Update state and display completion:**

After PR is created, transition state to `"pushed"`:

```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "pushed", "quick": false, "pr_number": {PR_NUMBER}}
EOF
```

Display:
```
CI Mode Complete!

PRD: {PLANS_DIR}/prdx-{SLUG}.md
PR: #{PR_NUMBER}
Issue: #{ISSUE_NUMBER} (will auto-close on merge)

Lessons will be captured automatically after PR is merged.
```

**End of CI workflow.** No further decision points.

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
