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

### Step 1: Determine Entry Point

**First, parse `--quick` flag:**
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
- For multi-platform mobile PRDs, also check which platforms have been implemented (look for `## Implementation Notes (android)` and `## Implementation Notes (ios)` sections)
- Resume from the appropriate phase:
  - `planning` → Continue planning (Phase 2)
  - `in-progress` → Continue implementation (Phase 3)
    - For multi-platform: Check which platforms are done, resume with remaining platform
  - `review` → Ask user: Fix issues OR Create PR? (Phase 3a)
  - `implemented` → PR already created, inform user and show PR link from PRD
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

**If QUICK_MODE:**

Run the planning command with the `--quick` flag:

```
/prdx:plan --quick [description]
```

This enters plan mode with a lightweight template (Problem, Goal, Acceptance Criteria, Approach only). The PRD is saved as `prdx-quick-{slug}.md`.

> **MANDATORY:** During planning, ALL codebase exploration MUST use `prdx:code-explorer` and `prdx:docs-explorer` agents via the Task tool. NEVER use the built-in `Explore` subagent, Glob, Grep, or Read for exploration. See `/prdx:plan` for details.

**IMPORTANT: Stop here and wait.** Plan mode is interactive. Do NOT proceed until:
1. Plan mode has completed (user approved the plan and ExitPlanMode was called)
2. The PRD file exists in `~/.claude/plans/prdx-quick-{slug}.md`

**After plan mode completes (quick mode), STOP and use AskUserQuestion:**
- Option 1: "Implement now" (Recommended) — Start coding immediately
- Option 2: "Stop here" — Review plan later

Note: No "Publish to GitHub" option in quick mode — these are ephemeral tasks.

Route based on choice:
- Implement → Phase 3
- Stop → End workflow, tell user they can resume with `/prdx:prdx quick-{slug}`

**If NOT QUICK_MODE (normal mode):**

Run the planning command with the feature description:

```
/prdx:plan [description]
```

This enters native plan mode and creates a PRD following the PRDX template format.

> **MANDATORY:** During planning, ALL codebase exploration MUST use `prdx:code-explorer` and `prdx:docs-explorer` agents via the Task tool. NEVER use the built-in `Explore` subagent, Glob, Grep, or Read for exploration. See `/prdx:plan` for details.

**IMPORTANT: Stop here and wait.** Plan mode is an interactive process where the user reviews and iterates on the PRD. Do NOT proceed to implementation until:
1. Plan mode has completed (user approved the plan and ExitPlanMode was called)
2. The PRD file exists in `~/.claude/plans/prdx-{slug}.md`

**After plan mode completes and the PRD is saved, STOP and use AskUserQuestion to ask:**
- Option 1: "Publish to GitHub" (create issue for team visibility)
- Option 2: "Implement now" (start coding immediately)
- Option 3: "Stop here" (review PRD later)

Route based on choice:
- Publish → Phase 2a (then ask about implementation)
- Implement → Phase 3
- Stop → End workflow, tell user they can resume with `/prdx:prdx [slug]`

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
- No → End workflow

---

### Step 3: Implementation

**Check if this is a multi-platform mobile PRD:**

Read the PRD and check for `**Platforms:**` field with multiple platforms (e.g., "android, ios").

**For single-platform PRDs:**
```
/prdx:implement [slug]
```
Wait for implementation to complete, then proceed to review decision.

**For multi-platform mobile PRDs:**

Implementation runs **sequentially** per platform to learn from the first implementation.

1. **First Platform (Android):**
   - Display: "Starting Android implementation..."
   - Run: `/prdx:implement [slug] android`
   - Wait for completion

2. **Between Platforms - Ask User:**
   Use AskUserQuestion:
   - Option 1: "Continue to iOS" (Recommended)
   - Option 2: "Stop here, I'll continue iOS later"
   - Option 3: "Skip iOS, Android only"

   Route based on choice:
   - Continue → Proceed to iOS
   - Stop → End workflow, tell user to resume with `/prdx:prdx [slug]`
   - Skip → Update PRD to remove iOS from Platforms, proceed to review

3. **Second Platform (iOS):**
   - Display: "Starting iOS implementation (applying learnings from Android)..."
   - Run: `/prdx:implement [slug] ios`
   - Wait for completion

**IMPORTANT: After implementation completes, STOP and use AskUserQuestion:**

Do NOT proceed to create PR automatically. The user must test the implementation first.

**If QUICK_MODE:**
- Option 1: "Create PR" (Recommended) — Ready for review
- Option 2: "Done" — Commit only, no PR needed
- Option 3: "Test first" — Let me verify first

Route based on choice:
- Create PR → Run `/prdx:push quick-{slug}` directly, then proceed to Phase 5 (cleanup)
- Done → Proceed to Phase 5 (cleanup) immediately — no PR
- Test first → Tell user to test and resume with `/prdx:prdx quick-{slug}` when ready

**If NOT QUICK_MODE (normal mode):**
- Option 1: "Test first" (Recommended) - Let me verify the implementation works
- Option 2: "Create PR now" - Skip testing, go straight to PR

Route based on choice:
- Test first → End workflow, tell user to test and resume with `/prdx:prdx [slug]` when ready
- Create PR now → Run `/prdx:push [slug]` directly (do NOT ask for confirmation again — user already confirmed)

---

### Step 3a: Review Status Decision

**When PRD status is `review`:**

The implementation is complete but user hasn't confirmed it's ready for PR. Use AskUserQuestion:

**If QUICK_MODE:**
- Option 1: "Create PR" (Recommended) — Ready for review
- Option 2: "Done" — Commit only, no PR needed
- Option 3: "Fix issues" — Found bugs or need changes

Route:
- Create PR → Run `/prdx:push quick-{slug}` directly, then proceed to Phase 5 (cleanup)
- Done → Proceed to Phase 5 (cleanup) immediately
- Fix issues → Same as normal mode below

**If NOT QUICK_MODE (normal mode):**
- Option 1: "Create PR" (Recommended) - Implementation looks good, ready for review
- Option 2: "Fix issues" - Found bugs or need changes
- Option 3: "View implementation summary" - Review what was done

**Route based on choice:**
- Create PR → Run `/prdx:push [slug]` directly (do NOT ask for confirmation again — user already confirmed)
- Fix issues → Tell user to describe the issues. Claude will fix them in the current conversation (no need to re-run full implement). After fixes are committed, ask again.
- View summary → Show the implementation notes from the PRD, then ask again

**Important:** When user chooses "Fix issues", do NOT re-run `/prdx:implement`. Instead:
1. Ask user to describe the bugs/issues
2. Fix them directly in the conversation
3. Commit the fixes
4. Ask the review decision again

---

### Step 4: Create Pull Request

**Confirm before creating PR** — but only if the user hasn't already explicitly chosen "Create PR" or "Create PR now" in a previous step. If they have, skip this confirmation and run `/prdx:push` directly.

Use AskUserQuestion to confirm:
- Option 1: "Yes, create PR" - Ready to submit for review
- Option 2: "No, wait" - Need more time

If user confirms, run the push command:

```
/prdx:push [slug]
```

**After PR is created:**

**If QUICK_MODE:** Proceed to Phase 5 (cleanup), then display completion.

**If NOT QUICK_MODE:** Display completion message:

```
Feature complete!

PRD: ~/.claude/plans/[slug].md
PR: #[pr-number]

The feature is ready for review.
```

---

### Step 5: Cleanup (Quick Mode Only)

**This step only runs when QUICK_MODE is true.** It runs after the workflow completes (PR created, or user chose "Done").

1. **Delete the temporary PRD file:**
   ```bash
   rm ~/.claude/plans/prdx-quick-{slug}.md
   ```

2. **Clear last-slug if it points to this quick task:**
   ```bash
   if [ "$(cat .prdx/last-slug 2>/dev/null)" = "quick-{slug}" ]; then
     rm .prdx/last-slug
   fi
   ```

3. **Display completion message:**

   If PR was created:
   ```
   Done! PR: #[pr-number]

   Quick task cleaned up — no PRD artifact left behind.
   ```

   If user chose "Done" (no PR):
   ```
   Done! Changes committed on branch {BRANCH}.

   Quick task cleaned up — no PRD artifact left behind.
   Push when ready: git push -u origin {BRANCH}
   ```

---

## Important Guidelines

**CRITICAL: Never skip user decision points. ALWAYS use AskUserQuestion.**
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
