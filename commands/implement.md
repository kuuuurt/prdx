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

This command orchestrates agents in **isolated contexts** using **disk-based handoff**: every agent prompt passes paths into `.prdx/state/{slug}/`, and agents read only the shards they need. The full Step 5 loop spec lives in `skills/prdx-implement-loop.md` and is only loaded when the loop actually runs (parent PRDs that stop at Step 2b never load it).

**Phase A: Dev Planning** (`prdx:dev-planner`) — reads `prd/*` shards, writes `dev-plan/*` shards, returns ≤10-line summary.

**Phase B: Development** (`prdx:developer`, once per phase) — reads `dev-plan/phases/N-*.md` for its phase and `phases/{N-1}.md` only if sequentially dependent. Writes `phases/N.md`. Returns a one-line confirmation.

**Phase C: AC Verification + Code Review** (`prdx:ac-verifier` + `prdx:reviewer-orchestrator`, in parallel) — ac-verifier reads only `prd/acceptance.md`; reviewer reads `git diff`. Both write to `reviews/*.md`. Each returns ≤10 lines.

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

### Step 5: Platform Implementation Loop

Handles a **single platform** — the one from the PRD's `**Platform:**` field. Multi-platform features are handled via parent-child PRDs: each child runs through this step in its own session.

**Execute the loop spec in [skills/prdx-implement-loop.md](../skills/prdx-implement-loop.md).** The skill contains Steps 5a–5g (dev planning, phased execution, AC verification + code review, fix loops, auto-simplify). Pass these variables to it:

- `SLUG`, `PLATFORM`, `PLATFORM_FROM_PRD`, `LITE_MODE`
- `DEFAULT_BRANCH`, `BRANCH`, `PRD_FILE`
- `NO_CACHE`
- `COMMIT_INSTRUCTIONS` (from Step 1b)

When the skill returns control (after Step 5g), proceed to Step 6 below.

The full body of Step 5 is deliberately not inlined here — for parent PRDs (which stop at Step 2b), the loop spec never enters context.

<details>
<summary>Inlined fallback (if the skill file is missing)</summary>

If `skills/prdx-implement-loop.md` is absent for any reason, the legacy inlined body lives in git history at `commands/implement.md` before the split commit. Restore from there.

</details>

---

<!-- Steps 5a–5g moved to skills/prdx-implement-loop.md -->

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
