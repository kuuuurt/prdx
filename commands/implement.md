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

## Workflow Overview

1. Loads PRD file
2. Runs pre-implement validation hook
3. Git branch setup
4. **Invokes prdx:dev-planner** for detailed dev planning (isolated)
5. **Invokes platform agent** for implementation (isolated)
6. Runs post-implement hook to update PRD status

## Workflow

### Phase 1: Load Configuration and PRD

Load PRDX configuration:

```bash
# Load prdx.json config (check multiple locations)
CONFIG_FILE=""
if [ -f "prdx.json" ]; then
  CONFIG_FILE="prdx.json"
elif [ -f ".claude/prdx.json" ]; then
  CONFIG_FILE=".claude/prdx.json"
fi

# Parse config or use defaults
if [ -n "$CONFIG_FILE" ]; then
  # Read config values using jq if available, otherwise use defaults
  if command -v jq &> /dev/null; then
    COAUTHOR_ENABLED=$(jq -r '.commits.coAuthor.enabled // true' "$CONFIG_FILE")
    COAUTHOR_NAME=$(jq -r '.commits.coAuthor.name // "Claude"' "$CONFIG_FILE")
    COAUTHOR_EMAIL=$(jq -r '.commits.coAuthor.email // "noreply@anthropic.com"' "$CONFIG_FILE")
    EXTENDED_DESC_ENABLED=$(jq -r '.commits.extendedDescription.enabled // true' "$CONFIG_FILE")
    CLAUDE_LINK_ENABLED=$(jq -r '.commits.extendedDescription.includeClaudeCodeLink // true' "$CONFIG_FILE")
    COMMIT_FORMAT=$(jq -r '.commits.format // "conventional"' "$CONFIG_FILE")
  else
    # Defaults if jq not available
    COAUTHOR_ENABLED=true
    COAUTHOR_NAME="Claude"
    COAUTHOR_EMAIL="noreply@anthropic.com"
    EXTENDED_DESC_ENABLED=true
    CLAUDE_LINK_ENABLED=true
    COMMIT_FORMAT="conventional"
  fi
else
  # Use defaults if no config file
  COAUTHOR_ENABLED=true
  COAUTHOR_NAME="Claude"
  COAUTHOR_EMAIL="noreply@anthropic.com"
  EXTENDED_DESC_ENABLED=true
  CLAUDE_LINK_ENABLED=true
  COMMIT_FORMAT="conventional"
fi
```

Find and load PRD file:

```bash
# Find PRD file matching slug
PRD_FILE=$(find .claude/prds -name "*${SLUG}*.md" -type f | head -1)

if [ -z "$PRD_FILE" ]; then
  echo "❌ PRD not found: $SLUG"
  exit 1
fi
```

Parse PRD to extract:
- Platform
- Type (feature/bug-fix/refactor/spike)
- Branch name (if exists)
- Full plan content

### Phase 2: Pre-Implement Hook

Run validation hook:

```bash
if [ -f hooks/prdx/pre-implement.sh ]; then
  ./hooks/prdx/pre-implement.sh "$SLUG"
fi
```

Hook validates:
- PRD has required sections
- PRD is not already completed
- Git branch is correct (or creates it)
- No uncommitted changes (or warns)

If hook fails, stop execution.

### Phase 3: Git Setup

Validate not on default branch and setup feature branch:

```bash
# Get default branch name
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -z "$DEFAULT_BRANCH" ]; then
  # Fallback: check common default branches
  if git show-ref --verify --quiet refs/heads/main; then
    DEFAULT_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    DEFAULT_BRANCH="master"
  else
    DEFAULT_BRANCH="main"  # Default assumption
  fi
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Get branch name from PRD or generate
if grep -q "^\*\*Branch:\*\*" "$PRD_FILE"; then
  BRANCH=$(grep "^\*\*Branch:\*\*" "$PRD_FILE" | sed 's/\*\*Branch:\*\* //')
else
  # Generate branch name
  TYPE=$(grep "^\*\*Type:\*\*" "$PRD_FILE" | sed 's/\*\*Type:\*\* //')
  case "$TYPE" in
    "feature") PREFIX="feat" ;;
    "bug-fix") PREFIX="fix" ;;
    "refactor") PREFIX="refactor" ;;
    "spike") PREFIX="chore" ;;
    *) PREFIX="feat" ;;
  esac

  BRANCH="${PREFIX}/${SLUG}"

  # Add branch to PRD
  sed -i.bak "s/^\*\*Created:\*\*/\*\*Branch:\*\* ${BRANCH}\n\*\*Created:\*\*/" "$PRD_FILE"
  rm "${PRD_FILE}.bak"
fi

# Validate we're not trying to work on default branch
if [ "$BRANCH" = "$DEFAULT_BRANCH" ]; then
  echo "❌ Cannot implement on default branch: $DEFAULT_BRANCH"
  echo ""
  echo "Please update the PRD branch to a feature branch"
  echo "or remove the Branch field to auto-generate one."
  exit 1
fi

# If current branch is default, create/checkout feature branch
if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
  git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
elif [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  # On a different branch, switch to the correct one
  git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
fi
```

### Phase 4: Dev Planning (prdx:dev-planner)

Invoke the dev-planner agent to create a detailed implementation plan:

```
subagent_type: "prdx:dev-planner"

prompt: "Create a detailed implementation plan for this PRD.

PRD File: {PRD_FILE}
Platform: {PLATFORM}

{PRD_CONTENT}

Read the skills files and explore the codebase to create a comprehensive dev plan.
Return only the dev plan document."
```

**Agent runs in isolated context:**
- Reads `.claude/skills/impl-patterns.md` for platform patterns
- Reads `.claude/skills/testing-strategy.md` for testing approach
- Explores codebase for architecture and patterns
- Returns only the dev plan (~3KB)

**Wait for dev-planner agent** to complete and return the dev plan.

Store the dev plan for the platform agent.

### Phase 5: Invoke Platform Agent

Determine which agent to use from platform:

```bash
PLATFORM=$(grep "^\*\*Platform:\*\*" "$PRD_FILE" | sed 's/\*\*Platform:\*\* //')

case "$PLATFORM" in
  "backend") AGENT="prdx:backend-developer" ;;
  "android") AGENT="prdx:android-developer" ;;
  "ios") AGENT="prdx:ios-developer" ;;
  *) echo "❌ Unknown platform: $PLATFORM"; exit 1 ;;
esac
```

Build the commit instructions based on config:

```bash
# Build commit format instructions
COMMIT_INSTRUCTIONS="6. **Commits:**
   - Commit format: $COMMIT_FORMAT
   - Keep commits atomic and focused

   **IMPORTANT: You MUST use HEREDOC format for all commits:**
   \`\`\`bash
   git commit -m \"\$(cat <<'EOF'
   {your commit message here}
   EOF
   )\"
   \`\`\`

   **Commit Message Structure:**"

# Add format-specific instructions
if [ "$COMMIT_FORMAT" = "conventional" ]; then
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS
   - Line 1: {type}: {short description}
   - Line 2: Empty line"
else
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS
   - Line 1: {short description}
   - Line 2: Empty line"
fi

# Add extended description if enabled
if [ "$EXTENDED_DESC_ENABLED" = "true" ]; then
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS
   - Lines 3+: Extended description explaining the change
   - Empty line"
fi

# Add Claude Code link if enabled
if [ "$CLAUDE_LINK_ENABLED" = "true" ]; then
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS
   - 🤖 Generated with [Claude Code](https://claude.com/claude-code)
   - Empty line"
fi

# Add co-author if enabled
if [ "$COAUTHOR_ENABLED" = "true" ]; then
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS
   - Co-Authored-By: $COAUTHOR_NAME <$COAUTHOR_EMAIL>"
fi

# Add examples
COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS

   **Example commit:**
   \`\`\`bash
   git commit -m \"\$(cat <<'EOF'"

if [ "$COMMIT_FORMAT" = "conventional" ]; then
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS
feat: add user authentication"
else
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS
add user authentication"
fi

if [ "$EXTENDED_DESC_ENABLED" = "true" ]; then
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS

Implement authentication endpoints with JWT token generation
and password hashing using bcrypt."
fi

if [ "$CLAUDE_LINK_ENABLED" = "true" ]; then
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
fi

if [ "$COAUTHOR_ENABLED" = "true" ]; then
  COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS

Co-Authored-By: $COAUTHOR_NAME <$COAUTHOR_EMAIL>"
fi

COMMIT_INSTRUCTIONS="$COMMIT_INSTRUCTIONS
EOF
   )\"
   \`\`\`

   **CRITICAL: Always use HEREDOC format as shown above. Never use simple quotes.**"
```

Invoke platform agent with Task tool:

```
subagent_type: "{AGENT}"  # e.g., "prdx:backend-developer"

prompt: "Implement this feature using the dev plan provided.

PRD File: {PRD_FILE}

{PRD_CONTENT}

---

{DEV_PLAN}

---

**YOUR ROLE:**

The PRD defines the **what** and **why**. The dev plan defines the **how**.
Your job is to **execute** the dev plan using TDD.

**CRITICAL INSTRUCTIONS - READ CAREFULLY:**

You MUST follow the commit configuration provided below. This configuration comes from the project's prdx.json file and overrides any default commit format you might use. Pay special attention to:
- Commit format (conventional vs simple)
- Whether to include extended descriptions
- Whether to include co-author attribution
- Whether to include Claude Code link

**Implementation Instructions:**

1. **Execute the Dev Plan:**
   - Use TodoWrite to track tasks from the dev plan
   - Mark each task as in_progress when starting
   - Mark as completed when done
   - Follow the task order from the dev plan

2. **Test-Driven Development:**
   - Write tests FIRST for each acceptance criterion
   - Ensure tests fail initially (red)
   - Implement to make tests pass (green)
   - Refactor for quality

3. **Follow Platform Patterns:**
   - Read `.claude/skills/impl-patterns.md` for {PLATFORM} patterns
   - Match existing codebase conventions
   - Use established architecture

4. **Testing Strategy:**
   - Reference `.claude/skills/testing-strategy.md`
   - Write unit tests for business logic
   - Write integration tests for APIs/data flows
   - Cover edge cases and errors

5. **Code Quality:**
   - Follow platform best practices
   - Add error handling
   - Include logging where appropriate
   - Add comments for complex logic

{COMMIT_INSTRUCTIONS}

7. **Verification:**
   - Run full test suite
   - Verify each acceptance criterion from the PRD
   - Check for compilation errors
   - Ensure all tests pass

**CRITICAL: Return only a summary, not file contents:**

```markdown
## Implementation Summary

### Files Created
- [List new files with brief descriptions]

### Files Modified
- [List modified files with brief changes]

### Tests Written
- [List test files]

### Acceptance Criteria Status
- [x] AC1: [description] - Verified
- [x] AC2: [description] - Verified

### Commits
- [List commit messages]

### Test Results
[Pass/fail summary]

### Notes
[Any follow-up items]
```

**Agent runs in isolated context:**
- All file contents stay in agent's context
- Returns only the summary (~1KB)
"
```

**Wait for platform agent** to complete implementation.

### Phase 6: Post-Implement Hook

After successful implementation, run hook:

```bash
if [ -f hooks/prdx/post-implement.sh ]; then
  ./hooks/prdx/post-implement.sh "$SLUG"
fi
```

Hook updates:
- PRD status to "implemented"
- Implementation timestamp
- Any other metadata

### Phase 7: Append Implementation Notes

Add implementation summary to PRD:

```markdown
---
## Implementation Notes

**Branch:** {BRANCH}
**Implemented:** {DATE}

{IMPLEMENTATION_SUMMARY from agent}
```

Write to PRD file after existing content.

### Phase 8: Display Summary

```
✅ Implementation Complete!

📄 PRD: {PRD_FILE}
🌿 Branch: {BRANCH}
✅ Tests: All passing

Next steps:
1. Review the implementation
2. Test manually if needed
3. Create PR: /prdx:push {SLUG}

To create PR: /prdx:push {SLUG}
To view PRD: /prdx:show {SLUG}
```

## Error Handling

### No Slug Provided

```
❌ No PRD slug provided

Usage: /prdx:implement <slug>

Available PRDs:
{List PRDs with status "planning" or "in-progress"}

Example: /prdx:implement backend-auth
```

### PRD Not Found

```
❌ PRD not found: {SLUG}

Available PRDs:
- backend-auth (planning)
- android-login (in-progress)
- ios-profile (planning)

Use: /prdx:implement <slug>
```

### Hook Validation Failed

```
❌ Pre-implement validation failed

{Hook output}

Fix the issues and try again.
```

### Platform Agent Not Found

```
❌ Platform agent not found: prdx:{PLATFORM}-developer

Available agents:
- prdx:backend-developer
- prdx:android-developer
- prdx:ios-developer

Check your plugin installation.
```

### Implementation Failed

If agent encounters errors:

```
❌ Implementation failed

{Error details from agent}

The PRD status has not been updated.
You can:
1. Fix the issues manually
2. Run /prdx:implement {SLUG} again
3. Update the PRD with /prdx:show {SLUG} --edit
```

## Platform Agents

### Backend Developer (prdx:backend-developer)

**Specializes in:**
- TypeScript/Hono API development
- Zod validation and type safety
- OpenAPI integration
- Cloud Run deployment patterns
- RESTful API design

**Reads skills:**
- `impl-patterns.md` - Backend section
- `testing-strategy.md` - Bun test patterns

### Android Developer (prdx:android-developer)

**Specializes in:**
- Kotlin/Jetpack Compose
- MVVM architecture
- Repository pattern with Hilt DI
- Material Design 3
- Clean Architecture (no Use Cases)

**Reads skills:**
- `impl-patterns.md` - Android section
- `testing-strategy.md` - JUnit/Espresso patterns

### iOS Developer (prdx:ios-developer)

**Specializes in:**
- Swift/SwiftUI
- MVVM with ObservableObject
- NavigationStack patterns
- Async/await and Combine
- Swift concurrency

**Reads skills:**
- `impl-patterns.md` - iOS section
- `testing-strategy.md` - XCTest patterns

## Examples

### Example 1: Implement Backend Feature

```
User: /prdx:implement backend-auth

→ Loads .claude/prds/backend-auth.md
→ Runs pre-implement hook (validates PRD)
→ Creates branch: feat/backend-auth
→ Invokes prdx:backend-developer agent
→ Agent uses TodoWrite to track tasks
→ Agent writes tests first
→ Agent implements features
→ Agent creates conventional commits
→ All tests pass
→ Post-implement hook updates PRD status
→ Implementation notes appended to PRD

✅ Implementation Complete!

📄 PRD: .claude/prds/backend-auth.md
🌿 Branch: feat/backend-auth
✅ Tests: 15 passing

Next steps:
1. Review the implementation
2. Create PR: /prdx:push backend-auth
```

### Example 2: Implement Android Feature

```
User: /prdx:implement android-biometric-login

→ Platform detected: android
→ Invokes prdx:android-developer agent
→ Agent implements using Compose + BiometricPrompt
→ Creates ViewModel, Repository, UI components
→ Writes unit and integration tests
→ Follows MVVM architecture from skills
→ Uses Hilt for dependency injection

✅ Implementation Complete!

📄 PRD: .claude/prds/android-biometric-login.md
🌿 Branch: feat/android-biometric-login
✅ Tests: 23 passing (12 unit, 11 integration)
```

### Example 3: Continue In-Progress Implementation

```
User: /prdx:implement ios-profile-screen

→ Loads PRD (status: in-progress)
→ Checks out existing branch: feat/ios-profile-screen
→ Pre-implement hook warns about uncommitted changes
→ User commits changes first
→ Agent continues implementation
→ Completes remaining tasks from PRD
```

## Implementation Notes

### Two-Phase Approach with Context Isolation

Implementation uses two agents in sequence, each in **isolated context**:

| Phase | Agent | Returns |
|-------|-------|---------|
| Dev Planning | prdx:dev-planner | Dev plan only (~3KB) |
| Development | prdx:{platform}-developer | Summary only (~1KB) |

**Why isolated contexts?**
- File contents stay in agent's context, not main conversation
- Main conversation only receives summaries
- Enables larger features without exhausting context limits
- Each agent focuses on its specialized task

### Why Platform Agents?

Platform agents **execute** the dev plan. Each platform has specific:
- **Architecture patterns** (MVVM, Clean Architecture, BFF)
- **Testing frameworks** (Bun Test, JUnit, XCTest)
- **Language idioms** (TypeScript, Kotlin, Swift)
- **Best practices** (Hooks vs Classes, Compose vs Views, SwiftUI vs UIKit)

Platform-specific agents understand these deeply.

### Skills as Knowledge Base

Agents automatically read skills:
- **impl-patterns.md**: Platform-specific code patterns
- **testing-strategy.md**: Testing approaches and frameworks

No custom orchestration - agents read naturally during implementation.

### TodoWrite Integration

Platform agents use Claude Code's native TodoWrite tool:
- Tasks come from the dev plan created by Plan agent
- Tracks tasks in real-time during implementation
- User sees progress without asking
- Built-in tool, no custom tracking needed

### Hook-Based Validation

Hooks provide gates:
- `pre-implement.sh` - Validates PRD and environment
- `post-implement.sh` - Updates PRD status

Hooks are **optional** but recommended for quality gates.

### Test-Driven Development

All platform agents follow TDD:
1. Write tests first (red)
2. Implement features (green)
3. Refactor (clean)

This is instructed in the agent prompt, not enforced by command logic.

### Conventional Commits

Agents create conventional commits:
- `feat:` for features
- `fix:` for bug fixes
- `refactor:` for refactoring
- `chore:` for spikes

Simple one-line format, no extended descriptions.
