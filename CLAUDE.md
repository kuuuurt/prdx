# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PRDX is a Claude Code plugin that provides a PRD (Product Requirements Document) workflow leveraging Claude Code's **native plan mode**. Plans are saved automatically by Claude to `~/.claude/plans/` and serve as the single source of truth for feature development.

## Core Philosophy

**Leverage Native Claude Code Features:**
- **Plan mode** handles codebase exploration and PRD creation (plans auto-saved)
- **Platform agents** (backend/android/ios) handle implementation
- **Hooks** provide validation gates
- **Skills** provide knowledge bases
- **TodoWrite** tracks implementation progress
- Commands are **thin wrappers** that orchestrate

**No Custom Orchestration:**
- Don't reinvent plan storage (use native plan mode)
- Don't create custom task tracking (use TodoWrite)
- Don't write custom validation (use hooks)
- Let Claude's native features do the work

## Plan Mode Configuration

PRDX uses Claude's default plans directory (`~/.claude/plans/`).

**Naming convention:** `prdx-{slug}.md` to distinguish PRDX plans from regular plans.

## PRD Format (Plan Mode Template)

**IMPORTANT:** When entering plan mode for PRDX workflows, use this exact format for plans:

```markdown
# [Title]

**Type:** feature | bug-fix | refactor | spike
**Platform:** backend | android | ios | mobile
**Platforms:** android, ios (only for mobile - list target platforms)
**Status:** planning | in-progress | review | implemented | completed
**Created:** [YYYY-MM-DD]
**Branch:** feat/[slug] | fix/[slug] | refactor/[slug] | chore/[slug]

## Problem

[What pain point or opportunity exists? Why does this matter?]

## Goal

[What outcome do we want? Express in terms of user/business benefit.]

## User Stories

- As a [user type], I want to [action] so that [benefit]

## Acceptance Criteria

- [ ] [User-observable outcome - testable]
- [ ] [User-observable outcome - testable]

## Scope

### Included
- [What this PRD covers]

### Excluded
- [What this PRD explicitly does NOT cover]

## Approach

[High-level strategy - general direction, NOT detailed dev tasks]

## Risks & Considerations

- [Technical/business risks and constraints]
```

**Branch naming convention:**
- `feature` type → `feat/{slug}`
- `bug-fix` type → `fix/{slug}`
- `refactor` type → `refactor/{slug}`
- `spike` type → `chore/{slug}`

**Status workflow:**
1. `planning` - Initial state, plan being created
2. `in-progress` - Implementation started
3. `review` - Implementation done, awaiting user testing
4. `implemented` - User confirmed ready, PR created
5. `completed` - PR merged

**To update status:** Edit the `**Status:**` line in the plan file directly.

## Repository Structure

```
prdx/
├── .claude-plugin/          # Plugin metadata
│   ├── plugin.json
│   └── marketplace.json
├── commands/                # Thin wrapper commands
│   ├── prdx.md              # Main entry point (/prdx:prdx)
│   ├── plan.md              # Uses native plan mode
│   ├── implement.md         # Triggers platform agent
│   ├── show.md              # View/list/search PRDs
│   ├── push.md              # Create PR
│   ├── close.md             # Close PRD
│   ├── publish.md           # Create GitHub issue
│   ├── sync.md              # Sync with GitHub
│   ├── optimize.md          # Code cleanup/simplification
│   └── help.md              # Documentation
├── hooks/prdx/              # Validation hooks
│   ├── pre-plan.sh          # Pre-planning validation
│   ├── pre-implement.sh     # Pre-implementation validation
│   ├── post-implement.sh    # Post-implementation actions
│   └── post-edit-optimize.sh # Auto-optimize on file changes
├── skills/                  # Knowledge bases (read by agents)
│   ├── prd-review.md        # Review checklist
│   ├── impl-patterns.md     # Implementation patterns
│   └── testing-strategy.md  # Testing approaches
├── agents/                  # Specialized agents
│   ├── dev-planner.md       # Technical planning (isolated context)
│   ├── pr-author.md         # PR creation (isolated context)
│   ├── code-reviewer.md     # Code review (isolated context)
│   ├── backend-developer.md # Backend expert (discovers stack)
│   ├── frontend-developer.md # Frontend/web expert (discovers stack)
│   ├── android-developer.md # Kotlin/Compose expert
│   ├── ios-developer.md     # Swift/SwiftUI expert
│   ├── code-explorer.md     # Codebase exploration (isolated context)
│   └── docs-explorer.md     # Documentation search (isolated context)
└── install.sh               # Installation script
```

## Workflow

### Complete Feature Development (One Command)

```
/prdx:prdx "add biometric authentication"
↓
Plan Mode → PRD saved → [Publish?] → Publish → [Implement?] → Implement → Review → [Ready?] → PR
```

**For mobile features targeting both platforms:**
```
/prdx:prdx "add biometric authentication"
↓
Plan Mode (asks: Android & iOS, Android only, or iOS only?)
↓
PRD saved to ~/.claude/plans/
↓
[Publish?] → Publish (optional)
↓
[Implement?] → Implement Android → [Continue to iOS?] → Implement iOS
↓
Review (test, fix bugs if needed)
↓
[Ready?] → PR
```

The `/prdx:prdx` command is the main entry point, orchestrating the workflow with decision points.

**1 PRD = 1 Branch = 1 PR:** Each PRD gets a unique branch name at planning time. All implementation happens on that branch, and the PR is created from it.

### Individual Commands

```
1. Create Plan (uses native plan mode)
   /prdx:plan "add biometric authentication"
   ↓
   - Enters plan mode
   - Explores codebase
   - Creates PRD using the template format
   - User iterates until approval
   - Plan auto-saved to ~/.claude/plans/{slug}.md
   - Status: planning

2. Publish to GitHub (optional)
   /prdx:publish {slug}
   ↓
   - Creates GitHub issue from PRD
   - Updates PRD with issue number
   - Status stays unchanged (publish is metadata, not a workflow state)

3. Implement Feature
   /prdx:implement {slug}
   /prdx:implement {slug} android  (for multi-platform: Android only)
   /prdx:implement {slug} ios      (for multi-platform: iOS only)
   ↓
   - Reads PRD from ~/.claude/plans/
   - Updates status to in-progress
   - Checks out PRD's designated branch
   - prdx:dev-planner agent creates dev plan
   - Platform agent executes dev plan
   - Updates status to review

5. Review Implementation
   (Status: review)
   ↓
   - User tests the implementation
   - If bugs found: describe issues, Claude fixes them
   - Resume with /prdx:prdx {slug} to get fix/push options

6. Create Pull Request
   /prdx:push {slug}
   ↓
   - Updates status to implemented
   - prdx:pr-author agent creates PR
   - Appends PR metadata to PRD
```

**Status tracking:** Status is stored in the PRD file itself (`**Status:**` field) and updated by editing the file directly.

### Standalone Commands (No PRD Required)

These commands work independently of the PRDX workflow for quick, ad-hoc work:

```
/prdx:commit "fix typo"       # Commit with prdx.json config (format, co-author, etc.)
/prdx:optimize src/auth/      # Code cleanup on any files
/prdx:push                    # Create PR from current branch (auto-detects PRD if one exists)
```

**`/prdx:push` auto-detection:** When called without a slug, it checks if the current branch matches any PRD. If yes, uses PRD mode with full context. If no, uses standalone mode and creates a PR purely from commits/diff analysis.

### Key Features

**Native Plan Mode:**
- Uses Claude's built-in plan mode for PRD creation
- Plans auto-saved to `~/.claude/plans/`
- No custom file management needed
- Interactive iteration until approval

**Status in Plan File:**
- Status tracked in the `**Status:**` field of each PRD
- Updated by editing the file directly
- Workflow: planning → in-progress → review → implemented → completed

**Context-Isolated Agents:**
- `prdx:dev-planner`: Technical planning with files/tasks/tests
- `prdx:pr-author`: PR creation with comprehensive description
- Platform agents: TDD implementation execution

**Three-Phase Implementation:**
- Dev-planner agent first: Creates detailed technical plan
- Platform agent second: Executes the plan using TDD
- Code reviewer third: Validates diff against acceptance criteria

**Hooks for Validation:**
- `pre-implement.sh` - Validates PRD completeness, branch state
- `post-implement.sh` - Runs tests, updates status to `review`

**Platform Agents for Execution:**
- Each agent specializes in one platform
- Executes the dev plan
- Uses TodoWrite for task tracking
- Follows TDD and creates conventional commits

## Commands (Thin Wrappers)

### /prdx:prdx (Main Entry Point)

**What it does:**
1. Determines entry point (new feature or existing PRD)
2. Runs `/prdx:plan` for planning (uses native plan mode)
3. Asks: Implement now? → runs `/prdx:implement`
4. Asks: Create PR? → runs `/prdx:push`

**Usage:**
- `/prdx:prdx add user authentication` - Start new feature
- `/prdx:prdx biometric-login` - Resume existing PRD

**Key features:**
- Main entry point for all PRDX workflows
- Decision points at each phase (never auto-proceeds)
- Resumes from current status when given existing PRD
- Shows context and next steps at each decision

### /prdx:plan

**What it does:**
1. Detects platform from description/codebase
2. Enters native plan mode
3. Uses `prdx:code-explorer` and `prdx:docs-explorer` agents for codebase/docs exploration (keeps main context clean)
4. Creates PRD using template format
5. Iterates with user until approval
6. Calls ExitPlanMode immediately when user approves (do NOT ask "should I exit plan mode?")
7. Plan auto-saved to `~/.claude/plans/`

**Uses:** Native plan mode (not an isolated agent)

**Exploration:** MUST use `prdx:code-explorer` and `prdx:docs-explorer` agents (NOT direct Glob/Grep/Read, NOT built-in Explore subagent)

**Focus:** Recon, feasibility, business context, high-level approach (not detailed dev tasks)

### /prdx:implement

**What it does:**
1. Loads PRD file
2. Runs `pre-implement.sh` hook
3. Sets up git branch
4. Invokes `prdx:dev-planner` agent (isolated) for detailed planning
5. Invokes platform agent (isolated) to execute dev plan
6. Invokes `prdx:code-reviewer` agent (isolated) to validate implementation
7. If issues found: platform agent fixes, re-review (max 2 cycles)
8. Runs `post-implement.sh` hook (runs tests, updates status)
9. Appends implementation summary to PRD

**Agents used (all isolated):**
- `prdx:dev-planner` → returns dev plan (~3KB)
- Platform agent → returns summary (~1KB)
- `prdx:code-reviewer` → returns review summary (~2KB)

**Why three agents:** Dev-planner creates the roadmap; platform agent executes it; code reviewer catches issues before user handoff.

### /prdx:push

**What it does:**
1. Auto-detects PRD mode or standalone mode
2. Validates git state
3. Invokes `prdx:pr-author` agent (isolated context)
4. Agent creates PR via `gh` CLI
5. Returns only PR URL and number (~100B)

**Modes:**
- **PRD mode** (slug provided or matching PRD found): Full workflow with status updates, branch validation, PRD-enriched PR description
- **Standalone mode** (no matching PRD): Creates PR from commits/diff analysis only, no PRD interaction

**Agent used:** `prdx:pr-author` (isolated context)

### Other Commands

- `/prdx:show` - List/search/view PRDs (bash + grep)
- `/prdx:close` - Update PRD status to completed
- `/prdx:publish` - Create GitHub issue from PRD
- `/prdx:sync` - Sync PRD with GitHub issue

### Standalone-Capable Commands

These work with or without a PRD:
- `/prdx:commit` - Commit with prdx.json config (always standalone)
- `/prdx:optimize` - Code cleanup (always standalone)
- `/prdx:push` - Auto-detects PRD or standalone mode

## Agents

Agents run in **isolated contexts** to minimize main conversation size.

### Workflow Agents

**1. prdx:dev-planner**
- Reads skills (impl-patterns.md, testing-strategy.md)
- Explores codebase for patterns
- Creates detailed implementation plan
- Maps tests to acceptance criteria
- **Returns:** Dev plan only (~3KB)

**2. prdx:pr-author**
- Reads PRD and analyzes commits
- Generates comprehensive PR description
- Executes `gh pr create`
- Updates PRD with PR metadata
- **Returns:** PR URL and number only (~100B)

**3. prdx:code-reviewer**
- Reviews diff against acceptance criteria
- Flags bugs, security issues, quality problems
- Only reports high-confidence issues (>80%)
- **Returns:** Review summary (~2KB)

**Note:** PRD creation uses native plan mode instead of a custom agent.

### Platform Agents

**1. prdx:backend-developer**
- Framework-agnostic backend expert
- Discovers stack from codebase (package.json, etc.)
- API development, validation, services
- Adapts to project's framework and patterns
- **Returns:** Implementation summary (~1KB)

**2. prdx:frontend-developer**
- Framework-agnostic frontend/web expert
- Discovers stack from codebase (React, Vue, Svelte, Next.js, etc.)
- Component development, state management, data fetching
- Adapts to project's styling and patterns
- **Returns:** Implementation summary (~1KB)

**3. prdx:android-developer**
- Kotlin + Jetpack Compose expert
- Discovers DI/persistence from build.gradle
- MVVM architecture, StateFlow
- Adapts to project's libraries
- **Returns:** Implementation summary (~1KB)

**4. prdx:ios-developer**
- Swift + SwiftUI expert
- Discovers dependencies from Package.swift/Podfile
- MVVM, async/await, NavigationStack
- Adapts to project's libraries
- **Returns:** Implementation summary (~1KB)

**What platform agents do:**
- Receive dev plan from dev-planner
- Use TodoWrite to track tasks
- Implement with TDD
- Create conventional commits
- Return brief summary

**What they DON'T do:**
- Explore codebase (dev-planner already did this)
- Return full file contents
- Manage files outside implementation
- Handle git operations (command does this)
- Custom orchestration (they just implement)

### Exploration Agents

**1. prdx:code-explorer**
- Explores codebase to understand patterns
- Traces execution paths and dependencies
- Maps architecture layers
- **Returns:** Summary + key code snippets (~3KB)

**2. prdx:docs-explorer**
- Searches web and Context7 for documentation
- Prioritizes official sources
- Synthesizes from multiple sources
- **Returns:** Summary + key examples (~3KB)

**What exploration agents do:**
- Run in isolated context (keeps full content internally)
- Return concise summaries for main conversation
- Save context by not dumping full files/pages

**IMPORTANT:** During PRDX workflows (plan, implement), ALWAYS use `prdx:code-explorer` and `prdx:docs-explorer` agents instead of:
- Direct Glob/Grep/Read for codebase exploration
- The built-in `Explore` subagent type
This keeps the main context window clean.

### Context Efficiency

**Plan mode benefits:**
- Exploration happens in plan mode context
- Plan is saved to file, not kept in conversation
- Conversation context stays minimal

**Agent isolation benefits:**
- Dev-planner and platform agents run isolated
- File contents stay in agent's context
- Main conversation receives summaries only

## Skills (Knowledge Bases)

Skills are read by agents during execution:

**1. prd-review.md**
- Platform-specific review checklist
- Architecture validation points
- Common pitfalls
- Security/performance/accessibility checks

**2. impl-patterns.md**
- Backend: API patterns, middleware, validation
- Android: Repository patterns, Compose UI, state management
- iOS: ViewModel patterns, SwiftUI views, navigation

**3. testing-strategy.md**
- Unit testing frameworks by platform
- Integration testing patterns
- UI testing strategies
- Test coverage standards

**How agents use them:**
- `prdx:dev-planner` reads during technical planning
- Platform agents read during implementation
- Natural skill lookup, no custom code

## Hooks (Validation Gates)

### pre-plan.sh

**Runs before:** `/prdx:plan`

**Validates:**
- Git repository exists
- `~/.claude/plans/` directory exists
- PRDs are in `.gitignore`

**On failure:** Stops planning

### pre-implement.sh

**Runs before:** `/prdx:implement`

**Validates:**
- PRD file exists and has required sections
- PRD is not already completed
- Git branch is correct (or creates it)
- No uncommitted changes (or warns)

**On failure:** Stops implementation

### post-implement.sh

**Runs after:** `/prdx:implement`

**Validates:**
- Runs project tests (auto-detects test runner)
- If tests fail: blocks status change, agent must fix

**Updates:**
- PRD status to "review" (user must confirm before PR creation)
- Implementation timestamp

**On failure:** Blocks if tests fail; warns for other issues

### post-edit-optimize.sh

**Runs after:** Edit/Write tool usage on source files

**Behavior:**
- Detects changed lines via `git diff`
- Outputs `additionalContext` prompting optimization
- Only triggers for source files (`.kt`, `.swift`, `.ts`, etc.)

**Enable for your project:**
```bash
/prdx:config hooks enable auto-optimize
```

## Auto-Optimize Hook

When you see `PRDX Auto-Optimize:` in context, apply optimization rules:
1. Check the specified lines for optimization opportunities
2. Remove documentation-style comments (keep `// MARK:`, `// TODO:`, why-comments)
3. Inline single-use variables when expression is clear
4. Inline single-use private functions when simple (1-3 lines)
5. Apply changes with Edit tool, or continue if no optimizations needed

## PRD Structure

PRDs are business-focused documents that define **what** and **why**, not **how**:

```markdown
# [Title]

**Type:** feature | bug-fix | refactor | spike
**Platform:** backend | android | ios | mobile
**Platforms:** android, ios (only for mobile - lists target platforms)
**Status:** planning | in-progress | review | implemented | completed
**Created:** [DATE]
**Branch:** [BRANCH_NAME]

## Problem

[What pain point or opportunity exists? Why does this matter?]

## Goal

[What outcome do we want? Express in terms of user/business benefit.]

## User Stories

- As a [user type], I want to [action] so that [benefit]
- As a [user type], I want to [action] so that [benefit]

## Acceptance Criteria

- [ ] [User-observable outcome]
- [ ] [User-observable outcome]
- [ ] [User-observable outcome]

## Scope

### Included
- [What this PRD covers]

### Excluded
- [What this PRD explicitly does NOT cover]

## Approach

[High-level strategy - general direction, not detailed dev tasks]

## Risks & Considerations

- [Technical feasibility risk]
- [Business or user-facing risk]
- [Dependency or constraint]

---
## Implementation Notes (android)

**Branch:** [BRANCH]
**Implemented:** [DATE]

[Added by Android agent after implementation]

---
## Implementation Notes (ios)

**Branch:** [BRANCH]
**Implemented:** [DATE]

[Added by iOS agent after implementation - only for multi-platform mobile PRDs]

---
## Pull Request

**Created:** [DATE]
**Number:** #[PR_NUMBER]
**URL:** [PR_URL]
```

**Key points:**
- PRD is business-focused with high-level approach (no detailed dev tasks)
- `/prdx:implement` uses Plan agent for detailed dev planning first
- Platform agent then executes the dev plan
- Implementation notes added after development
- After implementation, status becomes `review` (not `implemented`)
- User tests and can request bug fixes while in `review` status
- `/prdx:push` confirms readiness, sets status to `implemented`, then creates PR
- PR metadata added by `/prdx:push`

## Development Guidelines

### When Modifying Commands

1. **Keep commands thin** - Delegate to agents or bash
2. **Use hooks for validation** - Don't inline validation logic
3. **Let agents do the work** - Don't orchestrate manually
4. **Use native tools** - Plan agent, TodoWrite, etc.

**Example - GOOD:**
```markdown
1. Run pre-plan hook
2. Detect platform
3. Invoke Plan agent with prompt
4. Display plan
5. Write PRD file after approval
```

**Example - BAD:**
```markdown
1. Search codebase manually with Grep/Glob
2. Parse files to understand architecture
3. Create plan structure with custom logic
4. Multi-agent orchestration with complex coordination
5. Custom iteration state management
```

### When Modifying Agents

1. **Agents do one thing well** - Platform-specific implementation
2. **Read skills naturally** - Reference `.claude/skills/*.md`
3. **Use TodoWrite** - Track tasks from PRD
4. **Return summaries** - For command to append to PRD
5. **No orchestration** - Just implement

### When Modifying Skills

1. **Skills are knowledge bases** - Not executable code
2. **Platform-specific sections** - Clear separation
3. **Pattern examples** - Show, don't tell
4. **Best practices** - Security, performance, accessibility

### When Modifying Hooks

1. **Hooks are bash scripts** - Simple validation
2. **Exit codes matter** - 0 = success, non-zero = failure
3. **User interaction OK** - Can prompt for confirmation
4. **Optional but recommended** - Commands work without them

## Installation Methods

**Marketplace Install** (Recommended):
```bash
/plugin marketplace add kuuuurt/prdx
/plugin install prdx@prdx
```

**Direct Symlink:**
```bash
ln -s "$(pwd)/prdx" ~/.claude/plugins/prdx
```

**Install Script:**
```bash
./install.sh  # Copies to project's .claude/ directory
```

## Key Differences from Complex Approaches

### What We DON'T Do

❌ Custom plan storage (use native plan mode)
❌ Direct codebase exploration in main context (use prdx:code-explorer/docs-explorer agents)
❌ Manual multi-agent orchestration (one agent per phase)
❌ Separate state management (status in plan file)
❌ Custom task tracking (use TodoWrite)
❌ TDD review checkpoints (code reviewer validates after implementation)

### What We DO

✅ Use native plan mode for PRD creation
✅ Store status in plan file directly
✅ One agent per implementation phase
✅ Hooks for validation gates
✅ Skills as passive knowledge bases
✅ TodoWrite for task visibility
✅ Interactive approval in plan mode
✅ Thin commands that orchestrate native tools

## Testing

1. **Test commands** - Invoke Plan/platform agents correctly
2. **Test hooks** - Validation logic works
3. **Test agents** - Follow patterns from skills
4. **Test skills** - Agents can read and apply them

## Customization

### For Different Tech Stacks

**Modify agents** to match your stack:
```bash
# Example: Express instead of Hono for backend
vim agents/backend-developer.md
```

Update agent's:
- Framework expertise
- Architecture patterns
- Code examples
- Testing approaches

**Update skills** with your patterns:
```bash
vim skills/impl-patterns.md
```

Add your:
- Code conventions
- Architecture decisions
- Testing frameworks
- Best practices

**Commands stay the same** - They just trigger agents.

### Remove Unused Platforms

```bash
# Backend-only project
rm agents/android-developer.md
rm agents/ios-developer.md
```

Commands automatically adapt to available agents.

## Related Documentation

- README.md: User-facing installation and usage guide
- install.sh: Manual installation script
- Plugin homepage: https://github.com/kuuuurt/prdx
