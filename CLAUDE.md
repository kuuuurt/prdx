# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PRDX is a Claude Code plugin that provides a PRD (Product Requirements Document) workflow leveraging Claude Code's **native plan mode**. Plans are saved locally to `.prdx/plans/` as a working copy; in CI mode the authoritative PRD is stored as a GitHub issue comment.

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

Plans are stored locally in a configurable directory (default `.prdx/plans/`). The entire `.prdx/` directory is gitignored. Projects can override the plans directory via the `plansDirectory` property in `prdx.json` (e.g. `"plansDirectory": "docs/plans"`).

On first run, PRDX auto-creates the plans directory and sets `plansDirectory` in `.claude/settings.local.json` so Claude Code's native plan mode saves to the right place. A `.prdx/plans-setup-done` marker prevents repeated setup.

**Naming convention:** `prdx-{slug}.md` for normal PRDs, `prdx-quick-{slug}.md` for quick mode (ephemeral).

### Canonical PLANS_DIR Resolution (use everywhere in hooks and commands)

All hooks and commands MUST use this snippet to resolve the plans directory. Do not hardcode `.prdx/plans`.

```bash
PROJECT_ROOT="${PRDX_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE=""
SEARCH_DIR="$PROJECT_ROOT"
while [ "$SEARCH_DIR" != "/" ]; do
  [ -f "$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/prdx.json" && break
  [ -f "$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done
PLANS_SUBDIR=$(jq -r '.plansDirectory // ".prdx/plans"' "$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="$PROJECT_ROOT/$PLANS_SUBDIR"
```

### Gitignore Management

Use this pattern for `.gitignore` updates:

```bash
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ ! -f "$GITIGNORE" ] || ! { grep -qxF '.prdx/' "$GITIGNORE" || grep -qxF '.prdx/*' "$GITIGNORE"; }; then
  echo '' >> "$GITIGNORE"
  echo '# PRDX' >> "$GITIGNORE"
  echo '.prdx/' >> "$GITIGNORE"
fi
```

## PRD Format (Plan Mode Template)

**IMPORTANT:** When entering plan mode for PRDX workflows, use the appropriate format based on mode:

### Full Template (Normal Mode)

```markdown
# [Title]

**Type:** feature | bug-fix | refactor | spike
**Project:** [git remote repo name]
**Platform:** backend | frontend | android | ios
**Platforms:** backend, android, ios (when multiple platforms)
**Implementation Order:**
1. backend
2. android, ios
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

Rules for Platform fields:
- **Single platform:** Use `**Platform:**` and `**Branch:**`. Omit `**Platforms:**` and `**Implementation Order:**`.
- **Multiple platforms (parent PRD):** Use `**Platforms:**` and `**Implementation Order:**`. Omit `**Platform:**` and `**Branch:**` (parent is orchestration-only, each child has its own branch).
- **Implementation Order:** Only present when `**Platforms:**` has 2+ entries. Numbered steps. Platforms on the same step are independent (can run in parallel sessions). Steps execute sequentially.
- **Project:** Always include `**Project:**` with the git remote repo name. Auto-detected via `gh repo view --json name --jq '.name'`, falling back to repo directory name.
- **Parent (child PRDs only):** Add `**Parent:** {parent-slug}` below `**Platform:**` when this PRD is a child of a multi-platform parent. Omit for parent PRDs and single-platform PRDs.

### Quick Template (`--quick` Mode)

Used for ephemeral tasks. Saved as `prdx-quick-{slug}.md` and cleaned up after workflow completes.

```markdown
# [Title]

**Type:** bug-fix | feature | refactor
**Project:** [git remote repo name]
**Platform:** {DETECTED_PLATFORM}
**Quick:** true
**Status:** planning
**Created:** [YYYY-MM-DD]
**Branch:** [current branch via `git branch --show-current`]

## Problem

[1-2 sentences]

## Goal

[1 sentence]

## Acceptance Criteria

- [ ] [Testable outcome]

## Approach

[1-2 sentences]
```

### Child PRD Template

```markdown
# [Feature Title] — [Platform]

**Type:** feature | bug-fix | refactor
**Project:** [git remote repo name]
**Platform:** backend | android | ios | frontend
**Parent:** {parent-slug}
**Status:** planning
**Created:** [YYYY-MM-DD]
**Branch:** {type-prefix}/[parent-slug]-[platform]

## Problem

[Platform-specific problem statement, or reference to parent PRD]

## Goal

[Platform-specific goal]

## Acceptance Criteria

- [ ] [Platform-specific testable outcome]

## Approach

[Platform-specific approach]
```

**Branch naming convention:**
- `feature` type → `feat/{slug}`
- `bug-fix` type → `fix/{slug}`
- `refactor` type → `refactor/{slug}`
- `spike` type → `chore/{slug}`

**Quick mode exception:** Quick PRDs use the current branch (`git branch --show-current`) instead of creating a new one.

**Status workflow:** `planning` → `in-progress` → `review` → `implemented` → `completed`

**To update status:** Edit the `**Status:**` line in the plan file directly.

**PRD key points:**
- Business-focused with high-level approach (no detailed dev tasks)
- After implementation, status becomes `review` (not `implemented`)
- User tests and can request bug fixes while in `review` status
- `/prdx:push` confirms readiness, sets status to `implemented`, creates PR
- Implementation notes and PR metadata appended by agents
- Quick PRDs (`**Quick:** true`) cleaned up after workflow completes

## State File Schema

Per-PRD state files live at `.prdx/state/{slug}.json`. Create `.prdx/state/` on first write (`mkdir -p .prdx/state`).

```json
{
  "slug": "biometric-login",
  "phase": "in-progress",
  "quick": false,
  "parent": "biometric-auth"
}
```

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `slug` | string | yes | Matches the PRD filename slug (`prdx-{slug}.md`) |
| `phase` | string | yes | Current workflow status (mirrors `**Status:**` in PRD) |
| `quick` | boolean | yes | `true` for quick-mode ephemeral PRDs |
| `parent` | string | no | Slug of the parent PRD (child PRDs only) |
| `pr_number` | number | no | PR number (present when phase is `"pushed"`) |

**Status ordering for rollup:** `planning < in-progress < review < implemented < completed`. Parent status = minimum across children.

**Runtime-only phase:** `"pushed"` — non-draft PR created, awaiting merge. Includes `pr_number`. The `/prdx:cleanup` CI job captures lessons and deletes state + PRD after merge.

**Conventions:** State files written by `/prdx:implement`. Quick PRD state files deleted with the ephemeral PRD. Non-draft PR state files transition to `"pushed"` for cleanup tracking.

## Parent-Child PRD Model

Multi-platform features use a parent-child structure. Parent PRDs are **orchestration-only** — they describe the overall feature and track children but are never directly implemented.

### Naming

| PRD | Filename | Branch |
|-----|----------|--------|
| Parent | `prdx-{parent-slug}.md` | _(none)_ |
| Child | `prdx-{parent-slug}-{platform}.md` | `{type-prefix}/{parent-slug}-{platform}` |

### Parent PRD Fields

Includes `## Children` section listing child slugs/branches. Has `**Platforms:**` and `**Implementation Order:**` but **no `**Branch:**`**. Status is derived (minimum across children via `.prdx/state/` files).

```markdown
**Platforms:** backend, android
**Implementation Order:**
1. backend
2. android

## Children

- prdx-biometric-auth-backend.md — backend (`planning`) — branch: feat/biometric-auth-backend
- prdx-biometric-auth-android.md — android (`planning`) — branch: feat/biometric-auth-android
```

### Child PRD Fields

Each child references parent via `**Parent:** {parent-slug}` (without `prdx-` prefix). Each child has its own branch.

### Multi-Session Workflow

**Orchestrator** (`/prdx:implement {parent-slug}`): Reads parent PRD, displays child progress table, shows session instructions. Does NOT run platform agents.

**Child session** (`/prdx:implement {child-slug}`): Checks prerequisites (sibling state files, earlier Implementation Order steps need status ≥ `review`), runs full pipeline (dev-planner → platform agent → code reviewer), writes state file.

**Cross-session communication:** `.prdx/state/` files. Parent's `## Children` section is the canonical list.

### Prerequisite Checking

1. Read parent's `**Implementation Order:**`
2. If step > 1, check earlier-step siblings via `.prdx/state/{sibling}.json`
3. Warn if any prerequisite has status < `review` (advisory, user can override)

## Workflow

### Complete Feature Development

```
/prdx:prdx "add biometric authentication"
↓
Plan Mode → PRD saved → [Publish?] → [Implement?] → Implement → Review → [Ready?] → PR
                                                                    ↳ Draft PR → [Review Loop] → Fix → Push → Done
```

**Multi-platform:** Plan mode asks which platforms/order → parent + child PRDs created → user runs each child in separate sessions.

**1 PRD = 1 Branch = 1 PR:** Parent PRDs are orchestration-only (no branch/PR). Each child gets its own branch and PR.

### Quick Mode (`--quick`)

One-off tasks with full pipeline rigor but no permanent PRD. Lightweight template, no publish option, "Done" option (commit only), PRD cleaned up after. Resume with `/prdx:prdx quick-{slug}` if interrupted.

### Agent Teams Mode (Experimental)

Same workflow as `/prdx:prdx` but with persistent teammates (Lead, Architect, Platform Dev, Auditor). Architect retains context across PRD creation and dev planning. Falls back to `/prdx:prdx` if unavailable. 3-4x token cost. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

### CI Mode (`--ci`)

Non-interactive. PRD is stored as a GitHub issue comment (not committed to the repo).

```bash
# Plan only — generates PRD, posts as issue comment
/prdx:prdx --ci --issue 42 --plan-only --requested-by username

# Implement — reads PRD from issue comment, implements, creates PR
/prdx:prdx --ci --issue 42 --requested-by username
```

**`--requested-by`:** Sets git author to specified GitHub user. Claude Code + github-actions[bot] as co-authors.

See `examples/workflows/mention.claude-code.yml`.

### Standalone Commands (No PRD Required)

```
/prdx:commit "fix typo"       # Commit with prdx.json config
/prdx:simplify src/auth/      # Code cleanup on any files
/prdx:push                    # Auto-detects PRD or standalone mode (supports --draft)
```

## Commands (Thin Wrappers)

### /prdx:prdx (Main Entry Point)

1. Determines entry point (new feature, existing PRD, or quick mode)
2. Runs `/prdx:plan` for planning
3. Asks: Implement? → `/prdx:implement`
4. Asks: Create PR? → `/prdx:push`
5. After draft PR: reviewing loop (fix → push → iterate)
6. Quick mode: cleans up PRD after workflow; normal PRDs cleaned up by `/prdx:cleanup`

### /prdx:prdx:agent (Agent Teams)

Same as `/prdx:prdx` with persistent teammates. Team: Lead (main session), Architect (`prdx:dev-planner`), Platform Dev (1:1 per platform), Auditor (`prdx:ac-verifier` + `prdx:code-reviewer`).

### /prdx:plan

1. Detects platform from description/codebase
2. Enters native plan mode
3. Uses `prdx:code-explorer` and `prdx:docs-explorer` agents for exploration (NOT direct Glob/Grep/Read, NOT built-in Explore subagent)
4. Creates PRD using template format
5. Iterates with user until approval
6. Calls ExitPlanMode immediately when approved (do NOT ask "should I exit plan mode?")

**Focus:** Recon, feasibility, business context, high-level approach (not detailed dev tasks)

### /prdx:implement

1. Loads PRD file
2. Detects PRD type: parent → shows child progress (stops); child → checks prerequisites; single-platform → continues
3. Runs `pre-implement.sh` hook
4. Sets up git branch
5. Invokes `prdx:dev-planner` agent (isolated) for detailed planning
6. Parses dev plan into phases (phase-summary JSON → header regex → single-phase fallback)
7. Executes phases one at a time — platform agent invoked per phase
8. Invokes `prdx:ac-verifier` agent (isolated) — loops fix → re-verify until pass or 3 attempts
9. Invokes `prdx:code-reviewer` agent (isolated) — max 2 fix cycles
10. Runs `post-implement.sh` hook (runs tests, updates status)
11. Appends implementation summary to PRD

**Phased execution:** One agent call per phase. Parallel phases use parallel tool calls. One atomic commit per phase.

### /prdx:push

1. Parses `--draft` flag
2. Auto-detects PRD mode or standalone mode
3. Validates git state
4. Invokes `prdx:pr-author` agent (isolated) → creates PR via `gh` CLI
5. Returns PR URL and number

### Other Commands

- `/prdx:show` — List/search/view PRDs
- `/prdx:publish` — Create GitHub issue from PRD
- `/prdx:cleanup` — Capture lessons from merged PRs + delete PRD plan files

## Agents

All agents run in **isolated contexts** to minimize main conversation size.

### Workflow Agents

| Agent | Role | Returns |
|-------|------|---------|
| `prdx:dev-planner` | Reads skills + CLAUDE.md lessons, explores codebase, creates dev plan with phases | ~3KB dev plan |
| `prdx:pr-author` | Reads PRD + commits, generates PR description, runs `gh pr create` | PR URL + number |
| `prdx:ac-verifier` | 3-point AC check (code exists, test exists, coverage). Independent verification | AC status ~1KB |
| `prdx:code-reviewer` | Reviews diff for bugs/security/quality. High-confidence only (>80%). Does NOT check ACs | Review ~2KB |

### Platform Agents

| Agent | Specialization |
|-------|---------------|
| `prdx:backend-developer` | APIs, services, validation — discovers stack from codebase |
| `prdx:frontend-developer` | Components, state, data fetching — discovers stack from codebase |
| `prdx:android-developer` | UI, architecture, state management — discovers stack from codebase |
| `prdx:ios-developer` | UI, architecture, state management — discovers stack from codebase |

**Platform agents:** Receive dev plan, use TodoWrite, implement with TDD, create conventional commits, return brief summary. They do NOT explore codebase (dev-planner does this), return full file contents, or handle git operations.

### Exploration Agents

| Agent | Role | Returns |
|-------|------|---------|
| `prdx:code-explorer` | Explores codebase patterns, traces execution paths, maps architecture | Summary + snippets ~3KB |
| `prdx:docs-explorer` | Searches web + Context7 for documentation, synthesizes from multiple sources | Summary + examples ~3KB |

**IMPORTANT:** During PRDX workflows (plan, implement), ALWAYS use `prdx:code-explorer` and `prdx:docs-explorer` agents instead of direct Glob/Grep/Read or the built-in Explore subagent. This keeps the main context window clean.

## Skills (Knowledge Bases)

Skills in `skills/` are read by agents during execution:
- **prd-review.md** — Platform-specific review checklist, architecture validation, common pitfalls
- **impl-patterns.md** — Backend/Android/iOS implementation patterns
- **testing-strategy.md** — Unit/integration/UI testing frameworks and strategies by platform

**Lessons learned** are stored in the project's `CLAUDE.md` (under `## Lessons Learned`), not in a skill file. `/prdx:prdx` automatically captures learnings from merged PRs.

## Hooks (Validation Gates)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `pre-plan.sh` | Before `/prdx:plan` | Validates git repo + plans dir exist |
| `pre-implement.sh` | Before `/prdx:implement` | Validates PRD completeness, branch state, uncommitted changes |
| `post-implement.sh` | After `/prdx:implement` | Runs tests (blocks on failure), updates status to `review` |
| `post-edit-simplify.sh` | After Edit/Write on source files | Detects changed lines, prompts simplification. Enable: `/prdx:config hooks enable auto-simplify` |

## Auto-Simplify Hook

When you see `PRDX Auto-Simplify:` in context, apply simplification rules:
1. Check the specified lines for simplification opportunities
2. Remove documentation-style comments (keep `// MARK:`, `// TODO:`, why-comments)
3. Inline single-use variables when expression is clear
4. Inline single-use private functions when simple (1-3 lines)
5. Apply changes with Edit tool, or continue if no simplifications needed

## Development Guidelines

When modifying PRDX itself:

- **Commands:** Keep thin — delegate to agents or bash. Use hooks for validation. Use native tools (plan mode, TodoWrite).
- **Agents:** Single responsibility. Read skills naturally. Use TodoWrite. Return summaries only. No orchestration.
- **Skills:** Knowledge bases only (not executable). Platform-specific sections. Pattern examples.
- **Hooks:** Bash scripts. Exit codes matter (0 = success). Commands work without them.

## Lessons Learned

### Split Code Reviewer into AC Verifier + 2-Pass Code Review (2026-03-18) - backend

**Patterns:**
- Splitting a monolithic agent into two focused single-responsibility agents (ac-verifier + code-reviewer) improves coverage and clarity
- Sequential phases (AC verification first, then code quality) ensure ACs are met before quality polish

**Challenges & Solutions:**
- AC fix loops needed a cap (3 attempts) to prevent infinite cycling — escalate to user after exhaustion

### CI Mode for PRDX (2026-03-18, updated 2026-04-01) - backend

**Patterns:**
- Composable flags (`--issue` standalone + `--ci` builds on it) provide flexibility for both interactive and non-interactive use
- Direct PRD generation via `prdx:code-explorer` + Write tool effectively replaces plan mode for non-interactive contexts
- Checking `CI=true` env var (standard across CI providers) is the cleanest way to bypass interactive prompts in hooks
- Storing PRDs as issue comments (with `<!-- prdx-prd -->` marker) avoids polluting git history with planning documents
- PRDX owns the full CI lifecycle: plan (issue comment), revise (update comment), implement (branch + PR). Only code review stays in the workflow
- `pr-author` agent handles both PR creation and updates (via `gh pr edit`), ensuring consistent titles/bodies across local and CI mode
- `--requested-by` flag sets git author to the workflow requestor; Claude Code + github-actions[bot] as co-authors
- After `@claude plan`, the requester is added as PR assignee. After `@claude implement`, the draft PR is marked ready and the requester is added as reviewer
- The implement workflow job routes through `prdx.md` CI path (`--ci --issue --requested-by`) so attribution logic stays in PRDX, not the workflow

**Deviations from Plan:**
- The CI straight-line flow needed to skip the plans-directory setup prompt entirely, requiring a pre-configured `.prdx/plans-setup-done` marker
