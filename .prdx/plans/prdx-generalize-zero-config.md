# Generalize PRDX for Zero-Config Plug-and-Play

**Type:** refactor
**Project:** prdx
**Platform:** backend
**Status:** in-progress
**Created:** 2026-03-31
**Branch:** refactor/generalize-zero-config

## Problem

PRDX currently prescribes a rigid 4-platform enum (backend/frontend/android/ios), hardcoded branch naming conventions, a heavy PRD template, and requires `prdx.json` configuration. This means projects outside the mobile+backend paradigm (CLI tools, data pipelines, Flutter, infra, monoliths) can't use the plugin without friction. The goal is "plug and play" — install the plugin and it just works for any project.

## Goal

Anyone can install PRDX and use it immediately on any project type without configuration. The plugin discovers project conventions rather than prescribing them.

## Acceptance Criteria

- [ ] Platform field accepts any string — not limited to 4 values
- [ ] Platform is auto-detected from any project type (Python, Go, Rust, Flutter, etc.)
- [ ] A single unified developer agent replaces all 4 platform agents
- [ ] Branch naming is detected from existing repo branches, with conventional fallback
- [ ] PRD template adapts — only required sections are mandatory, optional sections are contextual
- [ ] `prdx.json` is fully optional — all fields have sensible defaults, no required fields
- [ ] iOS simulator target is dynamically detected, not hardcoded
- [ ] Auto-simplify hook works with a broader set of languages
- [ ] Skills path resolution works correctly in consumer projects (not just the plugin repo)
- [ ] Existing workflows (CI mode, multi-platform, quick mode) continue to work

## Scope

### Included
- Generalize platform detection and agent dispatch
- Create unified developer agent
- Auto-detect branch naming conventions
- Simplify PRD template (adaptive sections)
- Make prdx.json fully optional
- Fix hardcoded iOS simulator
- Broaden auto-simplify source extensions
- Fix skills path resolution in agents

### Excluded
- Custom platform agent registration (future work)
- prdx.json migration tooling
- Changes to CI co-author IDs (GitHub platform constants)
- Changes to PR body structure (already flexible)
- Changes to CLAUDE.md lessons location (standard convention)

## Approach

### Phase 1: Unified Developer Agent + Free-Form Platform

**Replace all 4 platform agents with a single `agents/developer.md`** that:
1. Runs universal stack discovery (checks all dependency files, not just one platform's)
2. Selects verification strategy based on discovered stack
3. Retains specialized ecosystem knowledge in a unified context
4. Receives a platform hint in its prompt for context

**Delete the 4 existing platform agents** (`backend-developer.md`, `frontend-developer.md`, `android-developer.md`, `ios-developer.md`). No wrappers needed — for multi-platform PRDs, `implement.md` already spins up parallel agents (one per platform on the same Implementation Order step). Each gets its own `prdx:developer` instance with a different platform hint.

**Generalize platform detection in `plan.md`**:
- Replace the hardcoded 4-value enum with heuristic codebase scanning
- Detect ANY project type: Python, Go, Rust, Node, Java, Flutter, React Native, etc.
- `**Platform:**` field becomes free-form string
- AskUserQuestion shows ALL detected contexts, not just 4 hardcoded options
- Single detected platform auto-selects without asking

**Update `implement.md` dispatch**:
- Route ALL platforms to `prdx:developer` agent (single dispatch path)
- Pass platform as a hint in the agent prompt
- Multi-platform: spin up parallel `prdx:developer` agents (one per platform in the same step)
- Remove the 4-way platform→agent mapping entirely

### Phase 2: Branch Naming Detection

**Auto-detect branch convention from existing branches**:
```bash
git branch -r | grep -v HEAD | sed 's/.*origin\///' | head -30
```
- If branches use `feature/` → use `feature/` not `feat/`
- If branches use ticket patterns (JIRA-123/) → detect and suggest
- If no pattern detected → fall back to conventional (`feat/`, `fix/`, etc.)

**Keep as smart default** — no config needed. The existing `feat/`/`fix/` convention becomes the fallback, not the prescription.

### Phase 3: Fix Hardcoded Values

**iOS simulator** (`post-implement.sh` line 80, `ios-developer.md`):
- Detect available simulator dynamically via `xcrun simctl list`
- Fall back to "iPhone 16" only if detection fails

**Auto-simplify extensions** (`post-edit-simplify.sh` line 29):
- Expand to include: `.java`, `.rb`, `.php`, `.cs`, `.c`, `.cpp`, `.h`, `.scala`, `.dart`, `.zig`, `.ex`, `.exs`, `.clj`
- Covers most common languages without being overly broad

### Phase 4: Simplify PRD Template + Schema

**PRD template** — make sections adaptive:
- **Always required**: Problem, Goal, Acceptance Criteria, Approach (already what `pre-implement.sh` validates)
- **Contextual** (include when relevant): User Stories (user-facing features), Scope (ambiguous boundaries), Risks (known constraints)
- Instruct plan mode to omit empty sections rather than including stubs

**Type field** — keep suggested values but accept any string:
- Known types (`feature`, `bug-fix`, `refactor`, `spike`) map to conventional branch prefixes
- Unknown types use the type directly as prefix (e.g., `experiment/slug`)

**`schema.json`** — make everything optional:
- Remove `"required": ["version", "commits"]` at root
- Remove `"required"` arrays inside `commits.coAuthor` and `commits.extendedDescription`
- Add `"additionalProperties": true` at root to allow future extensions
- All defaults already work — config file becomes truly optional

### Phase 5: Fix Skills Path Resolution

**In `dev-planner.md`, `ac-verifier.md`, `code-reviewer.md`**:
- Skills are provided by the plugin system at `.claude/skills/` in consumer projects
- The current hardcoded paths are correct for consumer projects (plugin maps `skills/` → `.claude/skills/`)
- BUT: agents should gracefully handle missing skills (check existence before reading)
- Add fallback: if a skill file doesn't exist, skip it rather than erroring

## Risks & Considerations

- **Unified agent quality**: A generic developer agent needs to be as good as specialized ones. Mitigate by consolidating the best patterns from all 4 agents and testing across project types.
- **Branch detection false positives**: Some repos have messy branch histories. Mitigate with the conventional fallback.
- **Backward compatibility**: Existing PRDs with `**Platform:** backend` still work — the free-form approach is a superset. Multi-platform dispatch works the same (parallel agents), just all using `prdx:developer` now.
