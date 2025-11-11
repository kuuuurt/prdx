| description | argument-hint |
| Context-aware implementation: auto-plans, updates PRD, implements | [slug] [prompt] or empty to continue |

# Develop Feature

> **Context-aware implementation**
> Remembers your last PRD, shows what you're working on, asks if context lost

---

## Usage Modes

This command is **context-aware** - it remembers your last PRD and **always shows what you're working on**.

### Mode 1: Continue Where You Left Off (No Arguments)
```
/prdx:dev
```
- Uses last PRD you worked on automatically
- **Displays PRD name visually** for confirmation
- Continues implementation from where you stopped
- Shows progress and next tasks

### Mode 2: Fresh Implementation (Slug Only)
```
/prdx:dev backend-user-authentication
```
- Loads specified PRD
- **Displays PRD name visually** for confirmation
- Saves as current context
- Creates detailed plan if missing (inline in PRD)
- Starts implementation from scratch

### Mode 3: Continuation with Prompt (Slug + Instruction)
```
/prdx:dev backend-user-authentication "add OAuth support for Google and GitHub"
```
- Loads PRD
- **Displays PRD name visually** for confirmation
- Analyzes prompt to determine if PRD needs updating
- Calls `/prdx:update` if requirements changed
- Updates/regenerates detailed implementation plan
- Continues or starts implementation with new context

### Mode 4: Continue with Prompt (Prompt Only)
```
/prdx:dev "add error handling for network failures"
```
- Uses last PRD from context
- **Displays PRD name visually** for confirmation
- Applies prompt to current implementation
- Updates plan if needed

---

## Pre-Implementation Hook

**Run pre-dev-start validation hook:**

```bash
bash .claude/hooks/prd/pre-dev-start.sh "[PRD_PATH]"
```

Hook validates:
- PRD exists and has required sections
- Git status is clean
- Branch is appropriate
- Acceptance criteria defined
- Implementation phases present

---

## Phase 1: Parse Input & Load PRD with Context

**Context-aware argument parsing:**

1. **Load context file:**
   ```bash
   source .prdx-context 2>/dev/null || true
   ```
   - Read `LAST_PRD_SLUG`, `LAST_PRD_PATH`, `CURRENT_BRANCH`
   - Context persists across command invocations

2. **Parse arguments intelligently:**

   **No arguments** → Continue mode:
   ```
   /prdx:dev:start
   ```
   - Check context: If `LAST_PRD_SLUG` exists → use it
   - If no context: list PRDs and ask user to select
   - Display: "Continuing: [last-prd-name]"

   **One argument** → Could be slug or prompt:
   ```
   /prdx:dev:start android-219
   /prdx:dev:start "add error handling"
   ```
   - If matches PRD slug → New PRD mode
   - If doesn't match + context exists → Prompt mode (use last PRD)
   - If doesn't match + no context → Search PRDs by keyword, ask to select

   **Two+ arguments** → Slug + prompt:
   ```
   /prdx:dev:start backend-auth "add OAuth"
   ```
   - First arg = slug
   - Remaining = prompt

3. **Find PRD:**
   - If slug from args: `ls .claude/prds/*[slug]*.md`
   - If from context: use `LAST_PRD_PATH`
   - If neither: list all PRDs and ask user to select
   - **DO NOT PROCEED** without valid PRD

4. **Display PRD banner (ALWAYS show this):**

   ```
   ╔═══════════════════════════════════════════════════════════════╗
   ║  WORKING ON: [Feature Name]                                   ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║  PRD: [platform]-[slug].md                                    ║
   ║  Status: [status] | Platform: [platform]                      ║
   ║  [If issue:] Issue: #[number] | [If branch:] Branch: [name]  ║
   ╚═══════════════════════════════════════════════════════════════╝
   ```

   **Visual confirmation for developer - make this prominent!**

5. **Validate context if used:**

   If no slug provided and using context:
   ```
   [Display PRD banner above]

   Is this the correct PRD? (y/n)
   ```

   - If `y`: Continue
   - If `n`: Ask which PRD to work on
     ```
     Which PRD would you like to work on?

     Recent PRDs:
     1. android-219-biometric-auth (in-progress)
     2. backend-234-location-tracking (draft)
     3. ios-456-dark-mode (draft)

     Enter number or slug:
     ```

6. **Save to context:**
   ```bash
   echo "LAST_PRD_SLUG=[slug]" > .prdx-context
   echo "LAST_PRD_PATH=[path]" >> .prdx-context
   echo "LAST_PRD_PLATFORM=[platform]" >> .prdx-context
   echo "LAST_COMMAND=dev" >> .prdx-context
   echo "LAST_COMMAND_TIME=$(date +%s)" >> .prdx-context
   ```

7. **Read PRD and detect project structure:**
   - Extract platform(s) from PRD metadata or filename
   - Determine if **Full-Stack** (multi-platform PRD) or **Single-Platform**
   - Examples:
     - `backend-android-biometric.md` → Full-Stack, affects backend + android
     - `backend-user-auth.md` → Could be either (check repo structure)
     - `user-auth.md` → Single-Platform (current platform)

4. **Determine implementation scope:**

   **For Full-Stack PRDs** (affects multiple platforms):
   - Ask user which platform(s) to implement now
   - Options: All platforms, or select specific platform(s)
   - Can implement backend first, then mobile later
   - Each platform implementation is separate phase

   **For Single-Platform PRDs**:
   - Platform = current project automatically
   - Implementation scoped to this platform only

5. **If prompt provided, ask user about scope:**
   ```
   Prompt detected: "[prompt text]"

   How should this be handled?
   ```
   - Use AskUserQuestion with options:
     - **"Update PRD requirements"** - Requirements/scope changed, invoke /prdx:update first
     - **"Continue implementation"** - No PRD changes needed, apply prompt to implementation only
     - **"Update implementation plan only"** - PRD is fine, but regenerate detailed plan with new context

6. **Display status:**
   ```
   PRD loaded: [filename]
   Feature: [name]
   Project Structure: [Full-Stack / Single-Platform]
   Platform(s): [backend / android / ios / backend+android / etc]
   Implementing: [selected platform(s) for this run]

   Mode: [Fresh Implementation / Continue with Prompt]
   [If prompt:]
   Instruction: [prompt text]
   Action: [Update PRD / Update Plan / Continue]

   Detailed Plan Status: [FOUND / NOT FOUND / NEEDS UPDATE]

   Next steps:
   [Based on mode and plan status]
   ```

---

## Phase 2: Update PRD (If Needed)

**Only runs if user selected "Update PRD requirements" in Phase 1:**

### Invoke /prdx:update Workflow

Execute `/prdx:update` command flow inline:

1. **Pass context to /prdx:update:**
   - PRD path
   - User prompt/instruction
   - Request agent-powered impact analysis

2. **/prdx:update will:**
   - Analyze the requested changes
   - Route to appropriate platform agent (backend/android/ios)
   - Update PRD sections with strikethrough for old content
   - Add new requirements, acceptance criteria, or approach details
   - Preserve implementation history

3. **After /prdx:update completes:**
   - Reload PRD to get updated content
   - Display summary of changes made
   - Proceed to Phase 3 (Plan Update/Creation)

**Note:** See `/prdx:update` command documentation for full details on update workflow.

---

## Phase 3: Create or Update Detailed Implementation Plan

**Runs in three scenarios:**
1. No `## Detailed Implementation Plan` exists (fresh plan needed)
2. User selected "Update implementation plan only" (regenerate with new context)
3. PRD was updated in Phase 2 (plan needs to reflect new requirements)

### Agent-Powered Deep Analysis

**Route to agent(s) based on implementation scope:**

### For Full-Stack PRDs (Multi-Platform)

If implementing multiple platforms, invoke **multiple agents in parallel**, each creating their platform-specific section:

**Example: Backend + Android**
```
Task(subagent_type="backend-developer", prompt="[detailed plan for backend]")
Task(subagent_type="android-developer", prompt="[detailed plan for android]")
```

Each agent creates a section in the detailed plan:
- `## Backend Implementation` - backend-specific tasks
- `## Android Implementation` - android-specific tasks

**Note on coordination**: Agents should identify cross-platform dependencies (e.g., "backend API must be ready before android integration").

### For Single-Platform PRDs

Invoke single agent for the current platform:

**Determine plan type:**
- **Fresh plan**: No existing plan in PRD
- **Update plan**: Existing plan needs to be updated (PRD changed or user prompt requires it)

**Backend Projects:**
```
Task(
  subagent_type="backend-developer",
  prompt="[Create/Update] detailed implementation plan for [feature].

  PRD: [path]
  [If prompt provided:] User instruction: [prompt text]
  [If updating:] Existing plan: [summarize current plan]
  Use impl-patterns skill: .claude/skills/impl-patterns.md

  [If updating:]
  Review existing plan and update based on:
  - PRD changes (if any)
  - User prompt/instruction
  - Keep completed tasks marked as [x]
  - Update pending tasks to reflect new requirements
  - Add new tasks if needed
  - Preserve task history with strikethrough for removed/changed items

  [If creating:]
  Analyze codebase and provide detailed breakdown:

  Required content:
  1. Task-by-task breakdown with specific file paths
  2. API contracts (request/response with Zod schemas)
  3. Service integration points and patterns
  4. Database/Redis changes if needed
  5. Code patterns from impl-patterns skill
  6. Dependencies between tasks
  7. Risk assessment with technical details
  8. Testing strategy with specific test files
  9. AC-to-test mapping: Every Acceptance Criterion must map to specific tests

  CRITICAL: Ensure every AC from PRD has corresponding test(s) identified.

  Return structured plan ready to [add/update] inline in PRD."
)
```

**Android Projects:**
```
Task(
  subagent_type="android-developer",
  prompt="[Create/Update] detailed implementation plan for [feature].

  PRD: [path]
  [If prompt provided:] User instruction: [prompt text]
  [If updating:] Existing plan: [summarize current plan]
  Use impl-patterns skill: .claude/skills/impl-patterns.md

  [If updating:]
  Review existing plan and update based on:
  - PRD changes (if any)
  - User prompt/instruction
  - Keep completed tasks marked as [x]
  - Update pending tasks to reflect new requirements
  - Add new tasks if needed
  - Preserve task history with strikethrough for removed/changed items

  [If creating:]
  Analyze codebase and provide detailed breakdown:

  Required content:
  1. Task-by-task breakdown with specific file paths
  2. ViewModel/Repository structure with files
  3. Compose UI component breakdown
  4. Navigation changes with routes
  5. Data models and StateFlow patterns
  6. Code patterns from impl-patterns skill
  7. Dependencies between tasks
  8. Risk assessment
  9. Testing strategy (unit + Compose UI tests)
  10. AC-to-test mapping: Every Acceptance Criterion must map to specific tests

  CRITICAL: Ensure every AC from PRD has corresponding test(s) identified.

  Return structured plan ready to [add/update] inline in PRD."
)
```

**iOS Projects:**
```
Task(
  subagent_type="ios-developer",
  prompt="[Create/Update] detailed implementation plan for [feature].

  PRD: [path]
  [If prompt provided:] User instruction: [prompt text]
  [If updating:] Existing plan: [summarize current plan]
  Use impl-patterns skill: .claude/skills/impl-patterns.md

  [If updating:]
  Review existing plan and update based on:
  - PRD changes (if any)
  - User prompt/instruction
  - Keep completed tasks marked as [x]
  - Update pending tasks to reflect new requirements
  - Add new tasks if needed
  - Preserve task history with strikethrough for removed/changed items

  [If creating:]
  Analyze codebase and provide detailed breakdown:

  Required content:
  1. Task-by-task breakdown with specific file paths
  2. SwiftUI view structure with files
  3. ViewModel/Service architecture
  4. NavigationStack route changes
  5. Data models and @Published patterns
  6. Code patterns from impl-patterns skill
  7. Dependencies between tasks
  8. Risk assessment
  9. Testing strategy (XCTest + UI tests)
  10. AC-to-test mapping: Every Acceptance Criterion must map to specific tests

  CRITICAL: Ensure every AC from PRD has corresponding test(s) identified.

  Return structured plan ready to [add/update] inline in PRD."
)
```

---

## Phase 4: Add or Update Detailed Plan in PRD

**Use Edit tool to add/update comprehensive plan in PRD:**

### For New Plans (No existing plan)

Add new section after high-level Implementation section:

```markdown
---

## Detailed Implementation Plan

**Created**: [YYYY-MM-DD] | **Agent**: [platform]-developer | **Skills**: impl-patterns, testing-strategy

### Summary

[2-3 sentences: what we're building, approach, outcome from agent]

**Estimated effort**: [X simple, Y medium, Z complex] = ~[N hours]

---

### Task Breakdown

#### Phase 1: Foundation
- [ ] **Task name** (S) - `specific/file/path.ext`
  - Description: [What this accomplishes]
  - Technical details: [Patterns, code structure from impl-patterns]
  - Satisfies AC: [#1, #2]
  - Dependencies: None

#### Phase 2: Core Logic
- [ ] **Task name** (M) - `file1.ext`, `file2.ext`
  - Description: [What this accomplishes]
  - Technical details: [API contracts, patterns, integration points]
  - Satisfies AC: [#3]
  - Dependencies: Phase 1 complete

[Phases 3-5: Integration, Testing, Polish with similar structure]

---

### Technical Approach

**Architecture**: [Design decisions from agent]

**Code Patterns** (from impl-patterns skill):
- Pattern 1: [Reference and example]
- Pattern 2: [Reference and example]

**API Contracts** (Backend):
```typescript
// Request/Response structures
```

**Data Models** (Mobile):
```
// Model structures, state management
```

---

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Technical risk] | H/M/L | H/M/L | [Detailed strategy] |

---

### Testing Strategy

**CRITICAL**: Every Acceptance Criterion must have a corresponding test

(From testing-strategy skill)

**Unit Tests**:
- Files: [Specific test file paths]
- Coverage: [Target percentage]
- AC Coverage: [Which ACs these tests verify]
- Scenarios: [Key test cases mapped to ACs]

**Integration Tests**:
- Flows: [End-to-end scenarios]
- AC Coverage: [Which ACs these tests verify]

**Manual Testing**:
- [ ] Test case 1 (verifies AC #X)
- [ ] Test case 2 (verifies AC #Y)

**Commands**:
```bash
[Platform-specific test commands]
```

**AC-to-Test Traceability**:
- Each AC from PRD must map to at least one test (unit/integration/manual)

---

### Acceptance Criteria Mapping

**Every AC must map to specific tasks AND tests**

- AC #1: [Criterion] → Tasks: [task names] | Tests: [test file/type]
- AC #2: [Criterion] → Tasks: [task names] | Tests: [test file/type]
- AC #3: [Criterion] → Tasks: [task names] | Tests: [test file/type]
```

**Display confirmation:**
```
✓ Detailed Implementation Plan Created!

Added to PRD: ## Detailed Implementation Plan

Summary:
- Tasks: [N tasks across 5 phases]
- Effort: [X simple, Y medium, Z complex] = ~[N hours]
- Files to create: [count]
- Files to modify: [count]
- Risks identified: [count]

Agent: [platform]-developer
Skills: impl-patterns, testing-strategy

Ready to proceed with implementation.
```

### For Updating Existing Plans

**Use Edit tool to update the existing `## Detailed Implementation Plan` section:**

**Update strategy:**
1. **Preserve completed tasks** - Keep all `[x]` checked items unchanged
2. **Update pending tasks** - Modify `[ ]` tasks to reflect new requirements
3. **Use strikethrough** - For changed/removed content: `~~old content~~` → new content
4. **Add new tasks** - Insert new tasks where appropriate in phase structure
5. **Update metadata** - Add update timestamp:
   ```markdown
   **Created**: [original-date] | **Updated**: [YYYY-MM-DD] | **Agent**: [platform]-developer
   **Update reason**: [Brief description of why plan was updated]
   ```

**Example update:**
```markdown
#### Phase 2: Core Logic
- [x] **Implement user authentication** (M) - `src/auth/service.ts`
  - Description: Basic email/password auth
  - Technical details: JWT tokens, bcrypt hashing
  - ✅ Completed: 2025-11-05

- [ ] ~~**Add session management** (S)~~ **Add OAuth2 authentication** (M) - `src/auth/oauth.ts`, `src/auth/service.ts`
  - Description: Support Google and GitHub OAuth
  - Technical details: OAuth2 flow, token exchange, provider integration
  - Satisfies AC: #2 (updated), #4 (new)
  - Dependencies: Phase 1 complete
  - 🔄 Updated: Changed from session management to OAuth per user prompt

- [ ] **NEW: Add OAuth callback handlers** (S) - `src/auth/callbacks.ts`
  - Description: Handle OAuth provider callbacks
  - Technical details: State validation, token storage
  - Satisfies AC: #4
  - Dependencies: OAuth authentication complete
  - ✨ Added: New requirement from updated PRD
```

**Display confirmation:**
```
✓ Detailed Implementation Plan Updated!

Updated in PRD: ## Detailed Implementation Plan

Changes:
- Tasks completed: [N] (preserved)
- Tasks updated: [N] with strikethrough history
- Tasks added: [N] new tasks
- Effort revised: [X simple, Y medium, Z complex] = ~[N hours]

Update reason: [Based on PRD changes / User prompt / etc.]
Agent: [platform]-developer
Skills: impl-patterns, testing-strategy

Ready to proceed with implementation.
```

---

## Phase 5: Git Setup & Branch Strategy

**Prepare for implementation:**

1. **Navigate to platform directory:**

   **For Full-Stack projects**:
   - Detect platform from implementation scope (Phase 1)
   - Navigate to platform directory: `cd backend/` or `cd android/` or `cd ios/`
   - If implementing multiple platforms, start with first (typically backend)

   **For Single-Platform projects**:
   - Stay in root directory (already in the platform repo)

2. **Check git status:**
   ```bash
   git status
   ```
   - If uncommitted changes: **WARN** and suggest commit/stash first
   - **DO NOT PROCEED** with dirty working tree

3. **Check current branch:**
   ```bash
   git branch --show-current
   ```

4. **Smart Git Health Checks:**
   - **Check if current branch is behind main:**
     ```bash
     git fetch origin main
     git rev-list --count HEAD..origin/main
     ```
     If behind, prompt:
     ```
     ⚠️  Current branch is [N] commits behind main.

     Options:
     1. Rebase on main now (recommended)
     2. Continue anyway (may cause conflicts later)
     3. Cancel and sync manually

     What would you like to do?
     ```

   - **Check branch age (if not on main):**
     ```bash
     git log -1 --format=%ct [branch-name]
     ```
     If branch is >7 days old, warn:
     ```
     ⚠️  This branch is [N] days old and may be stale.
     Consider rebasing on main before continuing.
     ```

5. **Determine branch type from PRD metadata:**
   - Read `**Branch Type**` from PRD metadata (added by /prdx:plan)
   - If not present, infer from PRD filename or ask user:
     - Contains "fix": `fix/`
     - Contains "refactor": `refactor/`
     - Default: `feat/`
   - Map to conventional commit prefix:
     - feat → `feat/`
     - fix → `fix/`
     - refactor → `refactor/`
     - spike → `chore/` or `spike/`
     - chore → `chore/`
     - docs → `docs/`

6. **If on `main`/`master`/`develop`, create feature branch:**

   **Branch naming based on project structure**:

   **Full-Stack projects**:
   ```
   Format: <type>/<platform>-<issue-or-slug>
   Example: feat/backend-123-user-auth
   Example: feat/android-456-biometric
   ```
   - Include platform name (backend/android/ios)
   - Helps identify which platform the work affects

   **Single-Platform projects**:
   ```
   Format: <type>/<issue-or-slug>
   Example: feat/123-user-auth
   Example: fix/456-memory-leak
   ```
   - No platform prefix needed (repo = one platform)

   ```
   Suggested branch: [suggested-name]

   Accept suggested name? (y/n)
   [If no:] Enter custom name:
   ```

7. **Create or checkout branch:**
   ```bash
   git checkout -b [branch-name]
   # OR if branch exists:
   git checkout [branch-name]
   ```

8. **Update PRD status to "in-progress":**
   - Use Edit tool to update PRD metadata:
     ```markdown
     **Status**: draft → **Status**: in-progress
     ```
   - Add branch information to metadata:
     ```markdown
     **Branch**: [branch-name]
     ```
   - Record start date:
     ```markdown
     **Started**: [YYYY-MM-DD]
     ```

9. **Display plan and confirm:**
   ```
   Ready to implement: [Feature Name]

   Project: [project]
   PRD: .claude/prds/[prd-filename]
   Status: draft → in-progress ✓
   Detailed Plan: [Created / Pre-existing] in PRD
   Branch: [branch-name] (conventional: [type]/)
   Started: [date]

   Implementation Strategy:
   - Detailed plan with file paths available
   - [N] tasks across [M] phases
   - Estimated effort: ~[N hours]
   - Agent available for additional guidance if needed

   Commit format: Conventional commits (type: description)
   - No co-author, no extended description

   Proceed with implementation? (y/n)
   ```

---

## Phase 6: Execute Implementation from Detailed Plan

**Systematically implement each task from detailed plan:**

**Note:** If a prompt was provided and plan was updated, focus on:
- New/updated tasks first (marked with 🔄 Updated or ✨ Added)
- Then complete remaining pending tasks
- Skip already completed tasks (marked [x])

### Task Execution Loop

For each task in Detailed Implementation Plan:

1. **Start task:**
   - Update TodoWrite with task as `in_progress`
   - Display task details: description, files, technical details, dependencies

2. **Implement task:**
   - Follow technical details from plan (patterns, API contracts, etc.)
   - Use Read/Edit/Write tools
   - Reference impl-patterns skill if needed
   - Keep changes focused to task scope

3. **Handle discrepancies:**
   - **If you discover a blocker or need to deviate from plan:**
     - **PAUSE implementation**
     - **Use AskUserQuestion** to present options:
       ```
       Discrepancy detected in task: [task name]

       Issue: [What's wrong - blocker, better approach, missing dependency, etc.]

       Options:
       1. Update detailed plan in PRD (revise approach)
       2. Proceed with workaround (document deviation)
       3. Stop and reassess

       What should I do?
       ```
     - **Wait for approval** before proceeding
     - **If approved to update:**
       - Edit detailed plan in PRD with strikethrough
       - Document deviation

4. **Commit task** (one task = one commit):
   ```bash
   git add [relevant files]
   git commit -m "[type]: [simple description]"
   ```

   Conventional commit types:
   - `feat:` - New feature
   - `fix:` - Bug fix
   - `test:` - Tests
   - `refactor:` - Code refactoring
   - `chore:` - Maintenance
   - `docs:` - Documentation

   Examples:
   - `feat: add user profile settings screen`
   - `feat: implement profile data repository`
   - `test: add profile settings tests`

5. **Mark complete:**
   - Update TodoWrite marking task as `completed`
   - Check off task in detailed plan: `[ ]` → `[x]`

6. **Handle blocks:**
   - If task blocked, prompt user for guidance
   - Don't skip without explicit approval
   - Document any workarounds

---

## Phase 7: Efficient Testing Strategy

**Test effectively, not exhaustively. Focus on end results.**

### Testing Philosophy (from testing-strategy.md skill)

**Effective > Comprehensive:**
- Test **end results**, not implementation details
- Focus on **user-facing behavior** and **contracts**
- Use **Given-When-Then** pattern for clarity
- Each Acceptance Criterion → At least one test

**What to Test:**
- ✅ API endpoints (full request → response)
- ✅ User flows (login, navigation, submission)
- ✅ Business logic outcomes (input → result)
- ✅ Error handling (edge cases, failures)
- ✅ Validation (reject bad input)

**What NOT to Test:**
- ❌ Framework internals
- ❌ Third-party libraries
- ❌ Trivial code (getters/setters)
- ❌ Implementation details (which functions called)

### Writing Tests (Given-When-Then)

**Backend Example:**
```typescript
test('broadcasts location to riders', async () => {
  // Given: Authenticated driver
  const token = generateAuthToken('driver-123')

  // When: Driver sends location
  const response = await app.request('/api/driver/location', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify({ lat: 37.7749, lng: -122.4194 })
  })

  // Then: Location saved and broadcast
  expect(response.status).toBe(200)
  expect(await getDriverLocation('driver-123')).toMatchObject({
    lat: 37.7749, lng: -122.4194
  })
})
```

**Android Example:**
```kotlin
@Test
fun `login succeeds with valid credentials`() = runTest {
  // Given: Valid credentials
  val email = "user@example.com"
  val password = "password123"

  // When: User attempts login
  viewModel.login(email, password)

  // Then: User is authenticated
  val state = viewModel.state.value
  assertTrue(state.isAuthenticated)
  assertNull(state.error)
}
```

### Test Execution

1. **Run tests:**
   - Backend: `bun test`
   - Android: `./gradlew testDebugUnitTest`
   - iOS: `xcodebuild test -scheme YourApp`

2. **Linting/formatting:**
   - Backend: `bun run lint && bun run format`
   - Android: `./gradlew spotlessCheck && ./gradlew spotlessApply`

3. **Fix failures:**
   - If tests fail: **STOP** and fix before proceeding
   - Focus on fixing the behavior, not achieving coverage

4. **Manual testing (if needed):**
   - Only for UI flows or integration scenarios
   - Follow acceptance criteria checklist
   - Wait for user confirmation

5. **Commit tests:**
   ```bash
   git add [test files]
   git commit -m "test: verify [acceptance criterion]"
   ```

**Coverage Target:**
- Don't chase percentages
- Ensure: One test per Acceptance Criterion
- Critical paths covered
- Edge cases handled

---

## Phase 8: Finalize & Summary

**Complete implementation:**

1. **Run `/optimize`** to cleanup and optimize the implemented changes

2. **Update PRD** with implementation notes:
   ```markdown
   ---

   ## Implementation Notes

   **Implemented**: [date] | **Branch**: [branch-name]

   **Approach**: [Fresh implementation / Continuation with updates]
   [If prompt provided:]
   **User Prompt**: "[prompt text]"
   **PRD Updated**: [Yes/No] - [If yes: summary of changes]
   **Plan Updated**: [Yes/No] - [Created fresh / Updated existing]

   **Detailed Plan**: [Created/Updated] [date] by [platform]-developer

   **Commits**: [list commit SHAs and messages]

   **Deviations from Plan**:
   - [Deviation 1]: [Reason]
   - [Deviation 2]: [Reason]

   **Issues encountered**:
   - [Issue 1]: [Resolution]
   - [Issue 2]: [Resolution]

   **Testing results**:
   - Unit tests: [pass/fail count]
   - Integration tests: [status]
   - Manual testing: ✓ All test cases passed
   - Linting: ✓ Passed

   **Plan accuracy**:
   - [How well the detailed plan matched actual implementation]
   - [What was helpful / what could be improved]
   ```

3. **Mark tasks complete** in detailed plan (change `[ ]` to `[x]`)

4. **Update PRD status:**
   ```markdown
   **Status**: draft → implemented
   **Branch**: [branch-name]
   **Implemented**: [date]
   ```

5. **Display final summary:**
   ```
   ✓ Enhanced Feature Implementation Complete!

   Feature: [name]
   Project: [project]
   Branch: [branch-name]

   [If prompt provided:]
   Mode: Continuation with updates
   User Prompt: "[prompt text]"
   PRD Updated: [Yes/No]
   Plan Updated: [Yes/No]
   [Else:]
   Mode: Fresh implementation

   Approach:
   [Detailed plan created/updated/pre-existing] → Implementation executed

   Summary:
   - Tasks completed: [count]/[total]
   - Commits: [count]
   - Tests: ✓ [passing]/[total]
   - Linting: ✓ Passed

   [If PRD was updated:]
   PRD Update Phase:
   ✓ Requirements updated via /prdx:update
   ✓ Agent-powered impact analysis
   ✓ Changes documented with strikethrough

   Planning Phase:
   [If plan was created/updated:]
   ✓ Detailed plan [created/updated] by [platform]-developer
   ✓ impl-patterns skill applied
   ✓ testing-strategy skill applied
   [If updated:]
   ✓ Completed tasks preserved
   ✓ New tasks: [count added]
   ✓ Updated tasks: [count changed]

   Implementation Phase:
   ✓ Followed detailed plan structure
   ✓ File paths and patterns from plan
   ✓ Task dependencies respected

   Changes:
   [List modified/created files with line counts]

   Deviations from plan: [count]
   Plan accuracy: [assessment]

   Next steps:
   - Review implementation and PRD
   - Run /prdx:dev:check [slug] for multi-agent verification
   - Run /prdx:dev:push [slug] to create PR
   - Or push manually: git push -u origin [branch-name]
   ```

---

## Post-Implementation Hook

**Run post-dev-start hook:**

```bash
bash .claude/hooks/prd/post-dev-start.sh "[PRD_PATH]" "[BRANCH_NAME]"
```

Hook will:
- Confirm implementation complete
- Show commit summary
- Suggest next steps
- (Optionally trigger CI/notifications - customizable)

---

## Important Rules

### Prompt Handling
- **PARSE carefully** - Extract slug and optional prompt from arguments
- **ASK USER** - When prompt provided, ask how to handle it (Update PRD / Update Plan / Continue)
- **CALL /prdx:update** - When user selects "Update PRD requirements", invoke update workflow
- **UPDATE PLAN** - When requirements change, regenerate or update detailed plan
- **PRESERVE COMPLETED** - Never lose completed task history when updating plans

### Multi-Phase Behavior
- **ALWAYS check** for detailed plan first
- **CREATE PLAN INLINE** if missing (Phase 3-4)
- **UPDATE PLAN INLINE** if prompt requires plan changes
- **USE existing plan** if no changes needed
- **ONE COMMAND** handles prompts, updates, planning, and implementation

### Commits
- **CONVENTIONAL COMMITS** - Format: `type: description` (no co-author, no extended desc)
- **ONE TASK = ONE COMMIT** - Keep commits atomic and focused
- **CLEAR MESSAGES** - Describe what, not how

### Implementation
- **FOLLOW THE PLAN** - Detailed plan is source of truth
- **USE plan details** - File paths, patterns, technical approach all in plan
- **ASK BEFORE DEVIATING** - Always prompt for approval on discrepancies
- **UPDATE PLAN** - Keep plan in sync with reality (strikethrough for changes)
- **TRACK PROGRESS** - Use TodoWrite to keep user informed
- **CLEAN GIT STATE** - Never proceed with uncommitted changes
- **NEVER COMMIT PRDS** - PRD files are NEVER committed to git, only implementation code

### Testing
- **DON'T SKIP TESTS** - Always run tests if they exist
- **FIX BEFORE PROCEEDING** - Never continue with failing tests
- **AUTO-FIX LINT** - Apply formatting fixes automatically
- **USE plan strategy** - Follow testing approach from detailed plan

### Quality
- **FOLLOW PLAN PATTERNS** - Use patterns specified in detailed plan
- **BE THOROUGH** - Complete all tasks, handle all edge cases
- **PRESERVE HISTORY** - Use strikethrough in plan updates
- **DOCUMENT DEVIATIONS** - Explain why plan changed

### User Communication
- **PROMPT FOR DISCREPANCIES** - Use AskUserQuestion for all deviations
- **BE TRANSPARENT** - Show what's happening at each step
- **CONFIRM BEFORE PROCEED** - Get approval at key decision points
- **SUMMARIZE AT END** - Clear summary of what was accomplished

---

## Workflow Summary

### Scenario 1: Fresh Implementation (Slug Only)
```
/prdx:dev:start backend-auth

Load PRD → No detailed plan found
    ↓
Create detailed plan inline with agent (Phase 3-4)
    ↓
Setup git branch
    ↓
Execute implementation from plan
    ↓
Complete!
```

### Scenario 2: Continuation (Slug + Prompt, Update PRD)
```
/prdx:dev:start backend-auth "add OAuth support"

Load PRD → Prompt detected → Ask user how to handle
    ↓ (User selects: Update PRD requirements)
Invoke /prdx:update with prompt
    ↓
PRD updated with new requirements
    ↓
Update detailed plan inline with agent (Phase 3-4)
    ↓
Setup git branch
    ↓
Execute implementation (focus on new/updated tasks)
    ↓
Complete!
```

### Scenario 3: Continuation (Slug + Prompt, Update Plan Only)
```
/prdx:dev:start backend-auth "refactor authentication service"

Load PRD → Prompt detected → Ask user how to handle
    ↓ (User selects: Update implementation plan only)
Update detailed plan inline with agent (Phase 3-4)
    ↓
Detailed plan updated (preserve completed tasks)
    ↓
Setup git branch (or use existing)
    ↓
Execute implementation (focus on new/updated tasks)
    ↓
Complete!
```

### Scenario 4: Continuation (Slug + Prompt, No Updates)
```
/prdx:dev:start backend-auth "continue implementation"

Load PRD → Prompt detected → Ask user how to handle
    ↓ (User selects: Continue implementation)
Load existing plan
    ↓
Setup git branch (or use existing)
    ↓
Execute implementation (prompt guides focus, no plan changes)
    ↓
Complete!
```

### Scenario 5: Subsequent Run (Plan Exists)
```
/prdx:dev:start backend-auth

Load PRD → Detailed plan found
    ↓
Skip planning (already have detailed plan)
    ↓
Setup git branch (or use existing)
    ↓
Execute implementation from plan
    ↓
Complete!
```

**Key Features:**
- ✅ Accepts prompts for dynamic updates
- ✅ Intelligently calls /prdx:update when needed
- ✅ Creates detailed plans inline automatically when needed
- ✅ Preserves completed task history when updating plans
- ✅ One command handles all scenarios
- ✅ Flexible workflow for any development stage
