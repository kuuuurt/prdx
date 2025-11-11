| description | argument-hint |
| Create PRD with agent-powered planning - STOPS after PRD creation | Feature description [--type TYPE] [--depends-on ISSUE] [--platform PLATFORM] |

# Create PRD

> **Agent-powered PRD creation - PLANNING ONLY**
> Creates business-level PRD, then STOPS. Use /prdx:dev to start implementation.
>
> **IMPORTANT**: This command creates the PRD file and exits. It does NOT start implementation.

## Usage

```bash
/prdx:plan <feature-description> [options]
```

## Options

- `--type <type>` - Override inferred type: `feature`, `bug-fix`, `refactor`, `spike`
- `--depends-on <issue>` - Dependencies: issue number(s) or PRD slug(s) (comma-separated)
- `--platform <platform>` - Override detected platform: `backend`, `android`, `ios`, `web`

## Examples

```bash
# Smart defaults - infers type and platform
/prdx:plan "add biometric login"
→ Infers: feature, android (or asks if ambiguous)

# Description-based type inference
/prdx:plan "fix memory leak in auth service"
→ Infers: bug-fix (contains "fix")

/prdx:plan "refactor auth flow to use new pattern"
→ Infers: refactor (contains "refactor")

/prdx:plan "investigate performance issues"
→ Infers: spike (contains "investigate")

# Explicit override when needed
/prdx:plan "add fix for caching" --type feature
→ Uses: feature (overrides "fix" keyword)

# With dependencies
/prdx:plan "complete auth refactor" --depends-on #215,#218
```

---

## Pre-Planning Hook (Optional)

**If pre-plan hook exists, run it:**

```bash
bash .claude/hooks/prd/pre-plan.sh "$FEATURE_SLUG"
```

Hook can:
- Check for similar existing PRDs
- Validate git status
- Warn about in-progress PRDs
- Provide context before starting

---

## Phase 1: Setup & Discovery

**Parse parameters and detect project with smart inference:**

1. **Parse command-line options**:
   - Extract `--type` parameter (if provided)
   - Extract `--depends-on` parameter (parse comma-separated values)
   - Extract `--platform` parameter (if provided)

2. **Infer PRD type from description** (if `--type` not provided):

   Analyze the feature description for keywords:

   **Bug-fix keywords** (priority: high):
   - Contains: "fix", "bug", "error", "crash", "issue", "broken"
   - Example: "fix memory leak" → `bug-fix`

   **Refactor keywords** (priority: medium):
   - Contains: "refactor", "simplify", "optimize", "improve", "migrate"
   - Example: "refactor auth flow" → `refactor`

   **Spike keywords** (priority: medium):
   - Contains: "investigate", "explore", "research", "spike", "evaluate"
   - Example: "investigate performance" → `spike`

   **Default** (if no keywords match):
   - Use `feature`
   - Example: "add biometric login" → `feature`

   **Override**: If `--type` provided, use that instead.

3. **Display inferred type** and confirm if ambiguous:
   ```
   Inferred PRD type: bug-fix (from "fix memory leak")

   Is this correct? (y/n)
   [If no:] Select type: feature, bug-fix, refactor, spike
   ```

4. **Determine branch type** for conventional commits:
   - `feature` → branch prefix: `feat/`
   - `bug-fix` → branch prefix: `fix/`
   - `refactor` → branch prefix: `refactor/`
   - `spike` → branch prefix: `spike/` (or `chore/` if preferred)

5. **Auto-detect platform** (if `--platform` not provided):

   **From current directory:**
   ```bash
   pwd
   ```
   - If in `backend/` or contains TypeScript/Hono → `backend`
   - If in `android/` or contains Kotlin/Gradle → `android`
   - If in `ios/` or contains Swift/Xcode → `ios`
   - If in `web/` or `frontend/` → `web`

   **From description keywords:**
   - Contains "API", "endpoint", "server", "backend" → `backend`
   - Contains "Android", "Compose", "Activity" → `android`
   - Contains "iOS", "SwiftUI", "View Controller" → `ios`
   - Contains "web", "React", "frontend" → `web`

   **From recent PRDs** (pattern matching):
   - Check last 5 PRDs to find common platform

   **If still ambiguous**: Ask user
   ```
   Which platform does this affect?
   1. backend
   2. android
   3. ios
   4. Multiple platforms
   ```

   **Override**: If `--platform` provided, use that instead.

6. **Detect project structure** (critical for adaptive workflow):

   Check current directory structure:

   **Full-Stack Project** (multiple platforms in one repo):
   ```
   project-root/
   ├── .claude/prds/       # Centralized PRDs
   ├── backend/            # Backend platform
   ├── android/            # Android platform
   ├── ios/                # iOS platform
   └── web/                # Web platform (optional)
   ```
   - Multiple platform directories at root level
   - PRDs may span multiple platforms
   - Cross-platform coordination in single PRD

   **Single-Platform Project** (dedicated repo per platform):
   ```
   backend-repo/
   ├── .claude/prds/       # Backend-only PRDs
   ├── src/
   └── ...
   ```
   - Single platform per repository
   - PRDs scoped to this platform only
   - Other platforms = external dependencies

   **Detection**: Run `ls` - if 2+ platform dirs found → Full-Stack, else → Single-Platform

4. **Auto-search for duplicate PRDs** (before asking user):

   Extract keywords from description and search existing PRDs:
   ```bash
   # Extract 2-3 key nouns from description
   # Search for each keyword
   grep -r -i "<keyword>" .claude/prds --include="*.md" --exclude-dir=templates
   ```

   If similar PRDs found (>50% keyword overlap):
   ```
   ⚠️ Found similar PRD:
     - android-biometric-auth.md (Status: draft)
       "Add biometric authentication"

   Is this the same work? (y/n)
   [If yes:] Opening existing PRD...
   [If no:] Continuing with new PRD...
   ```

   **Skip this if:** Less than 2 existing PRDs (nothing to duplicate)

5. **Determine platform scope**:

   **For Full-Stack projects**:
   - Ask user which platform(s) this PRD affects (if not already detected)
   - Can be single (backend) or multiple (backend+android)
   - PRD coordinates work across platforms

   **For Single-Platform projects**:
   - Platform = detected platform automatically
   - Other platforms referenced as external only

6. Create PRD slug based on project structure:
   - **Full-Stack**: `[platform(s)]-[feature-name].md`
     - Example: `backend-user-auth.md`
     - Example: `backend-android-biometric.md` (cross-platform)
   - **Single-Platform**: `[feature-name].md`
     - Example: `user-auth.md`
   - All PRDs in `.claude/prds/` directory

6. **Select appropriate template** (if templates exist):
   - `feature` → `.claude/prds/templates/feature-template.md`
   - `bug-fix` → `.claude/prds/templates/bug-fix-template.md`
   - `refactor` → `.claude/prds/templates/refactor-template.md`
   - `spike` → `.claude/prds/templates/spike-template.md`

7. **Ask ONLY essential clarifying questions** (streamlined):

   **Only ask questions that can't be inferred:**

   - If description is vague (< 5 words): Ask "What problem are we solving?"
   - If bug-fix type + no repro mentioned: Ask "Steps to reproduce?"
   - If spike type: Ask "Time box (hours/days)?" (required for spikes)

   **Don't ask if already clear:**
   - ✗ "Who experiences this?" → Infer from context
   - ✗ "What problem?" → Already in description
   - ✗ "Current pain points?" → Use agent analysis instead

   **Example - Smart questions:**
   ```
   Description: "fix memory leak"
   → Asks: "Steps to reproduce the memory leak?"
   → Doesn't ask: "What problem?" (obvious from description)
   ```

   **Goal**: Minimize back-and-forth, maximize agent intelligence

---

## Phase 2: Agent-Powered Context Understanding

**Route to agent(s) based on project structure:**

### For Full-Stack Projects

If PRD affects multiple platforms, invoke **multiple agents in parallel**:

**Example: Backend + Android feature**
```
Task(subagent_type="backend-developer", prompt="[context]")
Task(subagent_type="android-developer", prompt="[context]")
```

Each agent provides context for their platform:
- Similar features in their codebase
- Integration points with other platforms
- Architectural patterns to follow
- Platform-specific considerations

**Coordination note**: Agents should mention cross-platform integration points.

### For Single-Platform Projects

Invoke single agent for the current platform:

**Backend:**
```
Task(
  subagent_type="backend-developer",
  prompt="Understand context for [feature] at a high level:
  - What similar features exist in the codebase?
  - What are the main integration points?
  - What architectural patterns should be followed?
  - What are the key business logic considerations?
  - How does this integrate with external clients (if any)?

  Provide high-level context (NO specific file paths or code details)."
)
```

**Android:**
```
Task(
  subagent_type="android-developer",
  prompt="Understand context for [feature] at a high level:
  - What similar features exist in the app?
  - What are the main integration points (API, services)?
  - What architectural patterns should be followed?
  - What are the key user experience considerations?
  - What backend APIs will this interact with?

  Provide high-level context (NO specific file paths or code details)."
)
```

**iOS:**
```
Task(
  subagent_type="ios-developer",
  prompt="Understand context for [feature] at a high-level:
  - What similar features exist in the app?
  - What are the main integration points (API, services)?
  - What architectural patterns should be followed?
  - What are the key user experience considerations?
  - What backend APIs will this interact with?

  Provide high-level context (NO specific file paths or code details)."
)
```

**Note**: Single-platform projects treat other platforms as external dependencies.

---

## Phase 3: Define Goal & Acceptance Criteria

**What success looks like:**

1. **Primary goal**: 1-2 sentences max, specific and measurable

2. **Acceptance criteria**: 3-5 testable requirements

   **CRITICAL RULE: No test = No acceptance criterion**
   - Every AC must map to a specific test (unit, integration, or manual)
   - Write ACs BEFORE designing the solution
   - Each criterion = one clear pass/fail test
   - Focus on observable outcomes, not implementation details

   **Format**: `- [ ] [Testable outcome that can be verified]`

   **Good examples** (each has a clear test):
   - `- [ ] User can log in with fingerprint in <2s` → UI test
   - `- [ ] API returns 401 for invalid tokens` → Integration test
   - `- [ ] Database persists user session for 24h` → Integration test
   - `- [ ] App handles network errors gracefully` → Unit test

   **Bad examples** (too vague, no clear test):
   - ❌ "Authentication is secure" → What test proves this?
   - ❌ "Code is well-structured" → Not testable
   - ❌ "Performance is good" → Not measurable

**Keep it minimal** - Only what's absolutely essential to call this feature "done"

---

## Phase 4: High-Level Technical Approach

**Keep it concise - 3 sections max:**

1. **Architecture** (1-2 sentences): How we'll build this at a high level
   - Example: "Add OAuth2 middleware to auth service, integrate with existing user flow"
   - NO file paths or code details

2. **Key Changes** (3-5 bullets): Major components/areas affected
   - Example: "Authentication service", "User profile UI", "Token storage"
   - Keep high-level, describe WHAT not WHERE

3. **Risks** (2-3 max): Real blockers with mitigation
   - Example: "OAuth providers may rate-limit → implement retry with backoff"

**Optional**: Read `.claude/skills/impl-patterns.md` for platform patterns

---

## Phase 5: High-Level Implementation Phases

**3-5 logical phases max:**

1. Each phase = logical group of work (WHAT needs doing)
2. One sentence description per phase
3. Mark complexity: S (simple), M (medium), L (complex)
4. Always include Testing phase

**Example:**
```markdown
## Implementation

### Phase 1: Foundation (M)
Set up OAuth2 service structure and configuration

### Phase 2: Core Logic (L)
Implement OAuth2 flow and token management

### Phase 3: Integration (M)
Connect with existing user service and UI

### Phase 4: Testing (M)
Unit and integration tests for auth flows
```

**Keep it high-level** - No file paths, no code details. `/prdx:dev:start` adds those automatically.

---

## Phase 6: Create PRD

Use Write tool to create `.claude/prds/[platform]-[prd-slug].md`:

**IMPORTANT**: PRDs should be stored in `.claude/prds/` directory.

**Simple 1-pager format** (fits on one screen):

```markdown
# [Feature Title]

**Project**: [platform] | **Status**: draft | **Created**: [YYYY-MM-DD] | **Branch Type**: [feat|fix|refactor|spike]
**Dependencies**: [#issue-numbers or "none"] | **Blocks**: [#issue-numbers or "none"]

## Goal

[1-2 sentences: What are we building and why?]

## Acceptance Criteria

**Each criterion must have a corresponding test (unit/integration/manual)**

- [ ] [Testable outcome 1] → [Test type]
- [ ] [Testable outcome 2] → [Test type]
- [ ] [Testable outcome 3] → [Test type]

## Approach

**Architecture**: [1-2 sentences on high-level approach]

**Key Changes**:
- [Component/area 1 that needs work]
- [Component/area 2 that needs work]
- [Component/area 3 that needs work]

**Risks**:
- [Risk 1]: [mitigation]
- [Risk 2]: [mitigation]

## Implementation

### Phase 1: [Name] (S/M/L)
[What needs to be done - high level, no file paths]

### Phase 2: [Name] (S/M/L)
[What needs to be done - high level, no file paths]

### Phase 3: Testing (S/M/L)
[What testing is needed]
```

**PRD Guidelines**:
- **Keep it simple**: Entire PRD should fit on one screen/page
- **No sections beyond these**: Goal, Acceptance Criteria (3-5), Approach, Implementation (3-5 phases)
- **High-level only**: No file paths, API contracts, or code details here
- **Business-focused**: Describe WHAT and WHY, not HOW
- **Acceptance Criteria MUST be testable**: Every AC needs a corresponding test (unit/integration/manual)
- **ACs come BEFORE solution**: Define success criteria before designing implementation
- **Detailed plans later**: `/prdx:dev:start` adds technical details automatically

**Type-specific additions**:

**Bug Fix**: Add after Goal section:
```markdown
## Bug Details
**Severity**: [Critical/High/Medium/Low]
**Reproduce**: [steps]
**Expected**: [behavior]
**Actual**: [behavior]
```

**Spike**: Add after Goal section:
```markdown
## Research
**Question**: [what we need to answer]
**Decision**: [what this will inform]
**Timebox**: [hours/days]
```

---

## Phase 7: Multi-Agent Review

**Invoke specialized review agents in parallel:**

Launch three review agents concurrently using Task tool:

### 1. Technical Review Agent
```
Task(
  subagent_type="code-reviewer",
  prompt="Review PRD at [path] for technical correctness.

  Use prd-review skill: .claude/skills/prd-review.md (if available)

  Check:
  - Platform-specific patterns followed
  - Common pitfalls avoided
  - Architecture aligns with project
  - Technical approach is sound

  Return structured feedback: Strengths, Concerns, Suggestions, Blockers"
)
```

### 2. QA/Testing Review Agent
```
Task(
  subagent_type="code-reviewer",
  prompt="Review PRD at [path] for testability.

  Use testing-strategy skill: .claude/skills/testing-strategy.md (if available)

  Check:
  - Acceptance criteria are testable
  - Testing phase is comprehensive
  - Test coverage goals defined
  - Edge cases covered

  Return structured feedback with specific test scenarios to add"
)
```

### 3. Security/Performance Review Agent
```
Task(
  subagent_type="performance-optimizer",
  prompt="Review PRD at [path] for security and performance.

  Check:
  - Security implications identified
  - Performance considerations included
  - Data handling is secure
  - API rate limiting considered (backend)
  - Memory management considered (mobile)

  Return structured feedback with risks and mitigations"
)
```

**Wait for all agents to complete**, then consolidate feedback.

---

## Phase 8: Apply Improvements Inline

**Update PRD with agent feedback using Edit tool:**

Integrate improvements from all three agents:

**Problem/Goal:**
- Add missing user impact
- Clarify vague objectives
- Add overlooked scenarios

**Approach:**
- Add missing integration points
- Address security/performance concerns
- Include error handling strategies
- Apply platform-specific patterns

**Implementation:**
- Add missing steps
- Clarify dependencies
- Add test scenarios from QA agent
- Include security checks

**Acceptance Criteria:**
- Make more specific/testable per QA feedback
- Add edge cases
- Add non-functional requirements

**Risks:**
- Add security/performance risks identified
- Improve mitigation strategies

**IMPORTANT**:
- Use Edit tool for each section individually
- Integrate improvements naturally - should feel original
- Never create a separate "Review Notes" section
- Consolidate similar feedback from multiple agents

---

## Phase 9: Post-Planning Hook (Optional)

**If post-plan hook exists, run it:**

```bash
bash .claude/hooks/prd/post-plan.sh "[PRD_FILE_PATH]" "[PLATFORM]"
```

Hook can:
- Confirm PRD creation
- Show PRD statistics
- Suggest next steps
- Trigger notifications (customizable)

---

## Phase 10: Summary & Next Steps

**Show final summary:**

```
✓ Enhanced PRD Created & Multi-Agent Reviewed!

File: [filename]
Location: .claude/prds/
Platform: [backend/android/ios/web/mobile/etc]

Task count: [N tasks]
Complexity: [X simple, Y medium, Z complex]
Acceptance Criteria: [N items] (concise!)

Agent Reviews Completed:
✓ Technical Review - [key findings]
✓ QA/Testing Review - [key findings]
✓ Security/Performance Review - [key findings]

Key Improvements Applied:
- [Improvement 1]
- [Improvement 2]
- [Improvement 3]

Skills Used:
✓ impl-patterns.md - Platform-specific patterns
✓ prd-review.md - Review checklists
✓ testing-strategy.md - Test scenarios

Hooks Executed:
✓ pre-plan.sh - Environment validation
✓ post-plan.sh - Next steps + notifications

Next steps:
- Review the PRD at [location]
- Run /prdx:publish [slug] to publish to GitHub (optional)
- Run /prdx:dev [slug] to begin implementation (creates detailed plan automatically)
- Or edit PRD manually if needed
```

**STOP HERE - DO NOT START IMPLEMENTATION**

This command's job is complete. The PRD has been created.

To start implementation, the user must explicitly run:
```bash
/prdx:dev [slug]
```

---

## Important Rules

- **STOP AFTER PRD CREATION** - Do NOT start implementation, do NOT continue to coding
- **THIS IS PLANNING ONLY** - Creates PRD file and exits
- **ASK before assuming** - clarify unclear requirements
- **ROUTE to specialized agents** - backend-developer/android-developer/ios-developer
- **USE skills** - leverage impl-patterns, prd-review, testing-strategy
- **RUN hooks** - pre-plan and post-plan for automation
- **PARALLEL agent review** - technical, QA, security/performance simultaneously
- **BE SPECIFIC** - reference actual files and patterns
- **STAY FOCUSED** - 3-5 acceptance criteria max, no Notes section
- **UPDATE INLINE** - no review notes, direct improvements

**CRITICAL**: After Phase 10 (Summary), this command is DONE. Show next steps, then STOP.
- **NATURAL INTEGRATION** - read as if always there

---

## Differences from /prdx:plan

**Enhanced Features:**
- ✅ Agent routing (platform-specific agents)
- ✅ Skills integration (patterns, review, testing)
- ✅ Hooks system (pre/post automation)
- ✅ Multi-agent review (technical, QA, security/performance)
- ✅ High-level implementation phases (business-focused)

**Simplified:**
- ✅ Stricter content limits (3-5 acceptance criteria)
- ✅ No Notes section
- ✅ More concise throughout
- ✅ Separated business planning from technical planning

**Result:**
- Faster PRD creation with better quality
- Leverages specialized agent knowledge
- Clear separation: business requirements (here) vs technical details (`/prdx:dev:plan`)
