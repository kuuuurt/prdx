# PRDX

> PRD workflow for Claude Code leveraging native plan mode

PRDX is a Claude Code plugin that provides PRD (Product Requirements Document) workflow using Claude's **native plan mode**, platform-specific agents, hooks, and skills.

## The Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           /prdx:prdx "feature"                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. PLAN (native plan mode)                                                 │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Claude's native plan mode                                            │  │
│  │  • Explores codebase architecture                                     │  │
│  │  • Assesses feasibility                                               │  │
│  │  • Creates PRD with branch name                                       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              ▼                                              │
│                    ┌─────────────────┐                                      │
│                    │  Approve PRD?   │                                      │
│                    └────────┬────────┘                                      │
│                             │ yes                                           │
│                             ▼                                               │
│               Status: planning ────────────────► ~/.claude/plans/prdx-*.md  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                         ┌────────────┴────────────┐
                         ▼                         ▼
                   [Publish?]               [Implement?]
                         │                         │
                         ▼                         │
              ┌──────────────────┐                 │
              │ GitHub Issue #N  │                 │
              └──────────────────┘                 │
                         │                         │
                         └────────────┬────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  2. IMPLEMENT (three-phase)                                                 │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Phase A: prdx:dev-planner agent (isolated context)                   │  │
│  │  • Reads skills (impl-patterns, testing-strategy)                     │  │
│  │  • Creates detailed technical plan                                    │  │
│  │  • Maps tests to acceptance criteria                                  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              ▼                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Phase B: Platform agent (isolated context)                           │  │
│  │  • prdx:backend-developer   OR                                        │  │
│  │  • prdx:frontend-developer  OR                                        │  │
│  │  • prdx:android-developer   OR                                        │  │
│  │  • prdx:ios-developer                                                 │  │
│  │                                                                       │  │
│  │  Executes dev plan with TDD:                                          │  │
│  │  1. Write failing test                                                │  │
│  │  2. Implement to pass                                                 │  │
│  │  3. Commit                                                            │  │
│  │  4. Repeat                                                            │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              ▼                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Phase C: prdx:code-reviewer agent (isolated context)                 │  │
│  │  • Reviews diff against acceptance criteria                           │  │
│  │  • Flags bugs, security issues, quality problems                      │  │
│  │  • If issues found: platform agent fixes, re-review (max 2 cycles)   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              ▼                                              │
│               Status: in-progress → review                                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  3. REVIEW                                                                  │
│                                                                             │
│     ┌─────────────────────────────────────────────────────────────────┐     │
│     │                     User tests implementation                   │     │
│     └─────────────────────────────────────────────────────────────────┘     │
│                                      │                                      │
│              ┌───────────────────────┴───────────────────────┐              │
│              ▼                                               ▼              │
│     ┌─────────────────┐                             ┌─────────────────┐     │
│     │   Bugs found    │                             │   Looks good    │     │
│     └────────┬────────┘                             └────────┬────────┘     │
│              │                                               │              │
│              ▼                                               │              │
│     ┌─────────────────┐                                      │              │
│     │  Describe bugs  │                                      │              │
│     │  Claude fixes   │◄─────────────────┐                   │              │
│     │  Commit fixes   │                  │                   │              │
│     └────────┬────────┘                  │                   │              │
│              │                           │                   │              │
│              └───────► Test again ───────┘                   │              │
│                                                              │              │
│                              Status: review                  │              │
└──────────────────────────────────────────────────────────────┼──────────────┘
                                                               │
                                                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  4. PUSH                                                                    │
│                                                                             │
│     ┌─────────────────────────────────────────────────────────────────┐     │
│     │               "Is implementation ready?" ──► Yes                │     │
│     └─────────────────────────────────────────────────────────────────┘     │
│                              ▼                                              │
│               Status: review → implemented                                  │
│                              ▼                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  prdx:pr-author agent (isolated context)                              │  │
│  │  • Analyzes commits                                                   │  │
│  │  • Creates comprehensive PR description                               │  │
│  │  • Executes: gh pr create                                             │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              ▼                                              │
│                    Pull Request #N created                                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  5. COMPLETE (automatic on next /prdx:prdx startup)                          │
│                                                                             │
│     Detects merged PR → captures lessons → cleans up                        │
│                              ▼                                              │
│               Status: implemented → completed                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Status Flow

```
planning ──► in-progress ──► review ──► implemented ──► completed
    │              │            │              │              │
    ▼              ▼            ▼              ▼              ▼
PRD created    Coding...   User tests    PR created    PR merged
               + code      Fix bugs      Ready to      All done!
               review      if needed     merge

Optional: /prdx:publish adds GitHub issue link at any status (metadata, not a workflow state)
```

## Why This Approach?

**Native plan mode** handles PRD creation - plans auto-save to `~/.claude/plans/prdx-*.md`.

**Context-isolated agents** handle implementation, keeping the main conversation lightweight:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Main Conversation (stays small)                                            │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  • Dev plan summary (~3KB)                                              ││
│  │  • Implementation summary (~1KB)                                        ││
│  │  • Code review summary (~2KB)                                           ││
│  │  • PR URL (~100B)                                                       ││
│  │  ────────────────────────────                                           ││
│  │  Total: ~6KB                                                            ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Agent Contexts (isolated, discarded after use)                             │
│                                                                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │
│  │ prdx:dev-planner │  │ Platform agent   │  │ prdx:code-       │         │
│  │                  │  │                  │  │ reviewer         │         │
│  │ • Skills content │  │ • All source     │  │                  │         │
│  │ • Codebase       │  │   files read     │  │ • Diff analysis  │         │
│  │   patterns       │  │ • Test files     │  │ • AC validation  │         │
│  │ • Task breakdown │  │ • Build output   │  │ • Quality checks │         │
│  │                  │  │                  │  │                  │         │
│  │ Returns: Plan    │  │ Returns: Summary │  │ Returns: Review  │         │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 1 PRD = 1 Branch = 1 PR

```
┌────────────────────────────────────────────────────────────────────────────┐
│  PRD: android-biometric-auth                                               │
│  Branch: feat/android-biometric-auth                                       │
│  PR: #42                                                                   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  main ─────●─────────────────────────────────────────────────●──────────   │
│            │                                                 │             │
│            │  feat/android-biometric-auth                    │             │
│            └────●────●────●────●────●────●────●─────────────►│             │
│                 │    │    │    │    │    │    │       PR #42 │             │
│                 │    │    │    │    │    │    │              │             │
│              commit commit  ... commits  ...  fix         merge            │
│              (TDD)  (TDD)       (TDD)        (review)                      │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### One Command Workflow

```bash
/prdx:prdx "add biometric authentication to Android app"
```

This orchestrates the entire workflow with decision points at each phase.
Plans auto-save to `~/.claude/plans/prdx-{slug}.md`.
Stop anytime and resume with `/prdx:prdx <slug>`.

### Individual Commands

```bash
/prdx:plan "add biometric auth"          # Create PRD
/prdx:implement android-biometric-auth   # Implement feature
/prdx:push android-biometric-auth        # Create PR
```

## Installation

### Option 1: GitHub Marketplace

```bash
/plugin marketplace add kuuuurt/prdx
/plugin install prdx@prdx
```

### Option 2: Local Development

```bash
git clone https://github.com/kuuuurt/prdx.git ~/prdx
/plugin marketplace add ~/prdx
/plugin install prdx-local@prdx
```

### Option 3: Symlink

```bash
git clone https://github.com/kuuuurt/prdx.git
ln -s "$(pwd)/prdx" ~/.claude/plugins/prdx
```

## Commands

### Main Workflow

| Command | Description |
|---------|-------------|
| **`/prdx:prdx`** | **Complete workflow orchestrator (recommended)** |
| `/prdx:plan` | Create PRD |
| `/prdx:implement` | Implement feature |
| `/prdx:push` | Create pull request |

### Standalone (no PRD required)

| Command | Description |
|---------|-------------|
| `/prdx:commit` | Create commit using prdx.json config |
| `/prdx:simplify` | Simplify code with pragmatic cleanup |
| `/prdx:push` | Also works standalone (auto-detects PRD or creates PR from commits) |

### Management

| Command | Description |
|---------|-------------|
| `/prdx:show` | View/list/search PRDs |
| `/prdx:config` | Configure settings |
| `/prdx:publish` | Create GitHub issue from PRD |

## Agents

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Workflow Agents                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│  prdx:dev-planner    │ Creates detailed technical implementation plans     │
│  prdx:code-reviewer  │ Reviews diff against acceptance criteria            │
│  prdx:pr-author      │ Creates comprehensive PR descriptions              │
├─────────────────────────────────────────────────────────────────────────────┤
│  Platform Agents (framework-agnostic, discovers stack from codebase)       │
├─────────────────────────────────────────────────────────────────────────────┤
│  prdx:backend-developer   │ Backend implementation (any framework)         │
│  prdx:frontend-developer  │ Frontend/web implementation (any framework)    │
│  prdx:android-developer   │ Android implementation (Kotlin/Compose)        │
│  prdx:ios-developer       │ iOS implementation (Swift/SwiftUI)             │
├─────────────────────────────────────────────────────────────────────────────┤
│  Exploration Agents (keeps main context clean)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  prdx:code-explorer  │ Explores codebase patterns and architecture        │
│  prdx:docs-explorer  │ Searches web/Context7 for library documentation    │
└─────────────────────────────────────────────────────────────────────────────┘

Note: PRD creation uses Claude's native plan mode (not a custom agent).
```

## PRD Structure

PRDs are stored in `~/.claude/plans/` with `prdx-` prefix:

```markdown
# Feature Title

**Type:** feature | bug-fix | refactor | spike
**Platform:** backend | frontend | android | ios | mobile
**Platforms:** android, ios (only for mobile - lists target platforms)
**Status:** planning | in-progress | review | implemented | completed
**Created:** YYYY-MM-DD
**Branch:** feat/feature-slug

## Problem
[What pain point exists?]

## Goal
[What outcome do we want?]

## User Stories
- As a [user type], I want to [action] so that [benefit]

## Acceptance Criteria
- [ ] [Testable outcome]

## Scope
### Included / ### Excluded

## Approach
[High-level strategy]

## Risks & Considerations
```

## Configuration

```bash
/prdx:config minimal     # Conventional commits, no extras
/prdx:config standard    # Full attribution (default)
/prdx:config simple      # Simple commits with attribution
```

Or create `prdx.json`:

```json
{
  "commits": {
    "format": "conventional",
    "coAuthor": { "enabled": true },
    "extendedDescription": { "enabled": true }
  }
}
```

## Requirements

- **Claude Code** (claude.ai/code)
- **Git repository**
- **GitHub CLI** (`gh`) - Optional, for GitHub integration

## License

MIT License

---

**Made with care by Kurt** · [GitHub](https://github.com/kuuuurt/prdx)
