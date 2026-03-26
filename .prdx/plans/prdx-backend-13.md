# Exploration Cache

**Type:** feature
**Project:** prdx
**Platform:** backend
**Issue:** #13
**Status:** in-progress
**Created:** 2026-03-26
**Branch:** feat/exploration-cache

## Problem

Every PRDX workflow triggers fresh codebase exploration via `prdx:code-explorer` and `prdx:docs-explorer` agents, even when the codebase hasn't changed. A typical `/prdx:prdx` run explores twice — once during planning, once during implementation (via `prdx:dev-planner`). Repeated runs on the same PRD (e.g., after fixing a failed phase) explore again from scratch. This wastes tokens and adds latency, especially on larger codebases.

## Goal

Cache agent exploration summaries so that subsequent runs can skip redundant exploration when the relevant codebase hasn't changed, reducing token usage and improving speed without sacrificing accuracy.

## User Stories

- As a developer using PRDX, I want the implementation phase to reuse the exploration done during planning so that I don't pay for the same codebase analysis twice
- As a developer re-running `/prdx:implement` after a failed phase, I want cached exploration results to be reused so the retry is faster
- As a developer, I want the cache to auto-invalidate when the codebase changes so I never get stale results

## Acceptance Criteria

- [ ] Exploration results from `prdx:code-explorer` are cached to `.prdx/cache/` after each run
- [ ] `prdx:dev-planner` checks the cache before spawning a fresh `prdx:code-explorer` agent and reuses cached results when valid
- [ ] Cache entries are keyed by a combination of query content and git HEAD SHA, so changes to the codebase invalidate stale entries
- [ ] Cache is gitignored (already covered by `.prdx/*` rule)
- [ ] `prdx:code-explorer` agent instructions include writing cache entries on completion
- [ ] `prdx:dev-planner` agent instructions include reading cache before exploring
- [ ] Cache works transparently — no user flags or configuration required
- [ ] A `--no-cache` flag is available on `/prdx:implement` to force fresh exploration when needed

## Scope

### Included
- Caching `prdx:code-explorer` results (the primary source of redundant exploration)
- Cache invalidation based on git HEAD SHA
- Integration with `prdx:dev-planner` (the main consumer of exploration results)
- `--no-cache` escape hatch

### Excluded
- Caching `prdx:docs-explorer` results (external docs change independently of git state; lower value)
- Caching across different projects or repositories
- Cache size management or eviction policies (premature — cache entries are ~3KB each)
- UI for cache inspection or management

## Approach

**Cache storage:** `.prdx/cache/{slug}/` directory, one file per exploration query. Each file contains the explorer's markdown summary (~3KB) with a metadata header (git SHA, timestamp, query hash).

**Cache key:** Hash of the exploration query text + git HEAD SHA. This ensures:
- Same query on unchanged codebase → cache hit
- Same query after new commits → cache miss (re-explore)
- Different query → cache miss

**Write path (code-explorer agent):** After producing the exploration summary, the agent writes it to `.prdx/cache/{slug}/{query-hash}.md` with metadata. The slug comes from the agent's prompt context (the PRD being worked on).

**Read path (dev-planner agent):** Before spawning `prdx:code-explorer`, check `.prdx/cache/{slug}/` for a matching entry. If found and git SHA matches current HEAD, use the cached summary instead of spawning the agent. If no match, proceed normally.

**Cache format:**
```markdown
---
query_hash: {md5-of-query}
git_sha: {HEAD-at-time-of-exploration}
created: {ISO-timestamp}
slug: {prd-slug}
---

{exploration summary markdown — same format as code-explorer returns}
```

**Integration points:**
1. `agents/code-explorer.md` — add cache-write instructions at the end of the agent's workflow
2. `agents/dev-planner.md` — add cache-read logic before spawning exploration agents
3. `commands/implement.md` — pass `--no-cache` flag through to dev-planner when specified

## Risks & Considerations

- **Cache staleness on non-HEAD changes:** Git HEAD SHA catches committed changes but not uncommitted edits. This is acceptable — exploration summaries are high-level patterns/architecture, not line-level details. Uncommitted changes rarely alter the architectural patterns that exploration captures.
- **Agent instruction complexity:** Adding cache read/write to agent prompts increases their size. Keep instructions minimal — agents are already bounded to ~3KB output, so the cache format is naturally constrained.
- **Query matching:** Exploration queries are natural language, so exact string matching may miss semantically similar queries. Starting with exact match is pragmatic — most redundancy comes from the same workflow re-running the same prompts.
