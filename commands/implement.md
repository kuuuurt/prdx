---
description: "Implement feature by delegating to platform-specific agent"
argument-hint: "[slug]"
---

## Pre-Computed Context

```bash
echo "=== Git Context ==="
echo "Branch: $(git branch --show-current)"
echo "Default: $(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')"
git status --short
echo ""
echo "=== Config ==="
# Walk up to find prdx.json
DIR="$PWD"; while [ "$DIR" != "/" ]; do
  [ -f "$DIR/prdx.json" ] && echo "Config: $DIR/prdx.json" && break
  [ -f "$DIR/.prdx/prdx.json" ] && echo "Config: $DIR/.prdx/prdx.json" && break
  DIR=$(dirname "$DIR")
done
[ "$DIR" = "/" ] && echo "Config: (defaults)"
echo ""
echo "=== Plans Directory ==="
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PLANS_DIR="$PROJECT_ROOT/.prdx/plans"
echo "Plans directory: $PLANS_DIR"
echo ""
echo "=== Available PRDs (this project) ==="
PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
grep -rl "^\*\*Project:\*\* $PROJECT_NAME" "$PLANS_DIR"/*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^prdx-//' || echo "No PRDs found"
```

# /prdx:implement - Implement Feature

Three-phase implementation: **Dev Planning** (prdx:dev-planner) → **Development** (Platform agent) → **Code Review** (prdx:code-reviewer)

Both agents run in **isolated contexts** to minimize main conversation context usage.

**PRDs are read from `{PLANS_DIR}/`** (created by native plan mode).

**For PRDs with multiple platforms:** Implementation runs per the PRD's `**Implementation Order:**`.

## Usage

```bash
/prdx:implement backend-auth                    # Single-platform PRD
/prdx:implement biometric-auth                  # Parent PRD → shows child instructions
/prdx:implement biometric-auth-backend          # Child PRD → runs implementation
/prdx:implement biometric-auth-android          # Child PRD → checks prerequisites, runs implementation
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

**Phase C: Code Review (prdx:code-reviewer)**
- Runs in isolated context
- Reviews diff against acceptance criteria
- Flags bugs, security issues, unmet criteria
- If issues found: platform agent fixes, then re-review (max 2 cycles)
- Returns only review summary (~2KB)

**For Multi-Platform PRDs (parent-child model):**
- Parent PRDs delegate to child PRDs (Step 2b) — they are never directly implemented
- Each child PRD runs the full Phase A + B + C pipeline independently
- Child sessions check sibling prerequisites via `.prdx/state/` files (Step 2c)
- Children on the same Implementation Order step can run in parallel sessions (separate branches)

## Workflow

### Step 1: Load Configuration

**IMPORTANT: You must read and parse the project's prdx.json configuration.**

1. **Walk up the directory tree** to find the config file (supports monorepo/meta-project layouts):
   - Starting from the current working directory, check each directory going up:
     - `{dir}/prdx.json`
     - `{dir}/.prdx/prdx.json`
   - Stop at the first match or at filesystem root
   - This ensures config is found even when working inside a sub-project of a meta-project

2. If config file exists, extract these values:
   - `commits.format` → "conventional" or "simple"
   - `commits.coAuthor.enabled` → true/false
   - `commits.coAuthor.name` → name string
   - `commits.coAuthor.email` → email string
   - `commits.extendedDescription.enabled` → true/false
   - `commits.extendedDescription.includeClaudeCodeLink` → true/false

3. If no config file exists, use these defaults:
   - format: "conventional"
   - coAuthor.enabled: true
   - coAuthor.name: "Claude"
   - coAuthor.email: "noreply@anthropic.com"
   - extendedDescription.enabled: true
   - includeClaudeCodeLink: true

**Store these values - you will need them when invoking the platform agent.**

#### Step 1a: Validate Configuration

**If a config file was found, validate it:**

1. **Check for malformed JSON:**
   If the file cannot be parsed as valid JSON, display a warning and use defaults:
   ```
   ⚠️  prdx.json contains invalid JSON. Using default configuration.

   Fix: Check prdx.json syntax (missing commas, trailing commas, etc.)
   ```

2. **Check for unrecognized values:**
   - If `commits.format` is not "conventional" or "simple":
     ```
     ⚠️  Unrecognized commit format: "{value}". Expected: "conventional" or "simple". Using "conventional".
     ```
   - If unknown top-level keys exist, warn but continue:
     ```
     ⚠️  Unrecognized config key: "{key}". Ignoring.
     ```

3. **Display loaded config summary:**
   ```
   Config loaded:
     Format: conventional | Co-author: Claude <noreply@anthropic.com> | Extended: yes | Claude Code link: yes
   ```

#### Step 1b: Build Commit Instructions

**Build commit instructions immediately after config loading.** These are purely config-derived and don't depend on the PRD or dev plan, so computing them once here avoids repeating work in the per-platform loop.

**CRITICAL: Build these instructions based on the config values from Step 1.**

Build a commit instructions string with this structure:

```
6. **Commits:**
   - Keep commits atomic and focused
   - ALWAYS use HEREDOC format for commits:

   ```bash
   git commit -m "$(cat <<'EOF'
   {your commit message}
   EOF
   )"
   ```

   **Commit Message Structure:**
```

Then add based on config:

**If format is "conventional":**
```
   - Line 1: {type}: {short description}
   - Types: feat, fix, refactor, test, chore, docs
```

**If format is "simple":**
```
   - Line 1: {short description} (no type prefix)
```

**If extendedDescription.enabled is true:**
```
   - Line 2: Empty line
   - Lines 3+: Extended description explaining WHAT changed and WHY
```

**If extendedDescription.enabled is FALSE:**
```
   - DO NOT add any extended description
   - The subject line is the ENTIRE commit message (except for optional trailers)
   - There should be NO blank line followed by explanation text
```

**If includeClaudeCodeLink is true:**
```
   - Empty line
   - 🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**If coAuthor.enabled is true:**
```
   - Empty line
   - Co-Authored-By: {coAuthor.name} <{coAuthor.email}>
```

**If `GIT_AUTHOR_NAME` env var is set** (CI mode with `--requested-by`):
The commit author is already the requestor via exported env vars. Override co-author config to always include both Claude Code and GitHub Actions:
```
   - Co-Authored-By: Claude Code <noreply@anthropic.com>
   - Co-Authored-By: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>
```
This replaces the normal `coAuthor` config — in CI mode, the requestor is the author and Claude Code + GitHub Actions are always co-authors. The `includeClaudeCodeLink` and `extendedDescription` settings from prdx.json config are still respected.

**Add an example commit** showing the exact format based on config.

**Example with all options ENABLED (conventional format):**

```
   **Example commit (FOLLOW THIS FORMAT EXACTLY):**

   ```bash
   git commit -m "$(cat <<'EOF'
   feat: add user authentication

   Implement JWT-based authentication with login and refresh endpoints.
   Includes middleware for protected routes.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```
```

**Example with extendedDescription DISABLED (conventional format):**

```
   **Example commit (FOLLOW THIS FORMAT EXACTLY):**

   ```bash
   git commit -m "$(cat <<'EOF'
   feat: add user authentication
   EOF
   )"
   ```

   NOTE: When extendedDescription is disabled, the commit is ONLY the subject line.
   Do NOT add any description paragraph.
```

**Example with extendedDescription DISABLED but coAuthor ENABLED:**

```
   **Example commit (FOLLOW THIS FORMAT EXACTLY):**

   ```bash
   git commit -m "$(cat <<'EOF'
   feat: add user authentication

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

   NOTE: Only trailers (Co-Authored-By) appear, NO description paragraph.
```

**Store the result as `COMMIT_INSTRUCTIONS`.** This will be passed to all platform agent invocations.

### Step 2: Load PRD

**Resolve slug to PRD file using enhanced matching:**

1. **Exact match (prefixed):** `{PLANS_DIR}/prdx-{slug}.md`
2. **Exact match (unprefixed fallback):** `{PLANS_DIR}/{slug}.md` — for plans created without the `prdx-` prefix
3. **Substring match:** `ls {PLANS_DIR}/prdx-*{slug}*.md` — slug appears anywhere in prefixed filenames
4. **Substring match (unprefixed fallback):** `ls {PLANS_DIR}/*{slug}*.md` — search all plans if no prefixed match
5. **Word-boundary match:** Split slug into words, find PRDs containing all words (in any order)
6. **Disambiguation:** If multiple matches at any step, use AskUserQuestion to let user select:
   ```
   Multiple PRDs match "{slug}":
     1. backend-auth
     2. backend-auth-refresh
   Which one?
   ```
   If exactly one match at any step, use it.

7. If no match found at any step, show error and list available PRDs

**Auto-rename unprefixed plans:** If a match is found without the `prdx-` prefix, rename it to add the prefix before proceeding:
```bash
mv {PLANS_DIR}/{old-name}.md {PLANS_DIR}/prdx-{slug}.md
```
Inform the user: `Renamed plan to follow PRDX naming convention: prdx-{slug}.md`

3. Read the PRD file and extract:
   - **Platform** (single-platform PRDs: backend/frontend/android/ios)
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
{"slug": "{SLUG}", "phase": "in-progress", "quick": false, "parent": "{PARENT_SLUG}"}
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

**Display progress:**
```
Phase 1/4: Dev Planning — Creating implementation plan...
```

Invoke the dev-planner agent using the Task tool:

```
subagent_type: "prdx:dev-planner"

prompt: "Create a detailed implementation plan for this PRD.

PRD File: {PRD_FILE}
Platform: {PLATFORM}  (e.g., 'android' or 'ios')

{PRD_CONTENT}

Read the skills files and explore the codebase to create a comprehensive dev plan.
Use phased task groups (### Implementation Phases) with <!-- parallel: true --> or <!-- sequential --> annotations.
Return only the dev plan document."
```

Wait for the agent to return the dev plan. Store it for the next phase.

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

Parse the dev plan from Step 5a into individual phases for phase-by-phase execution.

**Three-layer fallback parsing:**

1. **Phase-summary JSON** (preferred): Look for `<!-- phase-summary [...] -->` in the dev plan. Extract the JSON array:
   ```
   <!-- phase-summary
   [
     {"phase": 1, "name": "Foundation", "mode": "parallel", "tasks": ["Task A", "Task B"]},
     {"phase": 2, "name": "Core Logic", "mode": "sequential", "tasks": ["Task C", "Task D"]}
   ]
   -->
   ```
   Parse this JSON into a `PHASES` array. If JSON is malformed, fall through to layer 2.

2. **Header regex** (fallback): Scan for `#### Phase N: [Name]` headers followed by `<!-- parallel: true -->` or `<!-- sequential -->` annotations. Extract phase number, name, mode, and task list (lines starting with `- [ ]`).

3. **Single phase** (final fallback): If neither parsing method finds phases, wrap the entire dev plan as a single sequential phase:
   ```
   PHASES = [{"phase": 1, "name": "Full Implementation", "mode": "sequential", "tasks": ["Execute entire dev plan"]}]
   ```

For each parsed phase, also extract the **full phase content** from the dev plan (everything between one `#### Phase N:` header and the next, or end of `### Implementation Phases` section). This full content is passed to the platform agent.

Store the result as `PHASES` array and `PHASE_CONTENTS` map (phase number → full markdown content).

**Display parsing result:**
```
Parsed dev plan: {N} phases ({list of "Phase N: Name (mode)" entries})
```

#### Step 5c: Phased Execution Loop

Determine agent based on platform:
- backend → `prdx:backend-developer`
- frontend → `prdx:frontend-developer`
- android → `prdx:android-developer`
- ios → `prdx:ios-developer`

Initialize `COMPLETED_PHASES` as an empty list (stores summaries from each completed phase).

**For each phase in PHASES (sequentially):**

**Display progress:**
```
Phase {PHASE_NUM}/{TOTAL_PHASES}: {PHASE_NAME} ({PHASE_MODE})...
```

Invoke the platform agent using the Task tool with **phase-scoped context**:

```
subagent_type: "{AGENT}"

prompt: "Implement Phase {PHASE_NUM}/{TOTAL_PHASES}: {PHASE_NAME}

## PRD (for reference)

**Title:** {PRD_TITLE}
**Acceptance Criteria:**
{ACCEPTANCE_CRITERIA from PRD}

## Full Dev Plan (for reference)

{FULL_DEV_PLAN from Step 5a}

## Completed Phases

{COMPLETED_PHASES summaries — or 'None (this is the first phase)' if empty}

## YOUR PHASE — Phase {PHASE_NUM}: {PHASE_NAME}

**Mode: {PHASE_MODE}**

{PHASE_CONTENT — full markdown content for this phase from PHASE_CONTENTS}

**Phase execution rules:**
- This is a {PHASE_MODE} phase
- {'PARALLEL: Tasks are independent. Use parallel tool calls — make multiple Edit/Write calls in a single response for different files.' if mode is 'parallel'}
- {'SEQUENTIAL: Tasks depend on each other. Complete each task fully before starting the next.' if mode is 'sequential'}
- Use TodoWrite to track tasks — mark in_progress when starting, completed when done
- Commit your work at the end of this phase (one atomic commit per phase)

**CRITICAL - COMMIT FORMAT:**

You MUST follow the commit configuration below. This is from the project's prdx.json and OVERRIDES any defaults.

{COMMIT_INSTRUCTIONS from Step 1b}

**Implementation Instructions:**

1. **Execute only YOUR PHASE tasks** — do not work ahead to future phases
2. **Test-Driven Development:** Write tests FIRST, ensure they fail, then implement
3. **Follow Platform Patterns:** Read `.claude/skills/impl-patterns.md` for {PLATFORM} patterns
4. **Testing Strategy:** Reference `.claude/skills/testing-strategy.md`
5. **Verification:** Run tests after implementation, ensure your phase's tasks pass
6. **Commit:** Create one atomic commit for this phase's work

**Return only a summary:**

## Phase {PHASE_NUM} Summary

### Files Created
- [List new files]

### Files Modified
- [List modified files]

### Tests Written
- [List test files]

### Commits
- [List commit messages]

### Test Results
[Pass/fail summary]
"
```

Wait for the platform agent to complete.

**After each phase completes:**
1. Store the agent's response in `COMPLETED_PHASES` (append phase number, name, and summary)
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
- Skip → Add skip note to COMPLETED_PHASES, continue loop
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
   {"slug": "{SLUG}", "phase": "review", "quick": false, "parent": "{PARENT_SLUG}"}
   EOF
   ```
   (Only include the `"parent"` key if the PRD has a `**Parent:**` field.)

4. **Continue to Step 5e** (Code Review)

---

#### Step 5e: AC Verification (prdx:ac-verifier)

**Display progress:**
```
Phase 3/3: AC Verification — Checking acceptance criteria...
```

After all platform implementations are complete, verify that acceptance criteria are met before code review.

Invoke the ac-verifier agent using the Task tool:

```
subagent_type: "prdx:ac-verifier"

prompt: "Verify the acceptance criteria for this PRD.

PRD Slug: {SLUG}
Base Branch: {DEFAULT_BRANCH}
Platform: {PLATFORM}

Acceptance Criteria:
{ACCEPTANCE_CRITERIA from PRD}

Check the diff (git diff {DEFAULT_BRANCH}..HEAD) against each acceptance criterion.
Perform the three-point check: code exists, test exists, coverage (happy + error).

Return only the AC verification summary."
```

**If any AC is NOT MET or Partial:**
1. Display the AC verification summary to the conversation
2. Feed the unmet/partial ACs back to the platform agent for fixing:

```
subagent_type: "{PLATFORM_AGENT}"

prompt: "Fix the following unmet acceptance criteria.

## AC Issues

{UNMET_AND_PARTIAL_ACS from ac-verifier output}

## Context

**Changed files:**
{OUTPUT of: git diff {DEFAULT_BRANCH}..HEAD --name-only}

**Recent commits:**
{OUTPUT of: git log {DEFAULT_BRANCH}..HEAD --oneline}

**Full Acceptance Criteria (from PRD):**
{ACCEPTANCE_CRITERIA from PRD}

## Instructions

1. Fix each unmet/partial AC listed above
2. Write missing tests where indicated
3. Run tests to verify fixes
4. Commit the fixes using the commit format below

{COMMIT_INSTRUCTIONS from Step 1b}

Return only a summary of fixes applied."
```

3. After fixes, re-run the ac-verifier to confirm
4. If ACs still unmet, loop back: platform agent fixes → ac-verifier re-checks
5. Continue looping until all ACs are verified or 3 attempts are exhausted

**If all ACs verified (at any attempt):**
- Continue to Step 5f

**If ACs still unmet after 3 fix attempts:**

Use AskUserQuestion to offer options:
- Option 1: "Proceed to code review" (Recommended) — Continue with remaining AC gaps noted
- Option 2: "Fix manually" — Stop here, let user fix AC issues (status stays `in-progress`)
- Option 3: "Stop implementation" — Halt workflow entirely

Route based on choice:
- Proceed → Continue to Step 5f, include unmet ACs in completion summary
- Fix manually → Display unmet ACs, end workflow
- Stop → End workflow, show how to resume with `/prdx:prdx {slug}`

---

#### Step 5f: Code Review (prdx:code-reviewer)

**Display progress:**
```
Code Review — Reviewing for bugs, security, and quality...
```

Run code review focused on bugs, security, quality, and conventions (AC verification already done in Step 5e).

Invoke the code-reviewer agent using the Task tool:

```
subagent_type: "prdx:code-reviewer"

prompt: "Review the implementation for this PRD.

PRD Slug: {SLUG}
Base Branch: {DEFAULT_BRANCH}
Platform: {PLATFORM}

Review the diff (git diff {DEFAULT_BRANCH}..HEAD) for bugs, security issues, quality problems, and convention adherence.
Only report high-confidence issues (>80%).

Return only the review summary."
```

**If issues found:**
1. Display the review summary to the conversation
2. Feed each issue back to the platform agent for fixing:

```
subagent_type: "{PLATFORM_AGENT}"

prompt: "Fix the following code review issues.

## Review Issues

{REVIEW_ISSUES}

## Context

**Changed files:**
{OUTPUT of: git diff {DEFAULT_BRANCH}..HEAD --name-only}

**Recent commits:**
{OUTPUT of: git log {DEFAULT_BRANCH}..HEAD --oneline}

## Instructions

1. Fix each issue listed above
2. Run tests to verify fixes
3. Commit the fixes using the commit format below

{COMMIT_INSTRUCTIONS from Step 1b}

Return only a summary of fixes applied."
```

3. After fixes, re-run the code reviewer to verify (max 2 review cycles to avoid loops)

**If 2 review cycles exhausted and issues remain:**

Use AskUserQuestion to offer options:
- Option 1: "Proceed anyway" (Recommended) — Continue to Step 6 with remaining issues noted
- Option 2: "Fix manually" — Stop here, let user fix remaining issues (status stays `in-progress`)
- Option 3: "Stop implementation" — Halt workflow entirely

Route based on choice:
- Proceed → Continue to Step 6, include remaining issues in completion summary
- Fix manually → Display remaining issues, end workflow
- Stop → End workflow, show how to resume with `/prdx:prdx {slug}`

**If no issues found (or after fixes verified):**
- Continue to Step 6

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
   {"slug": "{SLUG}", "phase": "review", "quick": false}
   EOF
   ```
   For child PRDs (has `**Parent:**` field), include the parent key:
   ```bash
   mkdir -p .prdx/state
   cat > .prdx/state/{SLUG}.json << EOF
   {"slug": "{SLUG}", "phase": "review", "quick": false, "parent": "{PARENT_SLUG}"}
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

## Error Handling

### No Slug Provided

```
❌ No PRD slug provided

Usage: /prdx:implement <slug>

Available PRDs:
{List PRDs from {PLANS_DIR}/}
```

### PRD Not Found

```
❌ PRD not found: {slug}

Available PRDs:
{List PRDs}
```

### Hook Failed

```
❌ Pre-implement validation failed

{Hook error output}

Fix the issues and try again.
```

---

## Platform Agents

| Platform | Agent | Specialization |
|----------|-------|----------------|
| backend | prdx:backend-developer | APIs, services, validation (discovers framework from codebase) |
| frontend | prdx:frontend-developer | Components, state, data fetching (discovers framework from codebase) |
| android | prdx:android-developer | Kotlin, Compose, MVVM (discovers DI/persistence from codebase) |
| ios | prdx:ios-developer | Swift, SwiftUI, MVVM (discovers dependencies from codebase) |

---

## Post-Implementation: Update Existing Draft PR

**After all implementation steps complete**, check if a draft PR already exists for this branch:

```bash
BRANCH=$(git branch --show-current)
PR_NUMBER=$(gh pr list --head "$BRANCH" --state open --json number,isDraft --jq '.[] | select(.isDraft) | .number' 2>/dev/null)
```

**If a draft PR exists:**

1. Push implementation commits:
   ```bash
   git push origin "$BRANCH"
   ```

2. Detect default branch:
   ```bash
   DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
   ```

3. Invoke `prdx:pr-author` agent to update PR body:
   ```
   subagent_type: "prdx:pr-author"

   prompt: "Update the PR body for a completed implementation.

   Mode: prd
   PR Number: {PR_NUMBER}
   PRD Slug: {SLUG}
   PRD File: {PLANS_DIR}/prdx-{SLUG}.md
   Branch: {BRANCH}
   Base Branch: {DEFAULT_BRANCH}

   Read the PRD (now including Implementation Notes), analyze commits, and update the PR title and body.
   Use gh pr edit to update the existing PR.
   The footer should say: 'Comment `@claude review` for code review.'

   Return confirmation of the update."
   ```

4. Display: `PR #{PR_NUMBER} updated with implementation details.`

**If no draft PR exists:** Skip this step entirely.

---

## Key Points

1. **PRDs from native plan mode** - Read from `{PLANS_DIR}/`
2. **Status tracking via file edit** - Update `**Status:**` field directly
3. **Always read prdx.json first** - Config determines commit format
4. **Build commit instructions dynamically** - Based on actual config values
5. **Pass commit instructions to agent** - Include in the prompt
6. **Agents run isolated** - They don't have access to main conversation context
7. **Return summaries only** - File contents stay in agent context
8. **Multi-platform uses parent-child model** - Parent delegates to child PRDs in separate sessions
9. **Child PRDs check prerequisites** - Read sibling state files before starting
10. **Code review before handoff** - prdx:code-reviewer runs after implementation, fixes issues automatically (max 2 cycles)
11. **Draft PR auto-update** - If a draft PR exists on the branch, pushes and updates its body after implementation
