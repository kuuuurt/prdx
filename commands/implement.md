---
description: "Implement feature by delegating to platform-specific agent"
argument-hint: "[slug]"
---

# /prdx:implement - Implement Feature

Two-phase implementation: **Dev Planning** (prdx:dev-planner) → **Development** (Platform agent)

Both agents run in **isolated contexts** to minimize main conversation context usage.

## Usage

```bash
/prdx:implement backend-auth
/prdx:implement android-biometric-login
/prdx:implement ios-profile-screen
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

## Workflow

### Step 1: Load Configuration

**IMPORTANT: You must read and parse the project's prdx.json configuration.**

1. Use the Read tool to check for config file in this order:
   - `prdx.json` (project root)
   - `.claude/prdx.json`

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
   ls .claude/prds/*{slug}*.md
   ```

2. If not found, show error and list available PRDs

3. Read the PRD file and extract:
   - Platform (backend/android/ios)
   - Type (feature/bug-fix/refactor/spike)
   - Branch name (if exists)
   - Full PRD content

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

### Step 5: Dev Planning (prdx:dev-planner)

Invoke the dev-planner agent using the Task tool:

```
subagent_type: "prdx:dev-planner"

prompt: "Create a detailed implementation plan for this PRD.

PRD File: {PRD_FILE}
Platform: {PLATFORM}

{PRD_CONTENT}

Read the skills files and explore the codebase to create a comprehensive dev plan.
Return only the dev plan document."
```

Wait for the agent to return the dev plan. Store it for the next phase.

### Step 6: Build Commit Instructions

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

### Step 7: Invoke Platform Agent

Determine agent based on platform:
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

### Step 8: Post-Implement Hook

Run the post-implement hook:

```bash
if [ -f hooks/prdx/post-implement.sh ]; then
  ./hooks/prdx/post-implement.sh "{slug}"
fi
```

### Step 9: Update PRD

Append the implementation summary to the PRD file:

```markdown
---
## Implementation Notes

**Branch:** {BRANCH}
**Implemented:** {TODAY's DATE}

{IMPLEMENTATION_SUMMARY from agent}
```

### Step 10: Display Completion

```
✅ Implementation Complete!

📄 PRD: {PRD_FILE}
🌿 Branch: {BRANCH}
✅ Tests: All passing

Next steps:
1. Review the implementation
2. Create PR: /prdx:push {slug}
```

---

## Error Handling

### No Slug Provided

```
❌ No PRD slug provided

Usage: /prdx:implement <slug>

Available PRDs:
{List PRDs from .claude/prds/}
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
