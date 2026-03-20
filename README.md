# PRDX

> PRD workflow for Claude Code leveraging native plan mode

PRDX is a [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code) that provides a PRD (Product Requirements Document) workflow using Claude's **native plan mode**, platform-specific agents, hooks, and skills.

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
│               Status: planning ────────────────► .prdx/plans/prdx-*.md     │
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
│  │  Phase C: Review (isolated contexts)                                  │  │
│  │                                                                       │  │
│  │  1. prdx:ac-verifier                                                  │  │
│  │     • Verifies acceptance criteria (code exists, test exists, covers) │  │
│  │     • If ACs unmet: platform agent fixes, re-verify (max 3 attempts) │  │
│  │                                                                       │  │
│  │  2. prdx:code-reviewer                                                │  │
│  │     • Flags bugs, security issues, quality problems                   │  │
│  │     • If issues found: platform agent fixes, re-review (max 2 cycles) │  │
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

## Quick Start

### Installation

```bash
# Claude Code plugin marketplace (recommended)
/plugin marketplace add kuuuurt/prdx
/plugin install prdx@prdx
```

### One Command Workflow

```bash
/prdx:prdx "add biometric authentication to Android app"
```

This orchestrates the entire workflow with decision points at each phase.
Plans auto-save to `.prdx/plans/prdx-{slug}.md`.
Stop anytime and resume with `/prdx:prdx <slug>`.

### Quick Mode

For one-off tasks that don't need a permanent PRD:

```bash
/prdx:prdx --quick "fix login validation"
```

Same pipeline (dev-planner, code review) but with a lightweight PRD that's cleaned up after.

### Individual Commands

```bash
/prdx:plan "add biometric auth"          # Create PRD
/prdx:implement android-biometric-auth   # Implement feature
/prdx:push android-biometric-auth        # Create PR
```

## CI Mode

Run PRDX from GitHub Actions or any CI environment. PRDX handles planning and implementation — the CI workflow handles PR and issue management.

```bash
# Plan only (generate PRD, commit, push branch)
/prdx:prdx --ci --issue 42 --plan-only --requested-by username

# Implement (read PRD from branch, implement, push)
/prdx:implement {slug}
```

### Responsibility Boundaries

| Step | Local Mode | CI Mode |
|------|-----------|---------|
| **Plan** | | |
| Explore codebase | PRDX | PRDX |
| Generate PRD | PRDX (plan mode) | PRDX (direct write) |
| Create branch | PRDX | PRDX |
| Commit & push PRD | PRDX | PRDX |
| Revise PRD from feedback | PRDX (user iterates in plan mode) | PRDX (reads PR comments) |
| Commit authorship | Config (`prdx.json`) | `--requested-by` flag |
| **Publish** | | |
| Create draft PR (PRD review) | — | **Workflow** |
| PR title/body | — | **Workflow** |
| Comment on issue | PRDX (`/prdx:publish`) | **Workflow** |
| **Implement** | | |
| Dev-plan, implement, review | PRDX | PRDX |
| Commit implementation | PRDX | PRDX |
| Push branch | PRDX | PRDX |
| Run tests | PRDX (post-implement hook) | PRDX (post-implement hook) |
| Commit authorship | Config (`prdx.json`) | `--requested-by` flag |
| **Push** | | |
| Create draft PR (implementation) | PRDX (`/prdx:push --draft`) | **Workflow** (update existing draft) |
| PR title/body | PRDX (pr-author agent) | **Workflow** |

PRDX outputs branch name, slug, and PRD file path. The CI workflow consumes those to manage PRs and issues.

### Setup

1. Configure plans directory (one-time, interactive):
   ```bash
   /prdx:config plans local
   ```

2. Ensure GitHub CLI is authenticated in your CI environment.

3. Install the workflow:
   ```bash
   /prdx:setup-github-actions
   ```
   Or manually copy `examples/workflows/claude-code.yml` to your repo's `.github/workflows/`.

### Reference Workflow

See [`examples/workflows/claude-code.yml`](examples/workflows/claude-code.yml) for a complete GitHub Actions workflow that implements the CI flow:

```
issue → @claude plan → draft PR with PRD → @claude revise / @claude implement → @claude review → human review
```

### What CI mode does differently

- Skips all interactive prompts (no "Implement now?" / "Create PR?" decision points)
- Fetches issue title + body as the feature description
- Auto-detects platform from codebase
- `--requested-by` sets commit author (Claude Code + GitHub Actions as co-authors)
- **Does NOT** create PRs, comment on issues, or manage PR state — that's the workflow's job
- Requires pre-configured plans directory (`.prdx/plans-setup-done` must exist)

## Installation

### Option 1: GitHub Marketplace (Recommended)

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
| `/prdx:push` | Create pull request (supports `--draft`) |

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
| `/prdx:setup-github-actions` | Install CI workflow in current repo |

## Why This Approach?

**Native plan mode** handles PRD creation — plans auto-save to `.prdx/plans/prdx-*.md`.

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

## Multi-Platform Support

For features spanning multiple platforms, PRDX uses a parent-child model:

```bash
/prdx:prdx "add biometric authentication"
# → Creates parent PRD + child PRDs (one per platform)
# → Each child gets its own branch and PR
# → Implementation Order controls sequencing
# → Children on the same step can run in parallel sessions
```

## Agents

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Workflow Agents                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│  prdx:dev-planner    │ Creates detailed technical implementation plans     │
│  prdx:ac-verifier    │ Verifies acceptance criteria (3-point check)       │
│  prdx:code-reviewer  │ Reviews diff for bugs, security, quality           │
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

## Configuration

```bash
/prdx:config minimal     # Conventional commits, no extras
/prdx:config standard    # Full attribution (default)
/prdx:config simple      # Simple commits with attribution
/prdx:config plans local # Store plans in project directory (.prdx/plans/)
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
- **GitHub CLI** (`gh`) — Optional, for GitHub integration (required for CI mode)

## License

MIT License

---

**Made with care by Kurt** · [GitHub](https://github.com/kuuuurt/prdx)
