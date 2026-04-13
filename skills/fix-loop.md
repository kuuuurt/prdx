# Fix Loop Skill

Canonical specification for the AC fix loop and code-review fix loop used in PRDX implementation workflows. Both `commands/implement.md` (Task-tool callers) and `commands/prdx-agent.md` (SendMessage teammates) reference this skill for the loop structure, caps, and escalation options.

Use invocation-agnostic placeholders — callers substitute "invoke ac-verifier" / "invoke code-reviewer" with their actual mechanism (Task tool or SendMessage).

## AC Fix Loop (max 3 attempts)

**Goal:** Ensure all acceptance criteria are met before code review begins.

### Loop Structure

1. **Invoke ac-verifier** with the current diff and acceptance criteria from the PRD.
2. If **all ACs verified** → exit loop, proceed to code review.
3. If **any AC unmet or partial:**
   a. Display the AC verification summary to the user.
   b. **Invoke the platform developer** with the list of unmet/partial ACs. Ask it to fix each one, write missing tests, run tests, and commit.
   c. Wait for the developer's fix confirmation.
   d. **Invoke ac-verifier** again to re-verify.
   e. If all ACs now verified → exit loop.
   f. If still unmet and `attempt < 3` → increment attempt counter, go to step 3b.
4. **If ACs still unmet after 3 fix attempts** → escalate (see Escalation below).

### Stale Reviewer Output Rule

When AC verification runs **after** a parallel first-pass code review (e.g., the reviewer ran concurrently with implementation), **discard the reviewer's first-pass output** if any AC fix loop iterations occur. The diff changes during fixes; a review against the pre-fix diff is no longer valid. Re-run the code reviewer only after the AC fix loop converges.

This rule applies only when a first-pass reviewer result is already available. If code review has not started yet, no action is needed.

## Code Review Fix Loop (max 2 cycles)

**Goal:** Catch bugs, security issues, quality problems, and convention violations before the PR is created.

### Loop Structure

1. **Invoke code-reviewer** with the current diff. Ask it to report only issues with >80% confidence.
2. If **no issues found** → exit loop, proceed to post-implementation steps.
3. If **issues found (cycle 1):**
   a. Display the review summary to the user.
   b. **Invoke the platform developer** with the list of issues. Ask it to fix each one, run tests, and commit.
   c. Wait for the developer's fix confirmation.
   d. **Invoke code-reviewer** again to re-review.
   e. If **no issues** → exit loop.
   f. If **issues remain after cycle 2** → escalate (see Escalation below).

## Escalation (Caps Exhausted)

When either loop cap is exhausted and issues remain, use **AskUserQuestion** to offer the user a choice:

**AC loop exhausted (3 attempts):**
- Option 1: "Proceed to code review" (Recommended) — Continue with remaining AC gaps noted in completion summary
- Option 2: "Fix manually" — Stop here; user resolves AC issues; status stays `in-progress`
- Option 3: "Stop implementation" — Halt workflow entirely; resume with `/prdx:implement {slug}`

**Review loop exhausted (2 cycles):**
- Option 1: "Proceed anyway" (Recommended) — Continue to post-implementation steps with remaining issues noted
- Option 2: "Fix manually" — Stop here; user resolves remaining issues; status stays `in-progress`
- Option 3: "Stop implementation" — Halt workflow entirely; resume with `/prdx:prdx {slug}`

Route based on user's choice. If "Proceed" is chosen, include the remaining unresolved items in the completion summary so they are visible in the PR description.
