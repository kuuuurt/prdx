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
echo "=== Available PRDs ==="
ls -1 ~/.claude/plans/prdx-*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^prdx-//' || echo "No PRDs found"
```

# /prdx:implement - Implement Feature

Three-phase implementation: **Dev Planning** (prdx:dev-planner) → **Development** (Platform agent) → **Code Review** (prdx:code-reviewer)

Both agents run in **isolated contexts** to minimize main conversation context usage.

**PRDs are read from `~/.claude/plans/`** (created by native plan mode).

**For PRDs with multiple platforms:** Implementation runs per the PRD's `**Implementation Order:**`.

## Usage

```bash
/prdx:implement backend-auth
/prdx:implement android-biometric-login
/prdx:implement ios-profile-screen
/prdx:implement fullstack-auth                  # Follows Implementation Order from PRD
/prdx:implement fullstack-auth backend          # Implement backend only
/prdx:implement fullstack-auth android          # Implement Android only
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

**For Multi-Platform PRDs:**
- Follows `**Implementation Order:**` from PRD (e.g., backend first, then mobile platforms)
- Runs Phase A + B for each platform sequentially
- Learns from implementation, commits, and updates PRD
- Each subsequent platform benefits from lessons learned

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

1. **Exact match (prefixed):** `~/.claude/plans/prdx-{slug}.md`
2. **Exact match (unprefixed fallback):** `~/.claude/plans/{slug}.md` — for plans created without the `prdx-` prefix
3. **Substring match:** `ls ~/.claude/plans/prdx-*{slug}*.md` — slug appears anywhere in prefixed filenames
4. **Substring match (unprefixed fallback):** `ls ~/.claude/plans/*{slug}*.md` — search all plans if no prefixed match
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
mv ~/.claude/plans/{old-name}.md ~/.claude/plans/prdx-{slug}.md
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
- If PRD contains `**Parent:**` field → it is a **child PRD**. Continue with normal flow (Steps 3-7) using the child PRD's single platform.
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

5. **Save last-used slug** for context persistence:
   ```bash
   mkdir -p .prdx && echo "{SLUG}" > .prdx/last-slug
   ```

### Step 2b: Parent PRD Handling

**This step runs only when the loaded PRD is a parent PRD (contains `## Children` section).**

Parent PRDs are NOT directly implemented. They orchestrate child PRD implementations across sessions.

1. **Parse children:** Read the `## Children` section to get child slugs and platforms.

2. **Check child state files:** For each child, read `.prdx/state/{child-slug}.json` if it exists. If no state file exists, status is `planning`.

3. **Parse Implementation Order** from the parent PRD to understand which children should be implemented first.

4. **Display progress table:**
   ```
   Parent PRD: {PARENT_SLUG}
   Branch: {BRANCH}
   Implementation Order: {ORDER_SUMMARY}

   | Child PRD | Platform | Status |
   |-----------|----------|--------|
   | {child-slug-1} | backend | in-progress |
   | {child-slug-2} | android | planning |
   ```

5. **Check for missing child PRD files:** For each child slug listed in `## Children`, verify the PRD file exists at `~/.claude/plans/prdx-{child-slug}.md`. If any are missing:
   ```
   Warning: Child PRD file not found: prdx-{child-slug}.md
   Re-run /prdx:plan to regenerate, or create manually.
   ```

6. **Display session instructions:**

   Determine which children are ready to implement (status is `planning` or their prerequisites in Implementation Order are met):

   ```
   To implement this feature, run each child PRD in a separate Claude session:

   Step 1 (run first):
     /prdx:implement {child-slug-backend}

   Step 2 (run after step 1 completes):
     /prdx:implement {child-slug-android}
     /prdx:implement {child-slug-ios}

   Each session runs independently with focused context.
   Check progress anytime: /prdx:show {parent-slug}
   ```

7. **Derive and display parent status:**

   Read all child state files and compute parent status using the ordering:
   `planning < in-progress < review < implemented < completed`

   Parent status = minimum status across all children.

   Display: `Overall status: {derived-status}`

8. **STOP here.** Do NOT proceed to Steps 3-7. The parent PRD delegates all implementation to child sessions.

---

### Step 2a: Determine Target Platform(s)

**Parse the command arguments:**
- `{slug}` only → Use PRD's platform(s)
- `{slug} {platform}` → Override to that platform only (e.g., `{slug} backend`, `{slug} android`, `{slug} ios`)

**For multi-platform PRDs:**

1. Check if PRD has `**Platforms:**` field with multiple platforms (e.g., "backend, android, ios")
2. Parse the `Platforms` field into a list: `TARGET_PLATFORMS`
3. If `**Implementation Order:**` exists, parse into `IMPLEMENTATION_STEPS` (ordered list of platform groups)
4. If second argument provided (e.g., "backend"), filter to just that platform
5. If no Implementation Order, treat all platforms as one step (implement in listed order)

**Determine implementation order:**
- Use `IMPLEMENTATION_STEPS` from PRD (e.g., step 1: ["backend"], step 2: ["android", "ios"])
- Platforms within a step are independent but still implemented one at a time
- Steps execute sequentially

**For single-platform PRDs:**
- Set `TARGET_PLATFORMS` = ["{PLATFORM}"]

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

**For each step in IMPLEMENTATION_STEPS (following Implementation Order):**

If the current step has **one platform**: Run Steps 5a-5d sequentially for that platform.

If the current step has **multiple platforms** (e.g., `2. android, ios`): These platforms are **independent** and should run in **parallel**:

1. Launch dev-planner agents for ALL platforms in this step **concurrently** (multiple Agent tool calls in a single message)
2. Once all dev-planners return, launch platform agents for ALL platforms **concurrently** (parse phases and execute per platform)
3. Wait for ALL platform agents to complete
4. Collect summaries from all platforms, then continue to next step

**Parallel platform rules:**
- Platforms within the same step CANNOT share `PREVIOUS_PLATFORM_NOTES` (they run concurrently)
- Each platform gets its own dev-planner, phase execution loop, and phase summaries
- If one platform fails, the other continues — failure is handled per-platform
- After all parallel platforms complete, their combined summaries become `PREVIOUS_PLATFORM_NOTES` for the next step

**For single-platform PRDs:** Set `IMPLEMENTATION_STEPS` = [["{PLATFORM}"]] (one step, one platform).

**For multi-platform PRDs (sequential steps):**
- First step: Full implementation from scratch
- Subsequent steps: Benefit from lessons learned via `PREVIOUS_PLATFORM_NOTES`

---

#### Step 5a: Dev Planning (prdx:dev-planner)

**Display progress:**
```
Phase 1/3: Dev Planning — Creating implementation plan...
```

Invoke the dev-planner agent using the Task tool:

```
subagent_type: "prdx:dev-planner"

prompt: "Create a detailed implementation plan for this PRD.

PRD File: {PRD_FILE}
Platform: {CURRENT_PLATFORM}  (e.g., 'android' or 'ios')

{PRD_CONTENT}

{PREVIOUS_PLATFORM_NOTES}  (if this is the second platform)

Read the skills files and explore the codebase to create a comprehensive dev plan.
Use phased task groups (### Implementation Phases) with <!-- parallel: true --> or <!-- sequential --> annotations.
Return only the dev plan document."
```

**For subsequent platforms in a multi-platform PRD:**
Include `PREVIOUS_PLATFORM_NOTES` with:
- Summary of previously completed platform(s) implementation
- Key patterns established
- Any issues encountered and solutions
- Recommendations for this platform

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

Determine agent based on current platform:
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

After each platform completes:

1. **Store the implementation summary** for this platform
2. **Update PRD** with platform-specific implementation notes:

```markdown
---
## Implementation Notes ({CURRENT_PLATFORM})

**Branch:** {BRANCH}
**Implemented:** {TODAY's DATE}

{IMPLEMENTATION_SUMMARY from agent}
```

3. **For child PRDs (has `**Parent:**` field):** Also update the child's state file after writing implementation notes:
   ```bash
   mkdir -p .prdx/state
   cat > .prdx/state/{SLUG}.json << EOF
   {"slug": "{SLUG}", "phase": "review", "quick": false, "parent": "{PARENT_SLUG}"}
   EOF
   ```
   (Only include the `"parent"` key if the PRD has a `**Parent:**` field.)

4. **For multi-platform PRDs with remaining platforms:**
   - Display completion for current platform:
     ```
     ✅ {CURRENT_PLATFORM} implementation complete! ({completed_count}/{total_platforms})

     Moving to {NEXT_PLATFORM}...
     ```
   - Store learnings as `PREVIOUS_PLATFORM_NOTES`:
     - What patterns were established in completed platform(s)
     - What worked well
     - What could be improved for the next platform
   - **Loop back to Step 5a** for the next platform (following Implementation Order)

5. **When all platforms are done:**
   - Continue to Step 5e (Code Review)

---

#### Step 5e: Code Review (prdx:code-reviewer)

**Display progress:**
```
Phase 3/3: Code Review — Reviewing against acceptance criteria...
```

After all platform implementations are complete, run an automated code review before handing off to the user.

Invoke the code-reviewer agent using the Task tool:

```
subagent_type: "prdx:code-reviewer"

prompt: "Review the implementation for this PRD.

PRD Slug: {SLUG}
Base Branch: {DEFAULT_BRANCH}
Platform: {CURRENT_PLATFORM}

Acceptance Criteria:
{ACCEPTANCE_CRITERIA from PRD}

Review the diff (git diff {DEFAULT_BRANCH}..HEAD) against the acceptance criteria.
Flag bugs, security issues, quality problems, and unmet criteria.
Only report high-confidence issues.

Return only the review summary."
```

**If issues found:**
1. Display the review summary to the conversation
2. Feed each issue back to the platform agent for fixing with full context:

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

**Acceptance Criteria (from PRD):**
{ACCEPTANCE_CRITERIA from PRD}

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

**For multi-platform PRDs:**
```
✅ All platforms implemented!

📄 PRD: {PRD_FILE}
🌿 Branch: {BRANCH}
📋 Status: review

Platforms completed:
  ✅ {platform_1} - {PLATFORM_1_SUMMARY}
  ✅ {platform_2} - {PLATFORM_2_SUMMARY}
  ✅ {platform_N} - {PLATFORM_N_SUMMARY}

Next steps:
1. Test the implementation on all platforms
2. If bugs found: describe them and I'll fix them
3. When ready: /prdx:push {slug}
```

---

## Error Handling

### No Slug Provided

```
❌ No PRD slug provided

Usage: /prdx:implement <slug>

Available PRDs:
{List PRDs from ~/.claude/plans/}
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

## Key Points

1. **PRDs from native plan mode** - Read from `~/.claude/plans/`
2. **Status tracking via file edit** - Update `**Status:**` field directly
3. **Always read prdx.json first** - Config determines commit format
4. **Build commit instructions dynamically** - Based on actual config values
5. **Pass commit instructions to agent** - Include in the prompt
6. **Agents run isolated** - They don't have access to main conversation context
7. **Return summaries only** - File contents stay in agent context
8. **Multi-platform runs per Implementation Order** - Follows steps defined in PRD
9. **Pass learnings between platforms** - Include previous platform notes
10. **Code review before handoff** - prdx:code-reviewer runs after implementation, fixes issues automatically (max 2 cycles)
