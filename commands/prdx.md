---
description: "Complete PRD workflow: plan → implement → push"
argument-hint: "[--quick] [--auto] [--ci] [--issue <number>] [--pr <number>] [feature description or PRD slug]"
---

## Pre-Computed Context

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-plans-dir.sh"
source "$(git rev-parse --show-toplevel)/hooks/prdx/ensure-gitignore.sh"
source "$(git rev-parse --show-toplevel)/hooks/prdx/first-run-setup.sh"
ACTIVE_STATES=$(ls .prdx/state/*.json 2>/dev/null)
PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
[ "$FIRST_RUN" = "true" ] && echo "PRDX initialized. Plans: $PLANS_DIR"
```

# /prdx:prdx - Complete Feature Workflow

> Main entry point for PRDX. Orchestrates plan → implement → push with decision points.
> Use `--quick` for ephemeral tasks. Use `--auto --issue N` for non-interactive mode (routes to `/prdx:auto`).
> `--ci` is a deprecated alias for `--auto` — emits a warning and routes identically.
> Use `--issue N` or `--pr N` (without `--auto`/`--ci`) to resume a CI-created PRD locally.

---

### Step 1: Determine Entry Point

**`--issue N` / `--pr N` flag (resume from CI, no `--auto`/`--ci`):**

If `--issue N` or `--pr N` is present and neither `--auto` nor `--ci` is present:

```bash
# Set ISSUE_NUMBER=N  (or PR_NUMBER=N — the hook resolves either)
source "$(git rev-parse --show-toplevel)/hooks/prdx/resume-from-issue.sh"
# → sets: RESUME_SLUG, RESUME_PR_NUMBER, RESUME_PHASE
```

Route by `RESUME_PHASE`:
- `"reviewing"` → Jump to Step 3b using `RESUME_SLUG` + `RESUME_PR_NUMBER`
- `"post-implement"` → Jump to Step 3a using `RESUME_SLUG`

On hook error: show message, stop.

**Auto-detect from current branch (no flags, no local state):**

Before falling through to new-feature planning: if no `.prdx/state/*.json` files exist and the current branch is not the default branch, run:

```bash
CURRENT_BRANCH=$(git branch --show-current)
PR_INFO=$(gh pr list --head "$CURRENT_BRANCH" --state all --json number,body --jq '.[0]' 2>/dev/null)
```

If a PR is found with `Closes/Fixes/Resolves #M` in body, and issue `#M` has a `<!-- prdx-prd -->` comment → show AskUserQuestion:
```
Resume CI-created PRD?
  Slug:   {DERIVED_SLUG}   (derived from issue title, same rule as /prdx:plan Step 0)
  Issue:  #{M}
  PR:     #{PR_INFO.number}
```
- Confirm → `ISSUE_NUMBER=$M`, source hook, route by `RESUME_PHASE` (same table above).
- Decline OR any check fails → fall through silently to normal new-feature flow.

**Normal active-state routing:**

When exactly one active state file is identified (see skill for active detection logic), read that slug's state using the shared hook:

```bash
# SLUG = slug extracted from the identified state file name (strip .prdx/state/ prefix and .json suffix)
source "$(git rev-parse --show-toplevel)/hooks/prdx/read-state.sh" "$SLUG"
# → sets: STATE_PHASE, STATE_QUICK, STATE_PARENT, STATE_PR_NUMBER
```

Route by `STATE_PHASE`:

| phase (`STATE_PHASE`) | action |
|-----------------------|--------|
| `"planning"` | Fall through to normal logic below |
| `"post-planning"` | Show post-planning decision (AskUserQuestion) |
| `"implementing"` | Jump to Step 3 |
| `"post-implement"` | Jump to Step 3a |
| `"reviewing"` | Jump to Step 3b |
| `"pushing"` / `"pushed"` / `"completed"` | See routing rules in skill |

> When scanning `.prdx/state/*.json` for multiple active sessions (no single slug identified yet), leave the directory scan loop in place — `read-state.sh` is for single-slug reads and is not a good fit for directory scanning. The loop body could be refactored to call `read-state.sh` per iteration in the future.

See [skills/prdx-workflow.md#entry-point-routing](../skills/prdx-workflow.md#entry-point-routing) for the full routing logic (active state detection, quick-flag parsing, CI/issue flags, slug-vs-description resolution, and no-argument handling).

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

**STOP and use AskUserQuestion:**

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

**When state file has phase `"reviewing"`, or PRD status is `implemented` with `## Pull Request` section.**

Fetch PR state, display comment summary, then offer fix/push/mark-ready options. Fixes are committed and pushed, then the loop re-fetches and re-asks.

See [skills/prdx-workflow.md#reviewing-loop](../skills/prdx-workflow.md#reviewing-loop) for the full decision-point specification (fetch commands, draft vs non-draft options, fix routing, and state transitions).

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

## Critical Rules

1. **ALWAYS use AskUserQuestion at every phase transition.** Never auto-proceed. Never ask twice for the same decision.
2. **After plan mode exits → STOP and ask** (Publish/Implement/Stop). Do NOT start implementing.
3. **After implementation → STOP and ask** before creating PR. Recommend testing first.
4. **Status tracking:** Read/update `**Status:**` field in PRD. Flow: planning → in-progress → review → implemented → completed.
5. **State files** (`.prdx/state/{slug}.json`): written at phase transitions, read at Step 1 for resume. Never deleted when user pauses. Only deleted after PR merge (lesson capture) or Quick mode "Done" (no PR).
6. **Errors:** Show clear message, offer retry/stop/skip. Never auto-proceed after errors.
