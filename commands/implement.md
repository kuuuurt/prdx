---
description: "Implement feature by delegating to platform-specific agent"
argument-hint: "[slug]"
---

# /prdx:implement - Implement Feature

Two-phase implementation: **Dev Planning** (prdx:dev-planner) → **Development** (Platform agent)

Both agents run in **isolated contexts** to minimize main conversation context usage.

**For mobile PRDs with multiple platforms:** Implementation runs **sequentially** per platform to learn from the first implementation.

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

This command orchestrates two agents in **isolated contexts**:

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

### Step 2: Load PRD

1. Find PRD file matching the slug:
   ```bash
   ls .prdx/prds/*{slug}*.md
   ```

2. If not found, show error and list available PRDs

3. Read the PRD file and extract:
   - Platform (backend/android/ios/mobile)
   - **Platforms** (for mobile only - e.g., "android, ios" or just "android")
   - Type (feature/bug-fix/refactor/spike)
   - Branch name (if exists)
   - Full PRD content

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
3. Generate branch name if not in PRD:
   - feature → `feat/{slug}`
   - bug-fix → `fix/{slug}`
   - refactor → `refactor/{slug}`
   - spike → `chore/{slug}`

4. If on default branch, checkout/create the feature branch:
   ```bash
   git checkout -b {branch} 2>/dev/null || git checkout {branch}
   ```

5. Update PRD with branch name if it was generated

### Step 5: Platform Implementation Loop

**For each platform in TARGET_PLATFORMS (sequentially):**

Run Steps 5a-5d for the current platform, then move to the next.

**For multi-platform mobile PRDs:**
- First platform (Android): Full implementation from scratch
- Second platform (iOS): Benefits from lessons learned, can reference Android implementation patterns

---

#### Step 5a: Dev Planning (prdx:dev-planner)

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

**Add an example commit** showing the exact format based on config. For example, with all options enabled (conventional format):

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

#### Step 5c: Invoke Platform Agent

Determine agent based on current platform:
- backend → `prdx:backend-developer`
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
   - Continue to Step 6 (Post-Implement Hook)

---

### Step 6: Post-Implement Hook

Run the post-implement hook:

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
✅ Tests: All passing

Next steps:
1. Review the implementation
2. Create PR: /prdx:push {slug}
```

**For multi-platform mobile PRDs:**
```
✅ All platforms implemented!

📄 PRD: {PRD_FILE}
🌿 Branch: {BRANCH}

Platforms completed:
  ✅ Android - {ANDROID_SUMMARY}
  ✅ iOS - {IOS_SUMMARY}

Next steps:
1. Review the implementation for both platforms
2. Create PR: /prdx:push {slug}
```

---

## Error Handling

### No Slug Provided

```
❌ No PRD slug provided

Usage: /prdx:implement <slug>

Available PRDs:
{List PRDs from .prdx/prds/}
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
| backend | prdx:backend-developer | TypeScript, Hono, Bun, OpenAPI |
| android | prdx:android-developer | Kotlin, Compose, MVVM, Hilt |
| ios | prdx:ios-developer | Swift, SwiftUI, MVVM, async/await |

---

## Key Points

1. **Always read prdx.json first** - Config determines commit format
2. **Build commit instructions dynamically** - Based on actual config values
3. **Pass commit instructions to agent** - Include in the prompt
4. **Agents run isolated** - They don't have access to main conversation context
5. **Return summaries only** - File contents stay in agent context
6. **Multi-platform mobile runs sequentially** - Android first, then iOS, to learn from first implementation
7. **Pass learnings between platforms** - Include previous platform notes for the second implementation
