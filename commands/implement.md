---
description: "Implement feature by delegating to platform-specific agent"
argument-hint: "[slug]"
---

## Pre-Computed Context

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-plans-dir.sh"
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-default-branch.sh"
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-commit-config.sh"
PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
AVAILABLE_PRDS=$(grep -rl "^\*\*Project:\*\* $PROJECT_NAME" "$PLANS_DIR"/*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^prdx-//' || true)
```

# /prdx:implement - Implement Feature

Three-phase implementation: **Dev Planning** (prdx:dev-planner) → **Development** (Platform agent) → **Code Review** (prdx:reviewer-orchestrator)

Both agents run in **isolated contexts** to minimize main conversation context usage.

**PRDs are read from `{PLANS_DIR}/`** (created by native plan mode).

**For PRDs with multiple platforms:** Implementation runs per the PRD's `**Implementation Order:**`.

## Usage

```bash
/prdx:implement backend-auth                    # Single-platform PRD
/prdx:implement biometric-auth                  # Parent PRD → shows child instructions
/prdx:implement biometric-auth-backend          # Child PRD → runs implementation
/prdx:implement biometric-auth-android          # Child PRD → checks prerequisites, runs implementation
/prdx:implement backend-auth --no-cache         # Force fresh codebase exploration (skip cache)
```

## How It Works

This command orchestrates three agents in **isolated contexts**:

**Phase A: Dev Planning (prdx:dev-planner)**
- Runs in isolated context
- Explores codebase for detailed technical context
- Creates implementation plan with specific tasks
- Returns only the dev plan (~3KB)

**Phase B: Development (Platform agent — phased execution)**
- Dev plan is parsed into phases (via phase-summary JSON, header regex fallback, or single-phase fallback)
- Platform agent is invoked **once per phase** with focused, phase-scoped context
- Prior phase summaries (files created, commits) are passed as context to subsequent phases
- Each phase produces one atomic commit
- Progress displayed: "Phase 2/4: Core Logic (sequential)..."
- Returns only implementation summary per phase (~1KB each)

**Phase C: Code Review (prdx:reviewer-orchestrator)**
- Runs in isolated context
- Routes based on diff LOC: <50 LOC uses fast single-pass, ≥50 LOC dispatches specialist sub-agents in parallel
- Diffs ≥200 LOC or any critical finding also trigger an adversarial red-team pass
- Classifies findings as AUTO-FIX (applied silently) or ASK (batched into one user prompt)
- If ASK findings remain after user response: platform agent fixes, then re-review (max 2 cycles)
- Returns only review pipeline summary (~2KB)

**For Multi-Platform PRDs (parent-child model):**
- Parent PRDs delegate to child PRDs (Step 2b) — they are never directly implemented
- Each child PRD runs the full Phase A + B + C pipeline independently
- Child sessions check sibling prerequisites via `.prdx/state/` files (Step 2c)
- Children on the same Implementation Order step can run in parallel sessions (separate branches)

## Workflow

### Step 1: Load Configuration

Commit config is pre-loaded via Pre-Computed Context (`resolve-commit-config.sh`). The following variables are available: `COMMIT_FORMAT`, `COAUTHOR_ENABLED`, `COAUTHOR_NAME`, `COAUTHOR_EMAIL`, `EXTENDED_DESC_ENABLED`, `CLAUDE_LINK_ENABLED`.

#### Step 1b: Build Commit Instructions

Build `COMMIT_INSTRUCTIONS` from the pre-loaded config (HEREDOC commit). Lines, in order, conditional on flags:

- Subject: `{type}: {desc}` if `COMMIT_FORMAT=conventional`, else `{desc}`
- Body (if `EXTENDED_DESC_ENABLED=true`)
- `🤖 Generated with [Claude Code](https://claude.com/claude-code)` (if `CLAUDE_LINK_ENABLED=true`)
- `Co-Authored-By: {COAUTHOR_NAME} <{COAUTHOR_EMAIL}>` (if `COAUTHOR_ENABLED=true`; `GIT_AUTHOR_NAME` set → use `claude[bot]` + `github-actions[bot]`)

Store ONE example commit matching the resolved config.

### Step 1b.5: Parse Flags

Before loading the PRD, parse flags from the argument string.

**Strip `--no-cache` flag from the slug argument:**

The argument may be `{slug} --no-cache` or `--no-cache {slug}`. Extract and remove the flag:

```
NO_CACHE=false
if argument contains "--no-cache":
    NO_CACHE=true
    slug = argument with "--no-cache" stripped and trimmed
```

Store `NO_CACHE` — it will be passed to the dev-planner agent in Step 5a.

### Step 2: Load PRD

**Resolve slug to PRD file:**

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-slug.sh" "$SLUG_INPUT"
# → sets: RESOLVED_SLUG, PRD_FILE, RENAMED
# → on ambiguity or not-found: writes to stderr and returns 1 — use AskUserQuestion to disambiguate
```

If `RENAMED=true`, inform the user: `Renamed plan to follow PRDX naming convention: prdx-{slug}.md`

3. Read the PRD file and extract:
   - **Platform** (single-platform PRDs: free-form string, e.g., backend, frontend, android, ios, python, go, etc.)
   - **Platforms** (multi-platform PRDs: e.g., "backend, android, ios")
   - **Implementation Order** (multi-platform PRDs: ordered steps)
   - Type (feature/bug-fix/refactor/spike)
   - Branch name from `**Branch:**` field
   - Status from `**Status:**` field
   - Full PRD content

**Detect PRD type:**
- If PRD contains `## Children` section → it is a **parent PRD**. Go to Step 2b (Parent PRD Handling).
- If PRD contains `**Parent:**` field → it is a **child PRD**. Go to Step 2c (Prerequisite Check), then continue with normal flow (Steps 3-7) using the child PRD's single platform.
- Otherwise → it is a **single-platform PRD**. Continue with normal flow (Steps 3-7) unchanged.

**For child PRDs:** Also write/update the child's state file:
```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "in-progress", "lite": false, "parent": "{PARENT_SLUG}"}
EOF
```
(Extract `{PARENT_SLUG}` from the `**Parent:**` field in the child PRD.)

4. **Update status to `in-progress`:**
   Edit the PRD file to change `**Status:** planning` to `**Status:** in-progress`

### Step 2b: Parent PRD Handling

**This step runs only when the loaded PRD is a parent PRD (contains `## Children` section).**

Parent PRDs are orchestration-only. They are NOT directly implemented — they delegate to child PRDs.

1. **Parse children:** Read the `## Children` section to get child slugs, platforms, and branches.

2. **Check child state files:** For each child, read `.prdx/state/{child-slug}.json` if it exists. If no state file exists, status is `planning`.

3. **Parse Implementation Order** from the parent PRD to understand which children should be implemented first.

4. **Display progress table:**
   ```
   Parent PRD: {PARENT_SLUG}
   Implementation Order: {ORDER_SUMMARY}

   | Child PRD | Platform | Branch | Status |
   |-----------|----------|--------|--------|
   | {child-slug-1} | backend | feat/{parent}-backend | in-progress |
   | {child-slug-2} | android | feat/{parent}-android | planning |
   ```

5. **Check for missing child PRD files:** For each child slug listed in `## Children`, verify the PRD file exists at `{PLANS_DIR}/prdx-{child-slug}.md`. If any are missing:
   ```
   Warning: Child PRD file not found: prdx-{child-slug}.md
   Re-run /prdx:plan to regenerate, or create manually.
   ```

6. **Display session instructions:**

   Determine which children are ready to implement based on Implementation Order and sibling state:

   For each step, check if all children in previous steps have status ≥ `review`. Mark children whose prerequisites are met as "ready".

   ```
   To implement this feature, run each child PRD in a separate Claude session:

   Step 1 (ready):
     /prdx:implement {child-slug-backend}

   Step 2 (waiting for step 1):
     /prdx:implement {child-slug-android}
     /prdx:implement {child-slug-ios}

   Children on the same step can run in parallel sessions (they have separate branches).
   Check progress anytime: /prdx:show {parent-slug}
   ```

   Mark steps as "ready", "in progress", "waiting for step N", or "done" based on child state files.

7. **Derive and display parent status:**

   Read all child state files and compute parent status using the ordering:
   `planning < in-progress < review < implemented < completed`

   Parent status = minimum status across all children.

   Display: `Overall status: {derived-status}`

8. **STOP here.** Do NOT proceed to Steps 3-7. The parent PRD delegates all implementation to child sessions.

---

### Step 2c: Child PRD Prerequisite Check

**This step runs only when the loaded PRD is a child PRD (has `**Parent:**` field).**

Before starting implementation, verify that prerequisites from the Implementation Order are met.

1. **Read the parent PRD:** Load `{PLANS_DIR}/prdx-{PARENT_SLUG}.md`
   - If parent PRD file not found, warn but continue (parent may have been deleted)

2. **Parse Implementation Order** from the parent PRD into ordered steps.

3. **Determine this child's step number:** Find which step contains this child's platform.

4. **If step > 1**, check prerequisites:
   - For each child in all earlier steps, read `.prdx/state/{child-slug}.json`
   - Check if their `phase` is at least `"review"` (meaning implementation is complete)

5. **If any prerequisite is not met**, warn:
   ```
   ⚠️  Prerequisite not met

   This child ({PLATFORM}) is in Implementation Order step {M}.
   Step {N} child "{sibling-slug}" ({sibling-platform}) is still: {sibling-status}

   Implementation Order requires step {N} to complete before step {M}.

   Continue anyway? (y/n)
   ```
   Use AskUserQuestion. If user declines, stop. If user confirms, continue.

6. **If all prerequisites are met** (or step = 1), continue to Step 3.

### Step 3: Run Pre-Implement Hook

Check if hook exists and run it:

```bash
if [ -f hooks/prdx/pre-implement.sh ]; then
  ./hooks/prdx/pre-implement.sh "{slug}"
fi
```

If hook fails (non-zero exit), stop and show the error.

### Step 4: Git Setup

1. Get current branch: `git branch --show-current`
2. Determine default branch (main or master)
3. **Read branch from PRD** - The PRD's `**Branch:**` field contains the designated branch
   - If Branch field is missing, error: "PRD missing Branch field. Re-run /prdx:plan to regenerate."

4. If on default branch, checkout/create the feature branch:
   ```bash
   git checkout -b {BRANCH_FROM_PRD} 2>/dev/null || git checkout {BRANCH_FROM_PRD}
   ```

5. If already on a different feature branch, warn user:
   ```
   ⚠️  Currently on branch '{CURRENT}' but PRD expects '{BRANCH_FROM_PRD}'

   Each PRD corresponds to exactly one branch.
   Switch to the correct branch? (y/n)
   ```

**Important:** Each PRD = 1 branch = 1 PR. Do not create new branches for existing PRDs.

### Step 5: Platform Implementation

This step handles a **single platform** — the one from the PRD's `**Platform:**` field.

Multi-platform features are handled via parent-child PRDs: each child is a single-platform PRD that runs through this step independently in its own session.

---

#### Step 5a: Dev Planning (prdx:dev-planner)

**Lite-mode shortcut — check this FIRST:**

If the PRD has `**Lite:** true`, skip this step entirely.

Lite-mode PRDs are small in scope — the dev-planner round-trip is wasted context.
Instead, synthesize a single-phase plan and write the shard directly to disk:

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh"
# Use prd/approach.md as the phase content (already sharded in /prdx:plan Step 4.7)
cp "$(shard_path {SLUG})/prd/approach.md" "$(shard_path {SLUG})/dev-plan/phases/1-implementation.md"
shard_index_append {SLUG} dev-plan/phases/1-implementation.md "Lite-mode single phase content"
echo '[{"phase":1,"name":"Implementation","mode":"sequential"}]' | shard_write {SLUG} dev-plan/phase-summary.json "Phase summary"
```

Then proceed to Step 5c with `PHASES = [{"phase": 1, "name": "Implementation", "mode": "sequential"}]`.

---

**Non-lite path (normal PRDs):**

**Display progress:**
```
Phase 1/4: Dev Planning — Creating implementation plan...
```

Invoke the dev-planner agent using the Task tool. **Pass paths, not content** — the agent reads what it needs from the sharded state directory:

```
subagent_type: "prdx:dev-planner"

prompt: "Create a detailed implementation plan for this PRD.

Slug: {SLUG}
Platform: {PLATFORM}  (e.g., 'android' or 'ios')
NO_CACHE: {NO_CACHE}  (true = skip exploration cache and force fresh codebase exploration)
INDEX: .prdx/state/{SLUG}/INDEX.md
PRD File (full, human-readable): {PRD_FILE}

Read INDEX.md first to discover prd/ shards. Read prd/problem.md, prd/acceptance.md, prd/approach.md. Read skills and explore the codebase.

Write your output as shards under .prdx/state/{SLUG}/dev-plan/:
- dev-plan/architecture.md     (high-level design)
- dev-plan/files.md            (file inventory)
- dev-plan/phases/N-{name}.md  (one per phase; include the phase content the developer will execute)
- dev-plan/phase-summary.json  (the <!-- phase-summary --> JSON array, as a standalone file)

Use the state-shard helper for writes:
  source \"\$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh\"
  cat ... | shard_write {SLUG} dev-plan/architecture.md \"Architecture overview\"
  ...etc

Return ONLY a brief summary (≤10 lines): phase count, phase names, any PRD gaps. Do NOT echo the dev plan back."
```

The dev-planner output stays on disk — orchestrator never carries the full plan in main context. Wait for the brief summary.

**If dev-planner fails or returns an error:**

Use AskUserQuestion to offer recovery options:
- Option 1: "Retry dev planning" — Re-invoke the dev-planner agent
- Option 2: "Skip to manual implementation" — Proceed to platform agent without a dev plan (agent will explore codebase itself)
- Option 3: "Stop implementation" — Halt and let user investigate

Route based on choice:
- Retry → Re-run Step 5a
- Skip → Proceed to Step 5b with a note that no dev plan is available (platform agent should explore codebase independently)
- Stop → End workflow, show how to resume with `/prdx:implement {slug}`

#### Step 5b: Parse Dev Plan into Phases

The dev-planner wrote a `dev-plan/phase-summary.json` file. Read it to get the phase list — **do not load the full dev plan into context**.

```bash
PHASE_SUMMARY_FILE=".prdx/state/{SLUG}/dev-plan/phase-summary.json"
PHASES=$(cat "$PHASE_SUMMARY_FILE" 2>/dev/null)
```

**Fallbacks (if `phase-summary.json` is missing or malformed):**

1. **Glob phase files**: List `.prdx/state/{SLUG}/dev-plan/phases/*.md`. Each filename `N-{name}.md` yields phase number and name. Mode defaults to `sequential` unless filename ends `-parallel.md`.
2. **Single phase**: If no phase files exist, synthesize:
   ```
   PHASES = [{"phase": 1, "name": "Full Implementation", "mode": "sequential"}]
   ```
   and treat the entire dev plan as phase 1.

**Phase content is NOT loaded into the orchestrator** — each phase's markdown lives at `.prdx/state/{SLUG}/dev-plan/phases/N-{name}.md` and is read by the developer agent directly.

Store only `PHASES` (the small JSON array of `{phase, name, mode}` triples) in orchestrator memory.

**Display parsing result:**
```
Parsed dev plan: {N} phases ({list of "Phase N: Name (mode)" entries})
```

#### Step 5c: Phased Execution Loop

Use `prdx:developer` for all platforms. The platform field is a free-form string (e.g., `backend`, `ios`, `android`, `frontend`, `python`, `go`, `rust`, `flutter`, or any other value). Pass it as a hint so the agent can prioritize which dependency files and patterns to look for.

**No `COMPLETED_PHASES` tracking in orchestrator.** Prior phase summaries live on disk at `.prdx/state/{SLUG}/phases/*.md`. The developer agent reads only what it needs.

**For each phase in PHASES (sequentially):**

**Display progress:**
```
Phase {PHASE_NUM}/{TOTAL_PHASES}: {PHASE_NAME} ({PHASE_MODE})...
```

Invoke the developer agent using the Task tool with **path-based context**:

```
subagent_type: "prdx:developer"

prompt: "Implement Phase {PHASE_NUM}/{TOTAL_PHASES}: {PHASE_NAME}

Slug: {SLUG}
Platform hint: {PLATFORM_FROM_PRD}
Phase: {PHASE_NUM}
Phase name: {PHASE_NAME}
Phase mode: {PHASE_MODE}
INDEX: .prdx/state/{SLUG}/INDEX.md

## Where to read

- INDEX.md — manifest of all shards
- prd/acceptance.md — ACs your work must satisfy
- dev-plan/architecture.md — design context (read once)
- dev-plan/files.md — file inventory (read once)
- dev-plan/phases/{PHASE_NUM}-*.md — YOUR phase content (tasks, scope)
- phases/{PRIOR}.md — prior phase summaries, IF AND ONLY IF this is a sequential phase that depends on prior work. Skip otherwise.

Do NOT read prd/problem.md or prd/approach.md unless your phase explicitly needs the rationale.

## Phase execution rules

- {PHASE_MODE}: {'Tasks are independent — parallelize Edit/Write calls' if parallel, else 'Tasks depend on each other — sequence them'}
- Use TodoWrite to track tasks
- One atomic commit at the end of this phase

## Commit format (from prdx.json — overrides defaults)

{COMMIT_INSTRUCTIONS from Step 1b}

## Output

After committing, write your phase summary to disk:

  source \"\$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh\"
  cat <<EOF | shard_write {SLUG} phases/{PHASE_NUM}.md \"Phase {PHASE_NUM} summary\"
  ## Phase {PHASE_NUM} Summary

  ### Files Created
  - ...

  ### Files Modified
  - ...

  ### Tests Written
  - ...

  ### Commits
  - ...

  ### Test Results
  ...
  EOF

Return ONLY a one-line confirmation: 'Phase {PHASE_NUM} complete — N files, M commits, tests {pass|fail}'. Do NOT echo the summary back."
```

Wait for the platform agent to complete.

**After each phase completes:**
1. The summary is already on disk at `.prdx/state/{SLUG}/phases/{PHASE_NUM}.md` — orchestrator does NOT store it in memory.
2. Display brief phase result:
   ```
   Phase {PHASE_NUM}/{TOTAL}: {PHASE_NAME} — Done
   ```

**If a phase fails or returns an error:**

Use AskUserQuestion to offer recovery options:
- Option 1: "Retry this phase" — Re-invoke the platform agent for the same phase
- Option 2: "Skip to next phase" — Mark phase as skipped, continue with remaining phases
- Option 3: "Continue manually" — Stop automated implementation, let user take over (status stays `in-progress`)
- Option 4: "Stop implementation" — Halt workflow entirely

Route based on choice:
- Retry → Re-run current phase
- Skip → Write a skip marker to `.prdx/state/{SLUG}/phases/{N}.md` (one line: `## Phase {N} — SKIPPED`), continue loop
- Continue manually → Display what was accomplished so far, end workflow
- Stop → End workflow, show how to resume with `/prdx:implement {slug}`

**After all phases complete, continue to Step 5d.**

#### Step 5d: Platform Completion

After all phases complete:

1. **Store the implementation summary**
2. **Update PRD** with implementation notes:

```markdown
---
## Implementation Notes ({PLATFORM})

**Branch:** {BRANCH}
**Implemented:** {TODAY's DATE}

{IMPLEMENTATION_SUMMARY from agent}
```

3. **For child PRDs (has `**Parent:**` field):** Also update the child's state file:
   ```bash
   mkdir -p .prdx/state
   cat > .prdx/state/{SLUG}.json << EOF
   {"slug": "{SLUG}", "phase": "review", "lite": false, "parent": "{PARENT_SLUG}"}
   EOF
   ```
   (Only include the `"parent"` key if the PRD has a `**Parent:**` field.)

4. **Continue to Step 5e** (Code Review)

---

#### Step 5e: AC Verification + Code Review — Parallel First Pass

**Display progress:**
```
Phase 3/3: AC Verification + Code Review — Running in parallel...
```

After all platform implementations are complete, launch `prdx:ac-verifier` and `prdx:reviewer-orchestrator` **simultaneously** as a read-only first pass. Both agents read the same diff (`git diff {DEFAULT_BRANCH}..HEAD`) — there is no conflict.

Pre-compute diff LOC before dispatching:
```bash
DIFF_LOC=$(git diff {DEFAULT_BRANCH}..HEAD | grep -c '^[+-]' || echo 0)
```

**IMPORTANT: Make both Task tool calls in a single message (parallel execution):**

```
subagent_type: "prdx:ac-verifier"

prompt: "Verify the acceptance criteria for this PRD.

Slug: {SLUG}
Base Branch: {DEFAULT_BRANCH}
Platform: {PLATFORM}
INDEX: .prdx/state/{SLUG}/INDEX.md

Read ONLY .prdx/state/{SLUG}/prd/acceptance.md for the ACs. Do not read problem.md, approach.md, the dev plan, or phase summaries.

Check the diff (git diff {DEFAULT_BRANCH}..HEAD) against each AC. Three-point check: code exists, test exists, coverage (happy + error).

Write your verdict to disk:
  source \"\$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh\"
  cat <<EOF | shard_write {SLUG} reviews/ac-verdict.md \"AC verifier verdict (latest)\"
  ## AC Verdict
  ... (per-AC: MET | PARTIAL | NOT MET, with one-line reason)
  EOF

Return ONLY a one-line summary: 'AC verdict: X met, Y partial, Z not met'. Do NOT echo the verdict body."
```

```
subagent_type: "prdx:reviewer-orchestrator"

prompt: "Review the implementation for this PRD.

Slug: {SLUG}
Base Branch: {DEFAULT_BRANCH}
Platform: {PLATFORM}
Diff LOC: {DIFF_LOC}
INDEX: .prdx/state/{SLUG}/INDEX.md (read prd/acceptance.md only if context-dependent)

Review git diff {DEFAULT_BRANCH}..HEAD for bugs, security, quality, convention adherence.
Dispatch specialists as needed. Classify findings as AUTO-FIX or ASK. Apply AUTO-FIX silently.

Write findings to disk:
  source \"\$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh\"
  cat <<EOF | shard_write {SLUG} reviews/code-review.md \"Code review findings (latest)\"
  ## Findings
  ... (one block per finding: severity, file:line, ASK|AUTO-FIX, description)
  EOF

Return ONLY a one-line summary: 'Review: N ASK findings, M auto-fixed' plus the ASK list (≤10 lines). Do NOT echo the full findings."
```

Wait for both agents to complete, then route based on the combined result:

**Routing logic (four branches):**

1. **Both clean** → Skip directly to Step 6 (post-implement hook). This is the happy path — saves one full agent round-trip compared to the old sequential flow.

2. **AC fails, review clean** → Discard the reviewer's first-pass output (it may assume ACs are met — that assumption is now invalid). Run the AC fix loop (Step 5e-fix below — up to 3 attempts). After AC converges, re-run `prdx:reviewer-orchestrator` on the new diff. If review now fails, run the review fix loop (Step 5f-fix). If review clean, proceed to Step 6.

3. **AC clean, review fails** → Run the review fix loop directly (Step 5f-fix — up to 2 cycles). AC is already verified so do not re-run it. After fix loop, proceed to Step 6.

4. **Both fail** → Run AC fix loop first (correctness-first invariant — see `skills/fix-loop.md`). Discard the stale reviewer output. After AC converges, re-run `prdx:reviewer-orchestrator` on the new diff. If review then fails, run the review fix loop. Proceed to Step 6 when both are clean.

---

#### Step 5e-fix: AC Fix Loop (subroutine)

Invoked when ac-verifier reports one or more ACs NOT MET or Partial. Maximum 3 attempts. On exhaustion → AskUserQuestion (Proceed to code review / Fix manually / Stop).

See [skills/fix-loop.md](../skills/fix-loop.md) for the full loop specification.

Feed unmet/partial ACs back to the platform agent:

```
subagent_type: "prdx:developer"

prompt: "Fix unmet acceptance criteria.

Slug: {SLUG}
Mode: ac-fix
Attempt: {ATTEMPT_NUM}
INDEX: .prdx/state/{SLUG}/INDEX.md

Read these files:
- reviews/ac-verdict.md — see which ACs failed and why
- prd/acceptance.md — full AC list

Run these for live context:
- git diff {DEFAULT_BRANCH}..HEAD --name-only
- git log {DEFAULT_BRANCH}..HEAD --oneline

Fix each unmet/partial AC, write missing tests, run tests, commit.

{COMMIT_INSTRUCTIONS from Step 1b}

Write the fix summary to disk:
  source \"\$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh\"
  cat <<EOF | shard_write {SLUG} reviews/fixes/ac-{ATTEMPT_NUM}.md \"AC fix attempt {ATTEMPT_NUM}\"
  ## Fixes
  ...
  EOF

Return ONLY a one-line confirmation."
```

Re-run `prdx:ac-verifier` after each fix. Loop until all ACs are met or 3 attempts are exhausted.

---

#### Step 5f-fix: Code Review Fix Loop (subroutine)

Invoked when `prdx:reviewer-orchestrator` reports ASK findings that the user chose to fix. Maximum 2 cycles. On exhaustion → AskUserQuestion (Proceed anyway / Fix manually / Stop).

See [skills/fix-loop.md](../skills/fix-loop.md) for the full loop specification.

Feed only the ASK findings (user-approved for fixing) back to the platform agent:

```
subagent_type: "prdx:developer"

prompt: "Fix code review issues.

Slug: {SLUG}
Mode: review-fix
Cycle: {CYCLE_NUM}
INDEX: .prdx/state/{SLUG}/INDEX.md

User-approved ASK findings (the only ones to fix):
{ASK_FINDINGS — pass inline, max ≤15 lines; if longer, write to reviews/fixes/review-{CYCLE_NUM}-input.md first and reference the path}

Run for live context:
- git diff {DEFAULT_BRANCH}..HEAD --name-only
- git log {DEFAULT_BRANCH}..HEAD --oneline

Fix each issue, run tests, commit.

{COMMIT_INSTRUCTIONS from Step 1b}

Write the fix summary to disk:
  source \"\$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh\"
  cat <<EOF | shard_write {SLUG} reviews/fixes/review-{CYCLE_NUM}.md \"Review fix cycle {CYCLE_NUM}\"
  ## Fixes
  ...
  EOF

Return ONLY a one-line confirmation."
```

Pre-compute updated diff LOC, then re-run `prdx:reviewer-orchestrator` after each fix:

```
subagent_type: "prdx:reviewer-orchestrator"

prompt: "Re-review after fixes.

Slug: {SLUG}
Base Branch: {DEFAULT_BRANCH}
Platform: {PLATFORM}
Diff LOC: {UPDATED_DIFF_LOC}
INDEX: .prdx/state/{SLUG}/INDEX.md
Prior review: reviews/code-review.md (read to check if findings were resolved)

Review the updated diff. Apply AUTO-FIX silently. Overwrite reviews/code-review.md with the new findings (use shard_write). Return ONLY a one-line summary."
```

Loop until clean or 2 cycles exhausted.

**After fix loop completes (or if review was already clean):**
- Continue to Step 5g

---

### Step 5g: Auto-Simplify Changed Files

Once review is clean, run mechanical simplification on files changed in this branch. No re-review afterward — the rules are deterministic (comment removal, single-use inlining) and not expected to introduce review-worthy changes.

1. **Collect changed source files:**
   ```bash
   git diff --name-only {DEFAULT_BRANCH}..HEAD | grep -E '\.(kt|swift|ts|tsx|js|jsx|py|go|rb|java|rs)$' || true
   ```
   If the list is empty, skip to Step 6.

2. **Apply simplification rules from `commands/simplify.md`** to each changed file. For each file:
   - Read the file
   - Remove documentation-style comments (keep `// MARK:`, `// TODO:`, `// FIXME:`, why-comments, workaround explanations, legal headers, `@Suppress`/`@ts-expect-error` with explanations)
   - Inline single-use local variables when the expression is clear
   - Inline single-use private functions when simple
   - Do NOT change behavior, refactor architecture, or touch unchanged files

3. **Commit if anything changed:**
   ```bash
   if ! git diff --quiet; then
     git add -A
     git commit -m "$(cat <<'EOF'
   refactor: simplify changed files post-review

   $COMMIT_TRAILERS
   EOF
   )"
   fi
   ```
   Use the same `COMMIT_INSTRUCTIONS` trailers built in Step 1b. If nothing was simplified, skip the commit silently.

4. **Continue to Step 6.**

---

### Step 6: Post-Implement Hook and Status Update

1. **Run the post-implement hook** (handles test verification and status update):
   ```bash
   if [ -f hooks/prdx/post-implement.sh ]; then
     ./hooks/prdx/post-implement.sh "{slug}"
   fi
   ```

2. **Fallback status update** (only if hook doesn't exist):
   If the hook file doesn't exist, update status directly:
   Edit the PRD file to change `**Status:** in-progress` to `**Status:** review`

   The hook is the single owner of status updates. The command only updates status as a fallback when the hook is absent.

3. **Write state file** (after hook runs or fallback status update):
   ```bash
   mkdir -p .prdx/state
   # Write state file (include parent key only for child PRDs)
   cat > .prdx/state/{SLUG}.json << EOF
   {"slug": "{SLUG}", "phase": "review", "lite": false}
   EOF
   ```
   For child PRDs (has `**Parent:**` field), include the parent key:
   ```bash
   mkdir -p .prdx/state
   cat > .prdx/state/{SLUG}.json << EOF
   {"slug": "{SLUG}", "phase": "review", "lite": false, "parent": "{PARENT_SLUG}"}
   EOF
   ```

### Step 7: Display Completion

**For single-platform PRDs:**
```
✅ Implementation Complete!

📄 PRD: {PRD_FILE}
🌿 Branch: {BRANCH}
📋 Status: review
✅ Tests: All passing

Next steps:
1. Test the implementation
2. If bugs found: describe them and I'll fix them
3. When ready: /prdx:push {slug}
```

**For child PRDs (has `**Parent:**` field):**
```
✅ Implementation Complete! ({PLATFORM})

📄 PRD: {PRD_FILE}
👆 Parent: {PARENT_SLUG}
🌿 Branch: {BRANCH}
📋 Status: review

Check sibling progress: /prdx:show {parent-slug}
When all children are done: /prdx:push {parent-slug}
```

---

### Step 8: Update Existing Draft PR (if any)

After Step 6, check if a draft PR exists on the branch:

```bash
BRANCH=$(git branch --show-current)
PR_NUMBER=$(gh pr list --head "$BRANCH" --state open --json number,isDraft --jq '.[] | select(.isDraft) | .number' 2>/dev/null)
```

If found, push commits (`git push origin "$BRANCH"`) and invoke `prdx:pr-author` with `Mode: prd`, `PR Number: {PR_NUMBER}`, `PRD File: {PRD_FILE}`, `Branch: {BRANCH}`, `Base Branch: {DEFAULT_BRANCH}`. The agent updates via `gh pr edit`. Display: `PR #{PR_NUMBER} updated with implementation details.`

## Errors

- **No slug** → list PRDs from `{PLANS_DIR}/`.
- **PRD not found** → list available slugs.
- **Pre-implement hook fails** → show hook output and stop.
