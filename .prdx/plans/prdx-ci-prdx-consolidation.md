# Consolidate CI Workflow into PRDX Commands

**Type:** refactor
**Project:** prdx
**Platform:** backend
**Status:** review
**Created:** 2026-03-21
**Branch:** refactor/ci-prdx-consolidation

## Problem

The CI workflow YAML (`mention.claude-code.yml`) duplicates ~90 lines of PRD-parsing shell scripts (awk `extract_section`, type→prefix mapping, title extraction) across 3 jobs (`plan`, `revise`, `implement`). This causes drift — the workflow generates PR titles independently of PRDX's `pr-author` agent, producing bad results like `refactor: Refactor: Read monthly report...` and absurdly long branch names like `refactor/refactor-read-monthly-report-directly-from-firestore-instead-of-aggregating-daily-reports`.

## Goal

Make PRDX the single source of truth for slug generation, PR titles, and PR bodies in both local and CI mode. The workflow YAML becomes a thin trigger that just calls PRDX commands.

## User Stories

- As a developer using CI mode, I want PRs with clean titles and short branch names so my repo isn't cluttered with verbose naming

## Acceptance Criteria

- [ ] Slugs are 2-4 words max (e.g., `monthly-report-read` not `refactor-read-monthly-report-directly-from-firestore-instead-of-aggregating-daily-reports`)
- [ ] PR titles don't duplicate the type prefix (no `refactor: Refactor:`)
- [ ] CI plan-only creates draft PR + comments on issue (PRDX handles it, not workflow shell)
- [ ] CI revise updates PR body after PRD revision (PRDX handles it, not workflow shell)
- [ ] CI implement updates PR body after implementation (PRDX handles it, not workflow shell)
- [ ] Workflow YAML has no `extract_section` or PRD-parsing shell scripts
- [ ] Local mode is completely unchanged
- [ ] `pr-author` agent handles both creation and update of PRs

## Scope

### Included
- Slug generation improvement (both modes)
- PR title deduplication in `pr-author` agent
- CI steps in `prdx.md` to handle PR creation/update
- `pr-author` agent: add "update existing PR" capability and CI mode awareness
- Workflow YAML simplification
- CLAUDE.md responsibility table update

### Excluded
- Local mode flow changes (untouched)
- `review` workflow job (stays as-is, code review is not PRDX's concern)
- `push.md` and `implement.md` (no changes needed)
- New commands (no `/prdx:revise` — reuse existing `--plan-only` revision path)

## Approach

Add if-checks in PRDX's CI steps to handle what the workflow currently does. Three touchpoints:

1. **Step 2-CI.5** (after plan push): invoke `pr-author` agent to create draft PR, then `gh issue comment`
2. **Step 2-CI.6** (after revise push): invoke `pr-author` agent to update PR body via `gh pr edit`
3. **Step 3-CI.4** (after implement push): invoke `pr-author` agent to update PR body via `gh pr edit`

The `pr-author` agent gains two new capabilities:
- **CI mode awareness**: adds `Closes #N`, PRDX footer, `@claude implement/review` instructions
- **Update mode**: uses `gh pr edit` instead of `gh pr create` when `PR Number:` is provided

The slug fix and PR title fix apply to both modes (local + CI).

## Risks & Considerations

- **Revise job needs linked issue number**: extracted from PR body `Closes #N`. Graceful fallback if missing.
- **pr-author scope creep**: adding "update existing PR" is small (one new code path). Agent already has all PRD-parsing logic.
- **Existing slugs**: only affects NEW PRDs. Existing verbose slugs remain as-is.

---
## Implementation Notes (backend)

**Branch:** refactor/ci-prdx-consolidation
**Implemented:** 2026-03-21

### Files Changed

1. **`commands/plan.md`** — Smart slug generation (2-4 words, strip filler words)
2. **`commands/prdx.md`** — CI steps now create/update PRs via pr-author agent (Steps 2-CI.5b, 2-CI.6, 3-CI.4b); slug derivation updated
3. **`commands/implement.md`** — Added CI mode post-step: push + update PR body when `CI=true`
4. **`agents/pr-author.md`** — Title deduplication rules, CI mode section, "Updating Existing PR" section
5. **`examples/workflows/mention.claude-code.yml`** — Removed ~90 lines of shell PRD-parsing; all 3 jobs now just call PRDX commands
6. **`CLAUDE.md`** — Updated responsibility table (PRDX owns everything in CI except code review)
