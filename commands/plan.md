| description | argument-hint |
| Enhanced PRD planning with agent routing, skills, and multi-agent review | Feature name or brief description [--type TYPE] [--depends-on ISSUE] |

# Enhanced Feature Planning (PRD2)

> **Agent-powered workflow with auto-routing, skills integration, and collaborative review**
> Leverages specialized agents, hooks, and skills for faster, smarter PRD creation

## Usage

```bash
/prdx:plan <feature-description> [options]
```

## Options

- `--type <type>` - PRD type: `feature` (default), `bug-fix`, `refactor`, `spike`
- `--depends-on <issue>` - Dependencies: issue number(s) or PRD slug(s) (comma-separated)

## Examples

```bash
/prdx:plan "add biometric login"
/prdx:plan "fix memory leak" --type bug-fix
/prdx:plan "refactor auth flow" --type refactor --depends-on #215,#218
/prdx:plan "investigate performance" --type spike
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

**Parse parameters and detect project:**

1. **Parse command-line options**:
   - Extract `--type` parameter (default: `feature`)
   - Extract `--depends-on` parameter (parse comma-separated values)
   - Valid types: `feature`, `bug-fix`, `refactor`, `spike`

2. **Determine branch type** for conventional commits:
   - `feature` → branch prefix: `feat/`
   - `bug-fix` → branch prefix: `fix/`
   - `refactor` → branch prefix: `refactor/`
   - `spike` → branch prefix: `spike/` (or `chore/` if preferred)

3. **Detect project structure** (critical for adaptive workflow):

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

4. **Determine platform scope**:

   **For Full-Stack projects**:
   - Ask user which platform(s) this PRD affects
   - Can be single (backend) or multiple (backend+android)
   - PRD coordinates work across platforms

   **For Single-Platform projects**:
   - Platform = current project automatically
   - Other platforms referenced as external only

5. Create PRD slug based on project structure:
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

6. **Ask clarifying questions** (don't proceed without answers):
   - For all types:
     - What problem are we solving?
     - Who experiences this problem?
   - For bug-fix:
     - Steps to reproduce?
     - Expected vs actual behavior?
   - For refactor:
     - Current pain points?
     - Future work this enables?
   - For spike:
     - Research question to answer?
     - Decision this will inform?
     - Time box (hours/days)?

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

1. **Primary goal**: 1 sentence, specific and measurable

2. **Acceptance criteria**: 3-5 testable requirements (STRICTER than /prdx:plan)
   - Use format: `- [ ] As [user], I can [action] so that [benefit]`
   - Cover: architecture, functional, error handling, non-functional
   - Keep FOCUSED - only essential criteria (5th criterion is optional, remove if not needed)

3. **Out of scope**: What we're explicitly NOT doing (optional)

---

## Phase 4: High-Level Technical Approach

**Define business-level technical approach:**

**Optional**: Read skill if it exists: `.claude/skills/impl-patterns.md`

Use skill (if available) to:
- Understand established project patterns
- Apply platform-specific best practices
- Identify correct high-level architecture approach

**Define approach:**

1. **Architecture**: 1-2 sentences on high-level approach
   - Focus on architectural decisions and patterns
   - NO specific file paths or code structure

2. **Key components**: Bullet list of major components/areas that need work
   - Examples: "Authentication service", "User profile UI", "Data sync layer"
   - Keep high-level, describe WHAT not WHERE

3. **Risks**: Top 2-3 risks with mitigation strategies
   - Focus on real blockers, not hypotheticals

---

## Phase 5: High-Level Implementation Phases

**Break down into logical implementation phases:**

1. Create 3-5 logical phases that group related work
2. Each phase describes WHAT needs to be done (not HOW)
3. Keep descriptions high-level and conceptual
4. Mark overall phase complexity: S (simple), M (medium), L (complex)
5. Include testing phase

**Example structure:**
```markdown
## Implementation

### Phase 1: Foundation (M)
Set up authentication service structure and base configuration

### Phase 2: Core Logic (L)
Implement OAuth2 flow and token management

### Phase 3: Integration (M)
Connect with existing user service and frontend

### Phase 4: Testing (M)
Unit and integration tests for auth flows

### Phase 5: Documentation (S)
API documentation and integration guide
```

**IMPORTANT**: This is **business-level planning**, not code-level.
- Focus on logical work phases, not specific files
- Describe outcomes, not implementation details
- No file paths, no API contracts, no code patterns
- Detailed technical planning happens in `/prdx:dev:start` automatically

---

## Phase 6: Create PRD

Use Write tool to create `.claude/prds/[platform]-[prd-slug].md`:

**IMPORTANT**: PRDs should be stored in `.claude/prds/` directory.

**Use the selected template** (from Phase 1):
- Feature: `templates/feature-template.md`
- Bug Fix: `templates/bug-fix-template.md`
- Refactor: `templates/refactor-template.md`
- Spike: `templates/spike-template.md`

**Add metadata**:
- Platform, Status (draft), Created date
- **Dependencies**: Add from `--depends-on` parameter (or "none")
- **Blocks**: Leave empty initially (or "none")
- **Related**: Leave empty initially (or "none")
- **Branch Type**: Store the branch prefix (feat, fix, refactor, spike) for later use

Example metadata line:
```markdown
**Project**: android | **Status**: draft | **Created**: 2025-11-07 | **Branch Type**: fix
**Dependencies**: #215, #218 | **Blocks**: none | **Related**: none
```

**Implementation section guidelines:**
- High-level phases only (WHAT, not HOW)
- No specific file paths or code details
- Business/feature-focused descriptions
- Use `/prdx:dev:plan` later for technical details

Key differences from older workflows:
- Acceptance Criteria: 3-5 items (more concise)
- No Notes section (removed from template)
- No detailed implementation plan (use `/prdx:dev:plan` for that)
- Type-specific templates with tailored sections

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
- Run /prdx:dev:start [slug] to begin implementation (creates detailed plan automatically)
- Or edit PRD manually if needed
```

**Interactive Q&A:**
1. Ask if they want to discuss any agent feedback
2. Offer to refine specific sections further
3. Remind them PRD is ready for implementation

---

## Important Rules

- **ASK before assuming** - clarify unclear requirements
- **ROUTE to specialized agents** - backend-developer/android-developer/ios-developer
- **USE skills** - leverage impl-patterns, prd-review, testing-strategy
- **RUN hooks** - pre-plan and post-plan for automation
- **PARALLEL agent review** - technical, QA, security/performance simultaneously
- **BE SPECIFIC** - reference actual files and patterns
- **STAY FOCUSED** - 3-5 acceptance criteria max, no Notes section
- **STRICTER content limits** - more concise than /prdx:plan
- **ONE PHASE = ONE COMMIT** - keep work atomic
- **UPDATE INLINE** - no review notes, direct improvements
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
