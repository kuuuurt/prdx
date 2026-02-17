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
echo "=== Available PRDs ==="
ls -1 ~/.claude/plans/prdx-*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^prdx-//' || echo "No PRDs found"
```

# /prdx:implement - Implement Feature

Three-phase implementation: **Dev Planning** (prdx:dev-planner) → **Development** (Platform agent) → **Code Review** (prdx:code-reviewer)

Both agents run in **isolated contexts** to minimize main conversation context usage.

**PRDs are read from `~/.claude/plans/`** (created by native plan mode).

**For mobile PRDs with multiple platforms:** Implementation runs **sequentially** per platform.

## Usage

```bash
/prdx:implement backend-auth
/prdx:implement android-biometric-login
/prdx:implement ios-profile-screen
/prdx:implement mobile-biometric-login          # Implements Android first, then iOS
/prdx:implement mobile-biometric-login android  # Implement Android only
/prdx:implement mobile-biometric-login ios      # Implement iOS only (after Android is done)
```

## How It Works

This command orchestrates three agents in **isolated contexts**:

**Phase A: Dev Planning (prdx:dev-planner)**
- Runs in isolated context
- Explores codebase for detailed technical context
- Creates implementation plan with specific tasks
- Returns only the dev plan (~3KB)

**Phase B: Development (Platform agent)**
- Runs in isolated context
- Executes the implementation plan
- Follows TDD (tests first)
- Returns only implementation summary (~1KB)

**Phase C: Code Review (prdx:code-reviewer)**
- Runs in isolated context
- Reviews diff against acceptance criteria
- Flags bugs, security issues, unmet criteria
- If issues found: platform agent fixes, then re-review (max 2 cycles)
- Returns only review summary (~2KB)

**For Multi-Platform Mobile PRDs:**
- Runs Phase A + B for the first platform (Android by default)
- Learns from implementation, commits, and updates PRD
- Then runs Phase A + B for the second platform (iOS)
- Each platform implementation benefits from lessons learned

## Workflow

### Step 1: Load Configuration

**IMPORTANT: You must read and parse the project's prdx.json configuration.**

1. Use the Read tool to check for config file in this order:
   - `prdx.json` (project root)
   - `.prdx/prdx.json`

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
   - Platform (backend/android/ios/mobile)
   - **Platforms** (for mobile only - e.g., "android, ios" or just "android")
   - Type (feature/bug-fix/refactor/spike)
   - Branch name from `**Branch:**` field
   - Status from `**Status:**` field
   - Full PRD content

4. **Update status to `in-progress`:**
   Edit the PRD file to change `**Status:** planning` to `**Status:** in-progress`

5. **Save last-used slug** for context persistence:
   ```bash
   mkdir -p .prdx && echo "{SLUG}" > .prdx/last-slug
   ```

### Step 2a: Determine Target Platform(s)

**Parse the command arguments:**
- `{slug}` only → Use PRD's platform(s)
- `{slug} android` → Override to Android only
- `{slug} ios` → Override to iOS only

**For mobile PRDs with multiple platforms:**

1. Check if PRD has `**Platforms:**` field with multiple platforms (e.g., "android, ios")
2. Parse the `Platforms` field into a list: `TARGET_PLATFORMS`
3. If second argument provided (android/ios), filter to just that platform

**Determine implementation order:**
- If `TARGET_PLATFORMS` = ["android", "ios"] → Implement Android first, then iOS
- If `TARGET_PLATFORMS` = ["android"] → Implement Android only
- If `TARGET_PLATFORMS` = ["ios"] → Implement iOS only

**For non-mobile or single-platform PRDs:**
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

**For each platform in TARGET_PLATFORMS (sequentially):**

Run Steps 5a-5d for the current platform, then move to the next.

**For multi-platform mobile PRDs:**
- First platform (Android): Full implementation from scratch
- Second platform (iOS): Benefits from lessons learned, can reference Android implementation patterns

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
Return only the dev plan document."
```

**For the second platform in a multi-platform PRD:**
Include `PREVIOUS_PLATFORM_NOTES` with:
- Summary of first platform's implementation
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

#### Step 5b: Build Commit Instructions

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

#### Step 5c: Invoke Platform Agent

**Display progress:**
```
Phase 2/3: Implementation ({CURRENT_PLATFORM}) — Executing dev plan with TDD...
```

Determine agent based on current platform:
- backend → `prdx:backend-developer`
- frontend → `prdx:frontend-developer`
- android → `prdx:android-developer`
- ios → `prdx:ios-developer`

Invoke using the Task tool:

```
subagent_type: "{AGENT}"

prompt: "Implement this feature using the dev plan provided.

PRD File: {PRD_FILE}

{PRD_CONTENT}

---

{DEV_PLAN from Step 5}

---

**YOUR ROLE:**

The PRD defines the **what** and **why**. The dev plan defines the **how**.
Your job is to **execute** the dev plan using TDD.

**CRITICAL - COMMIT FORMAT:**

You MUST follow the commit configuration below. This is from the project's prdx.json and OVERRIDES any defaults.

{COMMIT_INSTRUCTIONS from Step 6}

**Implementation Instructions:**

1. **Execute the Dev Plan:**
   - Use TodoWrite to track tasks from the dev plan
   - Mark each task as in_progress when starting
   - Mark as completed when done

2. **Test-Driven Development:**
   - Write tests FIRST for each acceptance criterion
   - Ensure tests fail initially (red)
   - Implement to make tests pass (green)

3. **Follow Platform Patterns:**
   - Read `.claude/skills/impl-patterns.md` for {PLATFORM} patterns
   - Match existing codebase conventions

4. **Testing Strategy:**
   - Reference `.claude/skills/testing-strategy.md`
   - Write unit tests for business logic
   - Write integration tests for APIs/data flows

5. **Code Quality:**
   - Follow platform best practices
   - Add error handling
   - Keep code simple and readable

7. **Verification:**
   - Run full test suite
   - Verify each acceptance criterion

**Return only a summary:**

```markdown
## Implementation Summary

### Files Created
- [List new files]

### Files Modified
- [List modified files]

### Tests Written
- [List test files]

### Acceptance Criteria Status
- [x] AC1 - Verified
- [x] AC2 - Verified

### Commits
- [List commit messages]

### Test Results
[Pass/fail summary]
```
"
```

Wait for the platform agent to complete.

**If platform agent fails or returns an error:**

Use AskUserQuestion to offer recovery options:
- Option 1: "Retry implementation" — Re-invoke the platform agent with the same dev plan
- Option 2: "Continue manually" — Stop automated implementation, let user take over (status stays `in-progress`)
- Option 3: "Stop implementation" — Halt workflow entirely

Route based on choice:
- Retry → Re-run Step 5c
- Continue manually → Display what was accomplished so far, end workflow
- Stop → End workflow, show how to resume with `/prdx:implement {slug}`

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

3. **For multi-platform PRDs with remaining platforms:**
   - Display completion for current platform:
     ```
     ✅ {CURRENT_PLATFORM} implementation complete!

     Moving to {NEXT_PLATFORM}...
     ```
   - Store learnings as `PREVIOUS_PLATFORM_NOTES`:
     - What patterns were established
     - What worked well
     - What could be improved for the next platform
   - **Loop back to Step 5a** for the next platform

4. **When all platforms are done:**
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

Acceptance Criteria:
{ACCEPTANCE_CRITERIA from PRD}

Review the diff (git diff main..HEAD) against the acceptance criteria.
Flag bugs, security issues, quality problems, and unmet criteria.
Only report high-confidence issues.

Return only the review summary."
```

**If issues found:**
1. Display the review summary to the conversation
2. Feed each issue back to the platform agent for fixing:

```
subagent_type: "{PLATFORM_AGENT}"

prompt: "Fix the following code review issues.

{REVIEW_ISSUES}

Fix each issue, run tests to verify, and commit the fixes.

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

### Step 6: Update Status and Post-Implement Hook

1. **Update status to `review`:**
   Edit the PRD file to change `**Status:** in-progress` to `**Status:** review`

2. Run the post-implement hook (optional):
   ```bash
   if [ -f hooks/prdx/post-implement.sh ]; then
     ./hooks/prdx/post-implement.sh "{slug}"
   fi
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

**For multi-platform mobile PRDs:**
```
✅ All platforms implemented!

📄 PRD: {PRD_FILE}
🌿 Branch: {BRANCH}
📋 Status: review

Platforms completed:
  ✅ Android - {ANDROID_SUMMARY}
  ✅ iOS - {IOS_SUMMARY}

Next steps:
1. Test the implementation on both platforms
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
8. **Multi-platform mobile runs sequentially** - Android first, then iOS
9. **Pass learnings between platforms** - Include previous platform notes
10. **Code review before handoff** - prdx:code-reviewer runs after implementation, fixes issues automatically (max 2 cycles)
