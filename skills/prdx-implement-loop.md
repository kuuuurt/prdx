# PRDX Implement Loop

Step 5 of `/prdx:implement`: the full agent-orchestration body (dev planning, phased execution, AC verification + code review, fix loops, auto-simplify).

Pulled out of `commands/implement.md` so:
- Parent PRDs (which stop at Step 2b) never load this content.
- Has one source of truth for the loop spec (other callers can reuse if added later).
- The thin command stays readable.

## Inputs from the caller

The command sets these before invoking this skill:

- `SLUG`, `PLATFORM`, `PLATFORM_FROM_PRD`, `LITE_MODE`
- `DEFAULT_BRANCH`, `BRANCH`, `PRD_FILE`
- `NO_CACHE` (passthrough to dev-planner)
- `COMMIT_INSTRUCTIONS` (built in command Step 1b)

All agent prompts pass **paths, not content** — every agent reads what it needs from `.prdx/state/{SLUG}/`. See `commands/plan.md` Step 4.7 for the shard layout.

---

## Step 5a: Dev Planning (prdx:dev-planner)

**Lite-mode shortcut — check this FIRST:**

If the PRD has `**Lite:** true`, skip the dev-planner round-trip. Lite-mode PRDs are small in scope — synthesize a single-phase plan and write the shard directly to disk:

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh"
cp "$(shard_path {SLUG})/prd/approach.md" "$(shard_path {SLUG})/dev-plan/phases/1-implementation.md"
shard_index_append {SLUG} dev-plan/phases/1-implementation.md "Lite-mode single phase content"
echo '[{"phase":1,"name":"Implementation","mode":"sequential"}]' | shard_write {SLUG} dev-plan/phase-summary.json "Phase summary"
```

Then proceed to Step 5c with `PHASES = [{"phase": 1, "name": "Implementation", "mode": "sequential"}]`.

---

**Non-lite path (normal PRDs):**

Display progress: `Phase 1/4: Dev Planning — Creating implementation plan...`

Invoke the dev-planner agent using the Task tool:

```
subagent_type: "prdx:dev-planner"

prompt: "Create a detailed implementation plan for this PRD.

Slug: {SLUG}
Platform: {PLATFORM}
NO_CACHE: {NO_CACHE}
INDEX: .prdx/state/{SLUG}/INDEX.md
PRD File (full, human-readable): {PRD_FILE}

Read INDEX.md first to discover prd/ shards. Read prd/problem.md, prd/acceptance.md, prd/approach.md. Read skills and explore the codebase.

Write your output as shards under .prdx/state/{SLUG}/dev-plan/:
- dev-plan/architecture.md
- dev-plan/files.md
- dev-plan/phases/N-{name}.md  (one per phase)
- dev-plan/phase-summary.json

Use shard_write from hooks/prdx/state-shard.sh.

Return ONLY a brief summary (≤10 lines): phase count, phase names, any PRD gaps."
```

**On dev-planner failure:** AskUserQuestion — Retry / Skip to manual (no dev plan, developer explores codebase itself) / Stop.

## Step 5b: Parse Dev Plan into Phases

Read `dev-plan/phase-summary.json` to get the phase list — **do not load the full dev plan into context**.

```bash
PHASES=$(cat ".prdx/state/{SLUG}/dev-plan/phase-summary.json" 2>/dev/null)
```

**Fallbacks:**
1. Glob `.prdx/state/{SLUG}/dev-plan/phases/*.md`. Filename `N-{name}.md` yields phase number and name. Mode defaults to `sequential` unless filename ends `-parallel.md`.
2. If no phase files exist: `PHASES = [{"phase": 1, "name": "Full Implementation", "mode": "sequential"}]`.

Phase content stays on disk — orchestrator carries only the `{phase, name, mode}` triples.

Display: `Parsed dev plan: {N} phases ({list})`

## Step 5c: Phased Execution Loop

Use `prdx:developer` for all platforms. `PLATFORM_FROM_PRD` is a free-form string (e.g., `backend`, `ios`, `python`, `flutter`) — pass it as a hint.

**No `COMPLETED_PHASES` tracking in orchestrator.** Prior phase summaries live at `.prdx/state/{SLUG}/phases/*.md`.

**For each phase in PHASES (sequentially):**

Display: `Phase {PHASE_NUM}/{TOTAL_PHASES}: {PHASE_NAME} ({PHASE_MODE})...`

Invoke developer:

```
subagent_type: "prdx:developer"

prompt: "Implement Phase {PHASE_NUM}/{TOTAL_PHASES}: {PHASE_NAME}

Slug: {SLUG}
Platform hint: {PLATFORM_FROM_PRD}
Mode: phase
Phase: {PHASE_NUM}
Phase name: {PHASE_NAME}
Phase mode: {PHASE_MODE}
INDEX: .prdx/state/{SLUG}/INDEX.md

## Where to read
- INDEX.md — manifest
- prd/acceptance.md — ACs your work must satisfy
- dev-plan/architecture.md — design context (read once)
- dev-plan/files.md — file inventory (read once)
- dev-plan/phases/{PHASE_NUM}-*.md — YOUR phase content
- phases/{PRIOR}.md — only if your phase is sequential and depends on prior work

Do NOT read prd/problem.md or prd/approach.md unless your phase content references them.

## Phase execution rules
- {PHASE_MODE}: parallel = tasks independent (multi Edit/Write in one response); sequential = each before next
- Use TodoWrite to track tasks
- One atomic commit at the end of this phase

## Commit format
{COMMIT_INSTRUCTIONS}

## Output
After committing, write your phase summary to .prdx/state/{SLUG}/phases/{PHASE_NUM}.md via shard_write.

Return ONLY a one-line confirmation: 'Phase {PHASE_NUM} complete — N files, M commits, tests {pass|fail}'."
```

**After each phase:**
- Summary on disk; orchestrator stores nothing.
- Display: `Phase {PHASE_NUM}/{TOTAL}: {PHASE_NAME} — Done`

**On phase failure:** AskUserQuestion — Retry / Skip (write `## Phase {N} — SKIPPED` to `phases/{N}.md`, continue) / Continue manually / Stop.

## Step 5d: Platform Completion

After all phases:

1. Update PRD with implementation notes section (append):
   ```
   ## Implementation Notes ({PLATFORM})
   **Branch:** {BRANCH}
   **Implemented:** {TODAY}
   {IMPLEMENTATION_SUMMARY}
   ```
2. For child PRDs (has `**Parent:**` field): update `.prdx/state/{SLUG}.json` with phase=review, parent={PARENT_SLUG}.
3. Continue to Step 5e.

## Step 5e: AC Verification + Code Review — Parallel First Pass

Display: `Phase 3/3: AC Verification + Code Review — Running in parallel...`

Pre-compute diff LOC:
```bash
DIFF_LOC=$(git diff {DEFAULT_BRANCH}..HEAD | grep -c '^[+-]' || echo 0)
```

**Make both Task calls in a single message (parallel):**

```
subagent_type: "prdx:ac-verifier"

prompt: "Verify the acceptance criteria.

Slug: {SLUG}
Base Branch: {DEFAULT_BRANCH}
Platform: {PLATFORM}
INDEX: .prdx/state/{SLUG}/INDEX.md

Read ONLY prd/acceptance.md. Check git diff {DEFAULT_BRANCH}..HEAD against each AC (three-point check: code exists, test exists, coverage).

Write verdict to reviews/ac-verdict.md via shard_write.
Return ONLY 'AC verdict: X met, Y partial, Z not met'."
```

```
subagent_type: "prdx:reviewer-orchestrator"

prompt: "Review the implementation.

Slug: {SLUG}
Base Branch: {DEFAULT_BRANCH}
Platform: {PLATFORM}
Diff LOC: {DIFF_LOC}
INDEX: .prdx/state/{SLUG}/INDEX.md (read prd/acceptance.md only if needed)

Review git diff {DEFAULT_BRANCH}..HEAD. Dispatch specialists by diff size. Classify findings as AUTO-FIX or ASK. Apply AUTO-FIX silently.

Write findings to reviews/code-review.md via shard_write.
Return ONLY 'Review: N ASK findings, M auto-fixed' plus ASK list (≤10 lines)."
```

**Routing (four branches):**

1. **Both clean** → Step 5g (skip Step 6 in skill; caller handles post-implement hook).
2. **AC fails, review clean** → Discard reviewer output (it may have assumed ACs met). Run Step 5e-fix. After AC converges, re-run reviewer. If review now fails, Step 5f-fix. Then 5g.
3. **AC clean, review fails** → Step 5f-fix directly (max 2 cycles). Then 5g.
4. **Both fail** → Step 5e-fix first (correctness before quality). Re-run reviewer. If review still fails, Step 5f-fix. Then 5g.

## Step 5e-fix: AC Fix Loop

Max 3 attempts. On exhaustion → AskUserQuestion (Proceed to code review / Fix manually / Stop). See `skills/fix-loop.md` for the loop spec.

```
subagent_type: "prdx:developer"

prompt: "Fix unmet acceptance criteria.

Slug: {SLUG}
Mode: ac-fix
Attempt: {ATTEMPT_NUM}
INDEX: .prdx/state/{SLUG}/INDEX.md

Read:
- reviews/ac-verdict.md — failing ACs
- prd/acceptance.md — full AC list

Live context:
- git diff {DEFAULT_BRANCH}..HEAD --name-only
- git log {DEFAULT_BRANCH}..HEAD --oneline

Fix each unmet/partial AC, write tests, commit.
{COMMIT_INSTRUCTIONS}

Write summary to reviews/fixes/ac-{ATTEMPT_NUM}.md via shard_write.
Return ONLY one-line confirmation."
```

Re-run `prdx:ac-verifier` after each fix.

## Step 5f-fix: Code Review Fix Loop

Max 2 cycles. On exhaustion → AskUserQuestion (Proceed anyway / Fix manually / Stop).

```
subagent_type: "prdx:developer"

prompt: "Fix code review issues.

Slug: {SLUG}
Mode: review-fix
Cycle: {CYCLE_NUM}
INDEX: .prdx/state/{SLUG}/INDEX.md

User-approved ASK findings (the only ones to fix):
{ASK_FINDINGS — inline ≤15 lines, else write to reviews/fixes/review-{CYCLE_NUM}-input.md and reference}

Live context:
- git diff {DEFAULT_BRANCH}..HEAD --name-only
- git log {DEFAULT_BRANCH}..HEAD --oneline

Fix, test, commit.
{COMMIT_INSTRUCTIONS}

Write summary to reviews/fixes/review-{CYCLE_NUM}.md via shard_write.
Return ONLY one-line confirmation."
```

Re-run reviewer (pre-compute updated `DIFF_LOC` first):

```
subagent_type: "prdx:reviewer-orchestrator"

prompt: "Re-review after fixes.

Slug: {SLUG}
Base Branch: {DEFAULT_BRANCH}
Platform: {PLATFORM}
Diff LOC: {UPDATED_DIFF_LOC}
INDEX: .prdx/state/{SLUG}/INDEX.md
Prior review: reviews/code-review.md (check if findings resolved)

Apply AUTO-FIX silently. Overwrite reviews/code-review.md. Return ONLY one-line summary."
```

Loop until clean or 2 cycles exhausted. Then Step 5g.

## Step 5g: Auto-Simplify Changed Files

Once review is clean, run mechanical simplification on changed files. No re-review — rules are deterministic.

1. Collect changed source files:
   ```bash
   git diff --name-only {DEFAULT_BRANCH}..HEAD | grep -E '\.(kt|swift|ts|tsx|js|jsx|py|go|rb|java|rs)$' || true
   ```
   Empty → return to caller.

2. Apply `commands/simplify.md` rules per file: remove doc-style comments (keep `// MARK:`, `// TODO:`, `// FIXME:`, why-comments, workaround explanations, legal headers, `@Suppress`/`@ts-expect-error`), inline single-use locals/private functions when clear. Do NOT change behavior or touch unchanged files.

3. Commit if anything changed:
   ```bash
   if ! git diff --quiet; then
     git add -A
     git commit -m "refactor: simplify changed files post-review

   $COMMIT_TRAILERS"
   fi
   ```
   Use `COMMIT_INSTRUCTIONS` trailers. Nothing changed → no commit, no message.

Return control to the caller (which runs the post-implement hook, status update, and completion display).
