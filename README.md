# PRDX

> PRD workflow for Claude Code leveraging native tooling

PRDX is a Claude Code plugin that provides PRD (Product Requirements Document) workflow using native Plan agents, platform-specific agents, hooks, and skills.

## Features

**Leverages Claude Code Native Tools**
- **Plan agent** for codebase exploration and planning
- **Platform agents** for implementation
- **Hooks** for validation gates
- **Skills** as knowledge bases
- **TodoWrite** for task tracking
- Thin wrapper commands that orchestrate

**Multi-Platform Development Support**
- Backend development (TypeScript, Hono, BFF patterns)
- Android development (Kotlin, Jetpack Compose, Clean Architecture)
- iOS development (Swift, SwiftUI, MVVM)

**1 PRD = 1 Branch = 1 PR**
- Each PRD gets a unique branch at planning time
- All implementation happens on that branch
- One pull request per PRD

**What's Inside**
- 12 commands for the complete workflow
- 6 specialized agents (planner, dev-planner, pr-author, 3 platform agents)
- 3 validation hooks (pre-plan, pre-implement, post-implement)
- 3 skills (impl-patterns, testing-strategy, prd-review)

## Installation

### Option 1: Local Marketplace (Recommended for Development)

Clone the repo and add it as a local marketplace:

```bash
# Clone the repository
git clone https://github.com/kuuuurt/prdx.git ~/prdx

# In Claude Code, add the local marketplace
/plugin marketplace add ~/prdx
```

Then install the plugin:

```bash
/plugin install prdx-local@prdx
```

### Option 2: Install from GitHub Marketplace

```bash
# Add the PRDX marketplace
/plugin marketplace add kuuuurt/prdx

# Install the plugin
/plugin install prdx@prdx
```

### Option 3: Symlink to Plugins Directory

```bash
# Clone the repository
git clone https://github.com/kuuuurt/prdx.git

# Link to Claude Code plugins directory
ln -s "$(pwd)/prdx" ~/.claude/plugins/prdx
```

Claude Code will automatically load the plugin.

## Quick Start

### One Command Workflow

Use `/prdx:prdx` for the complete workflow - it orchestrates everything with decision points:

```bash
/prdx:prdx "add biometric authentication to Android app"
```

This single command will:
1. **Plan** → Planner agent explores codebase, creates PRD, asks for approval
2. **Ask** → Publish to GitHub? Implement now? Stop here?
3. **Implement** → Dev-planner creates technical plan, platform agent implements with TDD
4. **Ask** → Create PR now?
5. **Push** → Creates PR with comprehensive description

You can stop at any decision point and resume later with `/prdx:prdx <slug>`.

### Individual Commands

For more control, use individual commands:

```bash
/prdx:config standard                    # Configure settings (optional)
/prdx:plan "add biometric auth"          # Create PRD
/prdx:implement android-biometric-auth   # Implement feature
/prdx:push android-biometric-auth        # Create PR
```

## Available Commands

### Main Workflow

| Command | Description |
|---------|-------------|
| **`/prdx:prdx [description\|slug]`** | **Complete workflow orchestrator (recommended)** |
| `/prdx:plan <description>` | Create PRD (triggers planner agent) |
| `/prdx:implement <slug>` | Implement feature (triggers dev-planner + platform agent) |
| `/prdx:push <slug>` | Create pull request (triggers pr-author agent) |
| `/prdx:commit [message]` | Create commit with configured format |

### Configuration & Management

| Command | Description |
|---------|-------------|
| `/prdx:config [preset\|show\|set\|get]` | Configure PRDX settings |
| `/prdx:show [slug]` | View/list PRDs |
| `/prdx:close <slug>` | Close completed PRD |
| `/prdx:migrate` | Migrate from .claude to .prdx folder |

### GitHub Integration

| Command | Description |
|---------|-------------|
| `/prdx:publish <slug>` | Create GitHub issue from PRD |
| `/prdx:sync <slug>` | Sync PRD with GitHub issue |

### Code Quality

| Command | Description |
|---------|-------------|
| `/prdx:optimize [files]` | Simplify code (defaults to changed files on branch) |

### Help

| Command | Description |
|---------|-------------|
| `/prdx:help` | Show documentation |

## Agents

| Agent | Purpose |
|-------|---------|
| `prdx:planner` | Explores codebase, creates business-focused PRDs |
| `prdx:dev-planner` | Creates detailed technical implementation plans |
| `prdx:pr-author` | Creates comprehensive PR descriptions |
| `prdx:backend-developer` | TypeScript/Hono implementation expert |
| `prdx:android-developer` | Kotlin/Compose implementation expert |
| `prdx:ios-developer` | Swift/SwiftUI implementation expert |

## Configuration

### Quick Setup

```bash
/prdx:config minimal     # Conventional commits, no co-author/links
/prdx:config standard    # Full attribution (default)
/prdx:config simple      # Simple commits with attribution
```

### Configuration File

Create `prdx.json` in project root or `.prdx/prdx.json`:

```json
{
  "version": "1.0",
  "commits": {
    "format": "conventional",
    "coAuthor": {
      "enabled": true,
      "name": "Claude",
      "email": "noreply@anthropic.com"
    },
    "extendedDescription": {
      "enabled": true,
      "includeClaudeCodeLink": true
    }
  },
  "pullRequest": {
    "defaultBase": "main",
    "autoAssign": true
  }
}
```

### Configuration Locations

PRDX looks for configuration in order:
1. `./prdx.json` (project root)
2. `./.prdx/prdx.json` (PRDX directory)

## Workflow Example

```bash
# 1. Plan feature
/prdx:plan "add OAuth2 authentication"
# → Planner explores codebase
# → Creates PRD with Branch: feat/backend-oauth2-auth
# → Asks for approval

# 2. Implement
/prdx:implement backend-oauth2-auth
# → Checks out feat/backend-oauth2-auth
# → Dev-planner creates technical plan
# → Platform agent implements with TDD
# → Creates commits

# 3. Create PR
/prdx:push backend-oauth2-auth
# → Validates branch matches PRD
# → Creates PR with comprehensive description
```

## PRD Structure

PRDs are stored in `.prdx/prds/`:

```markdown
# Feature Title

**Type:** feature | bug-fix | refactor | spike
**Platform:** backend | android | ios | mobile
**Status:** planning | in-progress | implemented | completed
**Created:** 2025-01-13
**Branch:** feat/feature-slug

## Problem
[What pain point exists?]

## Goal
[What outcome do we want?]

## User Stories
- As a [user], I want to [action] so that [benefit]

## Acceptance Criteria
- [ ] [Testable outcome]

## Scope
### Included / ### Excluded

## Approach
[High-level strategy]

## Risks & Considerations
```

## Package Contents

```
prdx/
├── .claude-plugin/          # Plugin metadata
├── commands/                # Workflow commands
│   ├── prdx.md              # Main orchestrator
│   ├── plan.md              # Planning
│   ├── implement.md         # Implementation
│   ├── push.md              # PR creation
│   ├── commit.md            # Commit helper
│   ├── config.md            # Configuration
│   ├── show.md              # View PRDs
│   ├── close.md             # Close PRD
│   ├── publish.md           # GitHub issue
│   ├── sync.md              # GitHub sync
│   ├── migrate.md           # Migration tool
│   └── help.md              # Documentation
├── agents/                  # Specialized agents
│   ├── planner.md           # PRD creation
│   ├── dev-planner.md       # Technical planning
│   ├── pr-author.md         # PR creation
│   ├── backend-developer.md
│   ├── android-developer.md
│   └── ios-developer.md
├── hooks/prdx/              # Validation hooks
│   ├── pre-plan.sh
│   ├── pre-implement.sh
│   └── post-implement.sh
├── skills/                  # Knowledge bases
│   ├── impl-patterns.md
│   ├── testing-strategy.md
│   └── prd-review.md
└── README.md
```

## Requirements

- **Claude Code** (claude.ai/code)
- **Git repository**
- **GitHub CLI** (`gh`) - Optional, for publish/sync commands

## License

MIT License

---

**Made with care by Kurt**

[GitHub](https://github.com/kuuuurt/prdx)
