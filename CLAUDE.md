# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PRDX is a Claude Code plugin that provides a complete PRD (Product Requirements Document) workflow system for feature development. It's designed to be installed as a plugin and includes commands, skills, and AI agents for managing the full development lifecycle from planning through implementation to deployment.

## Repository Structure

```
prdx/
├── .claude-plugin/          # Plugin metadata and marketplace config
│   ├── plugin.json          # Plugin manifest with version and structure
│   └── marketplace.json     # Private marketplace configuration
├── commands/                # 14 PRD workflow commands
│   ├── wizard.md            # Interactive PRD creation wizard
│   ├── plan.md              # Agent-powered feature planning
│   ├── list.md              # List all PRDs
│   ├── search.md            # Search PRDs by keyword
│   ├── update.md            # Update existing PRD
│   ├── close.md             # Close completed PRD
│   ├── publish.md           # Create GitHub issue from PRD
│   ├── sync.md              # Sync PRD with GitHub issue
│   ├── status.md            # Status dashboard
│   ├── deps.md              # Dependency management
│   ├── help.md              # Documentation
│   └── dev/                 # Development workflow commands
│       ├── start.md         # Start implementation with auto-planning
│       ├── check.md         # Verify implementation quality
│       └── push.md          # Create pull request
├── skills/                  # 3 specialized knowledge bases
│   ├── prd-review.md        # Platform-specific review patterns
│   ├── impl-patterns.md     # Implementation patterns by platform
│   └── testing-strategy.md  # Testing approaches
├── agents/                  # 3 platform-specific AI agents
│   ├── backend-developer.md # TypeScript/Hono/Bun expert
│   ├── android-developer.md # Kotlin/Compose expert
│   └── ios-developer.md     # Swift/SwiftUI expert
└── install.sh               # Installation script for manual setup
```

## Architecture

### Command System

Commands are organized as slash commands (`/prdx:*`) following a workflow-based structure:

**Core Workflow Commands:**
- `/prdx:wizard` - Interactive PRD creation with guided steps
- `/prdx:plan` - Agent-powered business-level PRD planning with multi-agent review
- `/prdx:dev:start` - Implementation (auto-creates detailed plan if needed) with prompt support
- `/prdx:dev:check` - Multi-agent verification
- `/prdx:dev:push` - Automated PR creation

**Management Commands:**
- List, search, update, close PRDs
- GitHub integration (publish, sync)
- Status dashboard and dependency tracking

### Agent System

PRDX includes three platform-specific AI agents that are invoked via the Task tool:

1. **backend-developer**: TypeScript/Hono expert
   - API development with OpenAPI integration
   - Zod validation and type safety
   - Cloud Run deployment patterns
   - External service integration

2. **android-developer**: Kotlin/Jetpack Compose expert
   - MVVM architecture (no Use Cases - deprecated)
   - Repository pattern with Hilt DI
   - Compose UI and Material Design 3
   - Clean Architecture principles

3. **ios-developer**: Swift/SwiftUI expert
   - MVVM with ObservableObject
   - NavigationStack patterns
   - Async/await and Combine
   - SwiftUI lifecycle management

### Skills System

Skills provide specialized knowledge bases that agents reference during PRD creation and review:

1. **prd-review.md**: Platform-specific review checklist
   - Architecture validation
   - Common pitfalls by platform
   - Security, performance, accessibility checks
   - Multi-project impact analysis

2. **impl-patterns.md**: Implementation patterns
   - Backend: API patterns, middleware, validation
   - Android: Repository patterns, Compose UI, state management
   - iOS: ViewModel patterns, SwiftUI views, navigation

3. **testing-strategy.md**: Testing approaches
   - Unit testing frameworks by platform
   - Integration testing patterns
   - UI testing strategies
   - Test coverage standards

## Key Workflows

### PRD Creation Flow (Simple 1-Pager)

```
/prdx:wizard or /prdx:plan
    ↓
Platform detection → PRD type selection → Gather requirements
    ↓
Search for duplicates → Identify dependencies
    ↓
Create simple PRD (fits on 1 screen):
  - Goal (1-2 sentences)
  - Acceptance Criteria (3-5 items)
  - Approach (Architecture + Key Changes + Risks)
  - Implementation (3-5 high-level phases)
    ↓
Multi-agent review (Technical, QA, Security)
    ↓
Apply improvements inline → Simple business-level PRD created
```

**PRD Structure** (1-pager):
- Metadata (status, dependencies, branch type)
- Goal (what & why)
- Acceptance Criteria (testable outcomes - MUST have corresponding tests)
- Approach (architecture, key changes, risks)
- Implementation (high-level phases only)

**Critical Rule**: Every Acceptance Criterion must map to a specific test (unit/integration/manual)

### Implementation Flow

```
/prdx:dev:start [slug] [optional prompt]
    ↓
Load PRD → Check for detailed implementation plan
    ↓
If prompt provided: Ask user (Update PRD / Update Plan / Continue)
    ↓
If plan missing or needs update:
  Platform agent creates/updates detailed plan inline:
  - Specific file paths
  - API contracts / data models
  - Code patterns
  - Risk assessment
  - Testing strategy
  Add "## Detailed Implementation Plan" to PRD
    ↓
Setup git branch → Execute implementation from plan
    ↓
Test → Finalize → Update PRD status
```

### Key Features of /prdx:dev:start

- **Auto-planning**: Creates detailed plan inline if missing
- **Prompt support**: Accepts instructions for continuing/updating work
- **Smart updates**: Can invoke `/prdx:update` for PRD changes
- **Plan preservation**: Updates plans with strikethrough for history
- **Task tracking**: Marks completed tasks, preserves history
- **Conventional commits**: Enforces proper commit format

### Separation of Concerns

**`/prdx:plan` (Business Level - 1 Pager)**:
- Goal (1-2 sentences: what & why)
- Acceptance Criteria (3-5 testable outcomes)
- Approach (architecture, key changes, risks)
- Implementation (3-5 high-level phases)
- **Fits on one screen** - no code details or file paths

**`/prdx:dev:start` (Technical Level - Detailed Plan)**:
- Specific files to create/modify
- API contracts and data models
- Code patterns from impl-patterns skill
- Task-by-task breakdown with file paths
- Testing strategy with test files
- **Created automatically** when starting implementation

## Development Guidelines

### When Modifying Commands

1. **Commands are markdown files** with instructions for Claude Code
2. **Use structured phases** (Phase 1, Phase 2, etc.) for complex workflows
3. **Include Usage section** at the top with examples
4. **Reference agents and skills** by their file paths
5. **Use Task tool** to invoke platform-specific agents
6. **Document options** clearly with `--flag` format

### When Modifying Agents

1. **Frontmatter is critical**: name, description, model, color
2. **Description section** shows when the agent should be used
3. **Include examples** of when to invoke the agent
4. **Core Principles section** defines the agent's approach
5. **Technical Guidelines** specify platform-specific patterns
6. **Implementation Workflow** provides step-by-step guidance

### When Modifying Skills

1. **Skills are knowledge bases** read by agents during execution
2. **Platform-specific sections** for backend/Android/iOS
3. **Checklist format** for review-focused skills
4. **Pattern examples** for implementation-focused skills
5. **Cross-platform concerns** like security and accessibility

### Plugin Manifest

The `.claude-plugin/plugin.json` defines the plugin structure:

```json
{
  "name": "prdx",
  "version": "0.1.0",
  "commands": "./commands",
  "skills": "./skills",
  "agents": "./agents"
}
```

**Version update checklist:**
1. Update version in `plugin.json`
2. Update version in `README.md` changelog
3. Update marketplace.json if needed
4. Tag git commit with version

## Installation Methods

PRDX supports multiple installation methods:

1. **Marketplace Install** (Recommended):
   ```bash
   /plugin marketplace add kuuuurt/prdx
   /plugin install prdx@prdx
   ```

2. **Direct Symlink**:
   ```bash
   ln -s "$(pwd)/prdx" ~/.claude/plugins/prdx
   ```

3. **Install Script**: Copies files to project's `.claude/` directory
   ```bash
   ./install.sh
   ```

## Testing Changes

Since this is a plugin for Claude Code, testing involves:

1. **Test in development**:
   - Symlink to `~/.claude/plugins/prdx`
   - Test commands in a sample project with `.claude/prds/` directory

2. **Verify command structure**:
   - Check frontmatter format (description, argument-hint)
   - Test parameter parsing
   - Verify agent invocations

3. **Test agent routing**:
   - Ensure agents receive correct context
   - Validate skill references work
   - Check agent output integration

4. **Test workflows end-to-end**:
   - Create PRD with `/prdx:wizard`
   - Plan with `/prdx:plan`
   - Implement with `/prdx:dev:start`
   - Verify with `/prdx:dev:check`

## Common Tasks

### Adding a New Command

1. Create `commands/new-command.md`
2. Add frontmatter with description and argument-hint
3. Structure as phases with clear instructions
4. Reference existing agents/skills
5. Document usage examples
6. Update README.md command list

### Adding a New Agent

1. Create `agents/new-agent.md`
2. Add frontmatter: name, description, model, color
3. Include usage examples in description
4. Define core principles and guidelines
5. Specify when to invoke the agent
6. Update README.md agent list

### Customizing for Different Tech Stacks

The plugin is designed to be customizable:

1. **Modify agents**: Edit agent files to match your stack
2. **Update skills**: Adjust patterns and review checklists
3. **Customize commands**: Modify routing logic in plan/dev commands
4. **Remove unused agents**: Delete mobile agents if backend-only

Example: Converting to Express.js backend
- Edit `agents/backend-developer.md`
- Replace Hono patterns with Express patterns
- Update `skills/impl-patterns.md` with Express examples
- Keep same command structure

## Important Notes

- **Commands invoke agents**: Use Task tool with subagent_type
- **Skills are passive**: Agents read them, they don't execute
- **PRDs live in user projects**: Not in this repo
- **PRDs are NEVER committed**: PRD files remain in `.claude/prds/` only, never committed to git
- **PRDs are 1-pagers**: Simple format that fits on one screen (Goal, AC, Approach, Implementation)
- **CRITICAL: No test = No AC**: Every Acceptance Criterion MUST have a corresponding test
- **ACs before solution**: Define testable success criteria before designing implementation
- **Adaptive workflow**: Automatically detects Full-Stack vs Single-Platform projects
- **Two-level planning**: `/prdx:plan` for business (1-pager), `/prdx:dev:start` creates technical plan inline
- **Plan storage**: Detailed plans live in PRD as `## Detailed Implementation Plan` section
- **Auto-planning**: `/prdx:dev:start` creates detailed plan if missing (Phase 3-4)
- **AC-to-test mapping**: Detailed plans include explicit mapping of ACs to tests
- **Conventional commits**: All commits follow `type: description` format (implementation code only)
- **No co-authors**: PRD system doesn't add co-author tags
- **Strikethrough for history**: Use `~~old~~` → new in plan updates
- **Multi-agent review**: Technical, QA, Security agents review in parallel

## Adaptive Workflow

PRDX adapts to your project structure:

### Full-Stack Projects (Multiple Platforms)

```
project-root/
├── .claude/prds/     # Centralized PRDs
├── backend/
├── android/
└── ios/
```

**Behavior**:
- PRDs can span multiple platforms (e.g., `backend-android-biometric.md`)
- `/prdx:plan` can invoke multiple agents in parallel for context
- `/prdx:dev:start` asks which platform(s) to implement
- Can implement platforms incrementally (backend first, then mobile)
- Branch names include platform: `feat/backend-123-auth`

### Single-Platform Projects (Dedicated Repos)

```
backend-repo/
├── .claude/prds/     # Backend-only PRDs
├── src/
└── ...
```

**Behavior**:
- PRDs scoped to current platform only
- Other platforms treated as external dependencies
- Single agent invoked for context
- Branch names: `feat/123-auth` (no platform prefix needed)
- Simpler workflow focused on one platform

## Branch Strategy

All commands use branch type metadata from PRD:
- `feat/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `chore/` or `spike/` - Research/spikes

Branch naming format: `<type>/<platform>-<issue-or-slug>`
Example: `feat/android-219-biometric-login`

## GitHub Integration

Commands that use GitHub CLI (`gh`):
- `/prdx:publish` - Creates GitHub issue from PRD
- `/prdx:sync` - Syncs PRD with existing issue
- `/prdx:dev:push` - Creates pull request

Requires: `gh` CLI installed and authenticated

## Dependencies

- Claude Code (claude.ai/code)
- Git repository
- Optional: GitHub CLI (`gh`) for publish/sync commands

## Related Documentation

- Plugin homepage: https://github.com/kuuuurt/prdx
- README.md: User-facing installation and usage guide
- install.sh: Manual installation script with backups
