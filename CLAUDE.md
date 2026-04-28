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

Plans stored in configurable directory (default `.prdx/plans/`), gitignored. Override via `plansDirectory` in `prdx.json`. A `.prdx/plans-setup-done` marker prevents repeated setup.

**Naming:** `prdx-{slug}.md` normal, `prdx-quick-{slug}.md` quick (ephemeral).

**PLANS_DIR resolution:** Source `hooks/prdx/resolve-plans-dir.sh` — do NOT hardcode `.prdx/plans`.

**PRD templates** (full, quick, child): see `commands/plan.md`. Every PRD includes `**Project:** [git remote repo name]`. Auto-detected via `gh repo view --json name --jq '.name'`, falling back to repo directory name.

**Branch naming:** `feature` → `feat/{slug}`, `bug-fix` → `fix/{slug}`, `refactor` → `refactor/{slug}`, `spike` → `chore/{slug}`. Quick PRDs use current branch.

**Status workflow:** `planning` → `in-progress` → `review` → `implemented` → `completed`

## State File Schema

`.prdx/state/{slug}.json` — keys: `slug`, `phase`, `quick` (bool), `parent?`, `pr_number?` (when pushed). Ordering: `planning < in-progress < review < implemented < completed`. Phase `"pushed"` = non-draft PR awaiting merge.

## Parent-Child PRD Model

Parent PRDs are **orchestration-only** (no branch/PR). Parent: `prdx-{slug}.md` with `**Platforms:**` + `**Implementation Order:**` + `## Children`. Child: `prdx-{slug}-{platform}.md` with `**Parent:** {slug}` field and own branch `{type-prefix}/{slug}-{platform}`.

**Prerequisites:** Check earlier-step siblings via `.prdx/state/{sibling}.json`; warn if status < `review` (advisory, overridable).

## Workflow

```
Plan Mode → PRD saved → [Publish?] → [Implement?] → Implement → Review → [Ready?] → PR
                                                                  ↳ Draft PR → [Review Loop] → Fix → Push → Done
```

**Multi-platform:** 1 PRD = 1 Branch = 1 PR. Parent + child PRDs → user runs each child in separate sessions. **Quick mode:** no permanent PRD, cleaned up after. **CI mode:** see `commands/prdx.md`. **Agent Teams:** Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

## Commands

- `/prdx:prdx` — Main entry: plan → implement → push loop. Quick mode cleans up PRD after.
- `/prdx:prdx:agent` — Same with persistent agent teams.
- `/prdx:plan` — Plan mode: detect platform, create PRD, iterate until approved, call ExitPlanMode. Use `prdx:code-explorer`/`prdx:docs-explorer` (NOT direct Glob/Grep/Read).
- `/prdx:implement` — Load PRD → hook → branch → dev-planner → phased platform agents → ac-verifier (3 attempts) → code-reviewer (2 cycles) → post-hook → append summary.
- `/prdx:push` — Validate git → `prdx:pr-author` → PR via `gh` CLI. Supports `--draft`.
- `/prdx:show` — List/search/view PRDs.
- `/prdx:publish` — Create GitHub issue from PRD.
- `/prdx:cleanup` — Capture lessons from merged PRs + delete plan files.
- `/prdx:auto` — Non-interactive mode (CI/automated): plan-only or implement from issue. `/prdx:ci` is a deprecated alias.

## Agents

All agents run in **isolated contexts**. ALWAYS use `prdx:code-explorer` and `prdx:docs-explorer` instead of direct Glob/Grep/Read or the built-in Explore subagent.

- `prdx:dev-planner` — codebase exploration → dev plan
- `prdx:pr-author` — PR description + `gh pr create`/`gh pr edit`
- `prdx:ac-verifier` — 3-point AC check (code exists, test exists, coverage)
- `prdx:code-reviewer` — bugs/security/quality, >80% confidence only
- `prdx:backend-developer`, `prdx:frontend-developer`, `prdx:android-developer`, `prdx:ios-developer` — discover stack from codebase; use TodoWrite; return brief summary only
- `prdx:code-explorer` — architecture + patterns; `prdx:docs-explorer` — web + Context7 docs

## Skills

`skills/prd-review.md`, `skills/impl-patterns.md`, `skills/testing-strategy.md` — read by agents. Lessons learned stored here under `## Lessons Learned`.

## Hooks (Validation Gates)

`pre-plan.sh` (validates git + plans dir), `pre-implement.sh` (validates PRD, branch, uncommitted changes), `post-implement.sh` (runs tests, updates status to `review`), `post-edit-simplify.sh` (detects changed lines, prompts simplification).

**Auto-Simplify:** When `PRDX Auto-Simplify:` appears in context: check specified lines, remove doc-style comments (keep `// MARK:`, `// TODO:`, why-comments), inline single-use variables/functions when clear.

## Development Guidelines

Commands: thin wrappers, delegate to agents/bash, use hooks + native tools. Agents: single responsibility, use TodoWrite, return summaries only. Skills: knowledge bases only. Hooks: bash, exit codes matter.

## Lessons Learned

### Split Code Reviewer into AC Verifier + 2-Pass Code Review (2026-03-18) - backend
- Split monolithic agents into focused single-responsibility agents (ac-verifier + code-reviewer) for better coverage
- Run AC verification before code quality — ensure correctness first, then polish
- Cap fix loops (3 attempts) to prevent infinite cycling — escalate to user after exhaustion

### CI Mode for PRDX (2026-03-18, updated 2026-04-01) - backend
- `--issue` + `--auto` composable flags for flexible interactive/non-interactive use (`--ci` is a deprecated alias for `--auto`)
- `prdx:code-explorer` + Write tool replaces plan mode in non-interactive CI contexts
- `CI=true` env var (standard across providers) cleanly bypasses interactive hook prompts
- PRDs as issue comments (`<!-- prdx-prd -->` marker) avoids polluting git history
- CI flow needed `.prdx/plans-setup-done` marker to skip interactive plans-directory setup prompt

### Upsert PRD comments by marker (2026-04-28) - claude-plugin
- All paths posting `<!-- prdx-prd -->` content go through `hooks/prdx/upsert-prd-comment.sh` to avoid duplicates
- Detection uses `gh issue view --json comments` + `jq` filter; PATCH falls back to POST on 404 (manually-deleted comment)
- Helper idempotently prepends the marker so callers don't need to remember it
