---
description: "Simplify code with pragmatic cleanup"
argument-hint: "[files/features]"
---

# /prdx:simplify - Code Cleanup

Deep code review (reuse, quality, efficiency) followed by a pragmatism pass that
keeps the result conservative and concise.

This command is a **thin wrapper**: it scopes the target files, hands the heavy
review to Claude Code's built-in `simplify` skill, then applies PRDX's
pragmatism and comment-discipline rules on top.

## Usage

```bash
/prdx:simplify                      # Changed files on current branch
/prdx:simplify src/auth/            # Specific directory
/prdx:simplify UserService.kt       # Specific file
/prdx:simplify "authentication"     # Feature name (searches for related files)
```

## Workflow

```
Phase 1: Scope target files
Phase 2: Built-in `simplify` skill — deep review (reuse / quality / efficiency)
Phase 3: PRDX pragmatism pass — enforce scope fence + conciseness + platform rules
Phase 4: Summary
```

### Phase 1: Scope Target Files

**If arguments provided:**

```bash
if [ -f "$ARG" ] || [ -d "$ARG" ]; then
  TARGET="$ARG"
else
  # Search for files related to feature name
  git grep -l "$ARG" --include="*.kt" --include="*.swift" --include="*.ts"
fi
```

**If no arguments** — changed source files on the current branch vs main:

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.(kt|swift|ts|tsx|js|jsx)$'
```

Display the target files and confirm before proceeding:

```
🎯 Target files:

src/auth/UserService.kt
src/auth/AuthViewModel.kt

Proceed with simplification? (y/n)
```

### Phase 2: Deep Review (built-in `simplify` skill)

Invoke the built-in `simplify` skill via the Skill tool, passing the scoped
target files so the review is bounded to them. The skill runs three parallel
review agents — code reuse, code quality, efficiency — and applies fixes:

- **Reuse:** new code that duplicates existing utilities/helpers
- **Quality:** redundant state, parameter sprawl, copy-paste variation, leaky
  abstractions, stringly-typed code, nested conditionals
- **Efficiency:** N+1 patterns, missed concurrency, hot-path bloat, no-op
  updates, unnecessary existence checks, memory leaks

This phase catches structural and efficiency issues that PRDX's own rules are
blind to. Let it run to completion before Phase 3.

### Phase 3: PRDX Pragmatism Pass

Re-read the target files (now modified by Phase 2) and enforce the rules the
built-in skill does not guarantee:

**Pragmatism fence — revert or scope down any Phase 2 change that:**
- Refactored architecture or restructured public APIs beyond the touched code
- Changed behavior or logic (simplification must be behavior-preserving)
- Generalized/abstracted beyond what the immediate code needs — three similar
  lines beat a premature abstraction

**Conciseness:**

| Rule | Action |
|------|--------|
| Self-documenting code | Use descriptive names instead of comments |
| Single-use variables | Inline when the expression is clear |
| Single-use private functions | Inline when simple |

**Comment discipline:**

REMOVE — comments describing *what* code does, comments restating an
identifier name, outdated comments, redundant doc headers.

KEEP — `// MARK:` / `#pragma mark` section markers, `// TODO:` / `// FIXME:`,
*why*-comments (hidden constraints, invariants, workarounds with context),
legal/license headers.

**Platform-specific:**
- **iOS/Swift** — keep `// MARK:` and `#pragma mark`; remove `///` docs unless public API
- **Android/Kotlin** — keep `@Suppress` with an explanation; remove KDoc on private functions
- **TypeScript** — keep `// @ts-expect-error` with an explanation; remove JSDoc on internal functions

### Phase 4: Summary

```
✅ Simplification complete!

Phase 2 (deep review): 3 reuse, 2 quality, 1 efficiency issue fixed
Phase 3 (pragmatism):  1 over-abstraction reverted, 4 comments removed, 2 vars inlined

Files modified: 2
- src/auth/UserService.kt
- src/auth/AuthViewModel.kt
```

## What This Command Does NOT Do

- Add new functionality
- Change behavior or logic
- Format code (use a formatter)
- Fix bugs
- Refactor architecture (use `/prdx:plan` for that)

## Cost note

Phase 2 fans out three parallel agents, so this command costs roughly 5–6× a
plain single-context cleanup. That is acceptable because it runs once at the
end of a workflow — but the cost should be monitored. See `tools/README.md`
("Token-cost measurement") for the planned measuring tool.
