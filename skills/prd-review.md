# PRD Review Skill

Expert skill for reviewing PRDs against the project's actual patterns and best practices. Agents should **discover the project's stack and conventions** before applying review checks.

## Platform-Specific Review Patterns

### Backend

**Architecture Checks:**
- API endpoint design follows the project's established routing conventions
- Authentication/authorization follows existing auth patterns
- Error handling uses the project's consistent error response format
- Input validation follows project's validation approach
- Third-party service integration follows established patterns

**Common Pitfalls:**
- Missing input validation at API boundaries
- Not handling external service failures gracefully
- Not considering caching for expensive operations
- Inconsistent error response format

**Performance:**
- Database queries optimized (avoid N+1)
- Caching strategy for frequently-accessed data
- Async operations properly handled

### Android

**Architecture Checks:**
- Code follows the project's established architecture pattern
- Dependency injection uses the project's existing DI approach
- Navigation follows the project's navigation patterns
- State management uses the project's established approach
- New code matches existing package/module organization

**Common Pitfalls:**
- Not handling configuration changes properly
- Memory leaks with lifecycle-unaware components
- Missing loading/error states in UI
- Inconsistent use of project's established patterns

**Performance:**
- Efficient list rendering for large datasets
- Background operations on appropriate threads/dispatchers

### iOS

**Architecture Checks:**
- Code follows the project's established architecture pattern
- State management uses the project's existing approach
- Navigation follows the project's navigation patterns
- Async operations follow project conventions
- New code matches existing file/group organization

**Common Pitfalls:**
- Retain cycles with closures
- Not updating UI on the main thread
- Missing accessibility labels
- Not handling background/foreground transitions

**Performance:**
- Avoiding expensive operations on main thread
- Proper lifecycle management for async work

### Frontend

**Architecture Checks:**
- Component structure follows project conventions
- State management approach is consistent with existing code
- Data fetching uses project's established pattern
- API layer is properly abstracted (not fetching directly in components)

**Common Pitfalls:**
- Missing loading, error, and empty states in UI
- Prop drilling instead of using project's state management approach
- Missing responsive design for mobile viewports
- Forgetting accessibility (ARIA labels, keyboard navigation, focus management)
- Not handling stale data or race conditions in async operations

**Performance:**
- Bundle size monitored (code splitting, lazy loading)
- Memoization for expensive computations
- Avoiding unnecessary re-renders

## Cross-Platform Concerns

**Security:**
- Sensitive data not logged
- API keys in environment variables
- Proper token refresh handling
- Input sanitization

**Accessibility:**
- Screen reader support
- Keyboard navigation
- Color contrast ratios

**Observability:** Error tracking configured, logging follows project conventions.

## Review Checklist

1. **Problem** — clear, specific, affected users identified
2. **Goal** — measurable, out-of-scope items prevent creep
3. **Acceptance Criteria** — 3-5 testable items covering functional, error handling, non-functional
4. **Technical Approach** — follows project patterns, risks identified, platform pitfalls addressed
5. **Implementation Plan** — logical phases, testing phase included, dependencies clear
6. **Multi-Project Impact** — client/backend implications checked, backward compatibility maintained

## Review Pipeline Patterns

These patterns apply to the `prdx:reviewer-orchestrator` and its specialist sub-agents.

### Diff Thresholds

| Diff size | Pipeline |
|---|---|
| < 50 LOC | Single-pass fallback (`prdx:code-reviewer`) |
| ≥ 50 LOC | Scope detection + parallel specialist dispatch |
| ≥ 200 LOC or any `critical` finding | Specialists + red-team adversarial pass |

### Specialist → File Mapping

| Specialist | Triggered by |
|---|---|
| `security` | `auth/`, `security/`, `crypto/`, `*token*`, `*password*`, `*secret*` |
| `testing` | `*.test.*`, `*.spec.*`, `tests/`, `__tests__/`, `*_test.*` |
| `data-migration` | `migrations/`, `*migration*`, `*schema*`, `*seed*` |
| `api-contract` | `routes/`, `controllers/`, `handlers/`, `api/`, `openapi*`, `swagger*` |
| `performance` | Any file with >30 changed lines |
| `maintainability` | All files (always included unless diff is test-only) |
| `red-team` | Conditional: LOC ≥ 200 or critical finding |

### Finding Structure

Every finding must include:
- `fingerprint` — `{file}:{line}:{rule-id}` (unique identifier for dedup)
- `severity` — `info` / `warning` / `critical`
- `classification` — `AUTO-FIX` or `ASK`
- `specialist` — which agent produced the finding

### Classification Rules

**AUTO-FIX** (silent batch commit, no user prompt):
- Unused import statements
- Trailing whitespace on changed lines
- `console.log` / `print` / debug prints in non-test code

**Always ASK** (batched into single `AskUserQuestion`):
- Any finding in a test file
- Any `critical` severity finding
- Architecture decisions, security tradeoffs, naming choices
- All red-team findings

**Default**: ASK when uncertain. AUTO-FIX only for patterns with mechanical certainty.

### Deduplication

When multiple specialists flag the same `fingerprint`:
- Keep one finding
- Union severity (take the highest: critical > warning > info)
- Mark `confidence: multi-specialist` to boost signal
