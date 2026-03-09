---
description: "Complete PRD workflow: plan → implement → push"
argument-hint: "[--quick] [feature description or PRD slug]"
---

# /prdx:prdx - Complete Feature Workflow

> **Main entry point for PRDX.**
> Orchestrates the complete feature development workflow with decision points.
> Use `--quick` for ephemeral tasks that need the full pipeline but not a permanent PRD.

## Workflow

Execute the following phases based on the argument provided:

### Step 0: Auto-Capture Lessons from Merged PRs

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
   cat ~/.claude/plans/prdx-{slug}.md
   ```
   (For quick-mode slugs: `~/.claude/plans/prdx-{slug}.md` — the `quick-` prefix is part of the slug itself)

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

   prompt: "Extract implementation learnings from this completed PRD.

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

   Extract concise learnings (3-5 bullet points total) in these categories:

   **Patterns:** What patterns worked well and should be reused?
   **Challenges & Solutions:** What problems came up and how were they solved?
   **Deviations from Plan:** Where did the implementation diverge from the plan and why?
   **Review Feedback:** What did reviewers flag that should be done differently next time?

   Format your response as markdown bullet points, grouped by category. Only include categories that have learnings. Each bullet should be one line, starting with a dash.

   Keep entries specific and actionable. Skip generic observations."
   ```

7. **Append learnings to the project's CLAUDE.md:**

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

8. **Clean up state file and PRD (if quick mode):**

   - If `quick` is `true` in the state file:
     - Delete the temporary PRD file: `rm ~/.claude/plans/prdx-{slug}.md`
     - Clear last-slug if it points to this slug:
       ```bash
       if [ "$(cat .prdx/last-slug 2>/dev/null)" = "{slug}" ]; then
         rm .prdx/last-slug
       fi
       ```
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

If state files exist, check the last-used slug first:
```bash
cat .prdx/last-slug 2>/dev/null
```

If a last-slug exists, read its state file:
```bash
cat .prdx/state/{last-slug}.json 2>/dev/null
```

If the state file exists, use its `slug` and `quick` fields (ignore any command arguments), and route based on `phase`:
- `"planning"` → Fall through to normal Step 1 logic below (plan mode may still be active or needs restart)
- `"post-planning"` → Show the post-planning decision point via AskUserQuestion:
  - **Normal mode** (quick=false):
    - Option 1: "Publish to GitHub" (create issue for team visibility)
    - Option 2: "Implement now" (start coding immediately)
    - Option 3: "Stop here" (review PRD later)
  - **Quick mode** (quick=true):
    - Option 1: "Implement now" (Recommended)
    - Option 2: "Stop here" (review plan later)
  - Route: Publish → Phase 2a, Implement → Phase 3, Stop → delete `.prdx/state/{slug}.json` and end workflow
- `"implementing"` → Jump to Phase 3 (implementation), using the slug from state file
- `"post-implement"` → Jump to Phase 3a (review decision), using the slug from state file
- `"reviewing"` → Jump to Step 3b (reviewing loop), using slug + pr_number from state file
- `"pushing"` → Inform user PR creation was interrupted. Offer to retry with `/prdx:push {slug}`. Delete `.prdx/state/{slug}.json`
- `"pushed"` → Already handled by Step 0 startup scan (which processes all pushed files). If it reaches here (e.g., PR not yet merged and this slug is the last-slug), inform user: `PR #{pr_number} is not merged yet. Lessons will be captured automatically after merge.` Then ignore this state file (do NOT use its slug) and continue with normal Step 1 logic below, processing command arguments as if no state file was found.
- `"completed"` → Stale state file (should have been deleted after lesson capture). Delete it (`rm -f .prdx/state/{slug}.json`) and continue with normal Step 1 logic below.

If state file does NOT exist (or no last-slug found), continue with normal logic below.

---

**Next, parse `--quick` flag:**
- Strip `--quick` from arguments if present (can appear anywhere in the argument string)
- If `--quick` is present:
  - Remaining text MUST be a description (not a slug) — error if empty
  - Error: `--quick requires a description. Usage: /prdx:prdx --quick "fix login validation"`
  - Set `QUICK_MODE=true`, skip PRD matching, go directly to Phase 2 (planning)
- If `--quick` is NOT present, continue with normal entry point logic below

**If the argument matches an existing PRD** (resolve using enhanced matching: exact → substring → word-boundary → disambiguation; see `/prdx:implement` for full algorithm):
- Read PRD and check its `**Status:**` field
- **Detect quick mode from PRD:** If the PRD contains `**Quick:** true`, set `QUICK_MODE=true` internally
- **Save last-used slug:** `mkdir -p .prdx && echo "{SLUG}" > .prdx/last-slug`
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
- Check for last-used slug: `cat .prdx/last-slug 2>/dev/null`
- If last slug exists and matching PRD file exists, offer it as the first option via AskUserQuestion:
  - Option 1: "Continue {last-slug}" (Recommended) — Resume the last PRD you were working on
  - Option 2: "Choose a different PRD" — List all PRDs to pick from
  - Option 3: "Start a new feature" — Create a new PRD
- If no last slug, list existing PRDX plans using: `ls -la ~/.claude/plans/prdx-*.md 2>/dev/null`
  - Ask: "Start a new feature or continue an existing PRD?"

---

### Step 2: Planning

**⛔ SCOPE: This step ONLY creates a PRD document. No application code, no branches, no implementation.** `/prdx:plan` enters plan mode to write a document. When the user approves the document, plan mode exits and a decision point is shown. Implementation happens in Step 3 — ONLY if the user chooses "Implement now".

**If QUICK_MODE:**

**Save workflow state before planning (with unique tentative ID):**
```bash
mkdir -p .prdx/state
TENTATIVE_ID="quick-TENTATIVE-${RANDOM}${RANDOM}"
cat > .prdx/state/${TENTATIVE_ID}.json << EOF
{"slug": "${TENTATIVE_ID}", "phase": "planning", "quick": true}
EOF
```
(Slug is tentative — derive from description in kebab-case. Plan.md will finalize the slug in the state file and last-slug. The random suffix prevents collisions between concurrent sessions.)

Run the planning command with the `--quick` flag:

```
/prdx:plan --quick [description]
```

This enters plan mode with a lightweight template (Problem, Goal, Acceptance Criteria, Approach only). The PRD is saved as `prdx-quick-{slug}.md`.

> **MANDATORY:** During planning, ALL codebase exploration MUST use `prdx:code-explorer` and `prdx:docs-explorer` agents via the Task tool. NEVER use the built-in `Explore` subagent, Glob, Grep, or Read for exploration. See `/prdx:plan` for details.

**IMPORTANT: Stop here and wait.** Plan mode is interactive. Do NOT proceed until:
1. Plan mode has completed (user approved the plan and ExitPlanMode was called)
2. The PRD file exists in `~/.claude/plans/prdx-quick-{slug}.md`

**After plan.md writes the real state file** (`.prdx/state/quick-{slug}.json`), delete the tentative file:
```bash
rm -f .prdx/state/${TENTATIVE_ID}.json
```

**⛔ AFTER PLAN MODE EXITS: Plan.md will show an AskUserQuestion decision point. Wait for the user's choice. DO NOT start implementing.**

Route based on the user's choice from plan.md:
- Implement → Phase 3
- Stop → Delete `.prdx/state/quick-{slug}.json` and end workflow. Tell user they can resume with `/prdx:prdx quick-{slug}`

**⛔ SAFETY CHECK:** If you find yourself about to call `/prdx:implement` or start writing code without the user explicitly choosing "Implement now" from the decision point above — STOP. You have skipped a mandatory decision point. Go back and ask the user.

**If NOT QUICK_MODE (normal mode):**

**Save workflow state before planning (with unique tentative ID):**
```bash
mkdir -p .prdx/state
TENTATIVE_ID="TENTATIVE-${RANDOM}${RANDOM}"
cat > .prdx/state/${TENTATIVE_ID}.json << EOF
{"slug": "${TENTATIVE_ID}", "phase": "planning", "quick": false}
EOF
```
(Slug is tentative — derive from description in kebab-case. Plan.md will finalize the slug in the state file and last-slug. The random suffix prevents collisions between concurrent sessions.)

Run the planning command with the feature description:

```
/prdx:plan [description]
```

This enters native plan mode and creates a PRD following the PRDX template format.

> **MANDATORY:** During planning, ALL codebase exploration MUST use `prdx:code-explorer` and `prdx:docs-explorer` agents via the Task tool. NEVER use the built-in `Explore` subagent, Glob, Grep, or Read for exploration. See `/prdx:plan` for details.

**IMPORTANT: Stop here and wait.** Plan mode is an interactive process where the user reviews and iterates on the PRD. Do NOT proceed to implementation until:
1. Plan mode has completed (user approved the plan and ExitPlanMode was called)
2. The PRD file exists in `~/.claude/plans/prdx-{slug}.md`

**After plan.md writes the real state file** (`.prdx/state/{slug}.json`), delete the tentative file:
```bash
rm -f .prdx/state/${TENTATIVE_ID}.json
```

**⛔ AFTER PLAN MODE EXITS: Plan.md will show an AskUserQuestion decision point. Wait for the user's choice. DO NOT start implementing.**

Route based on the user's choice from plan.md:
- Publish → Phase 2a (then ask about implementation)
- Implement → Phase 3
- Stop → Delete `.prdx/state/{slug}.json` and end workflow. Tell user they can resume with `/prdx:prdx [slug]`

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
- No → Delete `.prdx/state/{slug}.json` and end workflow

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

After displaying instructions, delete `.prdx/state/{SLUG}.json` and end workflow. The user manages child sessions independently.

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
- Test first → Delete `.prdx/state/quick-{slug}.json`. Tell user to test and resume with `/prdx:prdx quick-{slug}` when ready

**If NOT QUICK_MODE (normal mode):**
- Option 1: "Test first" (Recommended) - Let me verify the implementation works
- Option 2: "Create PR now" - Skip testing, go straight to PR
- Option 3: "Create Draft PR" — Mark as draft, not human-reviewed yet

Route based on choice:
- Test first → Delete `.prdx/state/{slug}.json`. End workflow, tell user to test and resume with `/prdx:prdx [slug]` when ready
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
   - Delete `.prdx/state/{SLUG}.json`
   - Display: `Resume later with /prdx:prdx {slug}`
   - Quick mode: proceed to Phase 5 (cleanup)

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
- Wait → Delete `.prdx/state/{SLUG}.json` and end workflow

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

  PRD: ~/.claude/plans/[slug].md
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
   rm ~/.claude/plans/prdx-quick-{slug}.md
   ```

2. **Delete workflow state:**
   ```bash
   rm -f .prdx/state/quick-{slug}.json
   ```

3. **Clear last-slug if it points to this quick task:**
   ```bash
   if [ "$(cat .prdx/last-slug 2>/dev/null)" = "quick-{slug}" ]; then
     rm .prdx/last-slug
   fi
   ```

4. **Display completion message:**
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
- Delete `.prdx/state/{slug}.json` on unrecoverable errors or when user chooses to abort

**Workflow state (`.prdx/state/{slug}.json`):**
- Written at phase transitions to enable resume after context clear
- Read at Step 1 to detect interrupted workflows
- Deleted at most terminal points (user stops, errors)
- Non-draft PR creation transitions to `"pushed"` phase (not deleted) to enable automatic lesson capture
- `"pushed"` state files are processed at next `/prdx:prdx` startup: merged PRs trigger lesson capture, then state file is deleted
