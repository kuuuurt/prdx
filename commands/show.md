| description | argument-hint |
| Smart PRD viewer: list all, search by keyword, or show detailed status | [slug or keyword] [--status STATUS] [--platform PLATFORM] |

# Show PRDs

> **One command for all PRD viewing needs**
> Smart context-aware viewer that lists, searches, or shows detailed status

## Usage

```bash
# List all PRDs
/prdx:show

# Search by keyword
/prdx:show auth
/prdx:show "memory leak"

# Show specific PRD status
/prdx:show android-219

# Filter by status or platform
/prdx:show --status planning
/prdx:show --platform backend
/prdx:show auth --platform android
```

---

## How It Works

**Smart routing based on input:**

1. **No arguments** → List all PRDs
2. **Exact slug match** → Show detailed status
3. **Keyword/phrase** → Search PRDs
4. **With filters** → List + filter

---

## Phase 1: Determine Mode

**Parse arguments and detect intent:**

1. **Resolve slug using enhanced matching** (exact → substring → word-boundary):
   ```bash
   # 1. Exact: ~/.claude/plans/prdx-{input}.md
   # 2. Substring: ls ~/.claude/plans/prdx-*{input}*.md
   # 3. Word-boundary: split input into words, find PRDs containing all words
   ```
   - If exactly 1 match → STATUS mode
   - If multiple matches → Ask user to select
   - If no match → SEARCH mode

2. **Parse filters:**
   - Extract `--status` value (planning, in-progress, review, implemented, completed)
   - Extract `--platform` value (backend, android, ios, web)

3. **Determine mode:**
   - No args + no filters → **LIST mode**
   - Exact slug → **STATUS mode**
   - Keyword + no exact match → **SEARCH mode**
   - Filters provided → **LIST mode** + filters

---

## MODE 1: List All PRDs

**Display formatted list of all PRDs:**

1. **Find all PRD files:**
   ```bash
   ls ~/.claude/plans/*.md 2>/dev/null
   ```

2. **Parse metadata from each:**
   - Title (first line with #)
   - Platform (**Project**: [value])
   - Status (**Status**: [value])
   - Created date
   - Issue number (if exists)
   - PR number (if exists)
   - Parent PRD (**Parent**: [value]) — present only in child PRDs

3. **Apply filters if provided:**
   - Filter by status if `--status` provided
   - Filter by platform if `--platform` provided

4. **Separate parent and child PRDs:**
   - Child PRDs have a `**Parent:**` field — collect these separately
   - Parent PRDs may have a `## Children` section — identify them
   - Top-level PRDs are those with no `**Parent:**` field

5. **Group by platform and display, with children nested under parents:**

   Display parent PRDs first (within their platform group), with their child PRDs indented
   underneath. Child PRDs do NOT appear at the top level — they are shown only under their parent.

```
PRDs in ~/.claude/plans/ (12 found)

BACKEND (3)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  planning       Fix Context Storage Logger Tracing
              Created: 2025-11-08

  in-progress Add Health Check Endpoint (#234)         (parent)
              Created: 2025-11-03 | Branch: feat/backend-234
    review      add-health-check-backend    backend
    planning    add-health-check-android    android

  completed   Fix IoT Client Memory Leak (#215)
              Created: 2025-10-28 | PR #223 merged

ANDROID (5)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  review      Production Observability (#218 → PR #230)
              Created: 2025-11-04 | 2 reviews pending

  planning       Optimize LoginViewModel
              Created: 2025-11-05 | Depends: #215

  [... more ...]

IOS (4)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [... entries ...]

──────────────────────────────────────────────────────────
Quick actions:
  /prdx:show <slug>        View detailed status
  /prdx:show <keyword>     Search PRDs
  /prdx:plan <desc>        Create new PRD
```

5. **If filtered, show what was applied:**
   ```
   Showing: status=planning, platform=android (2 found)
   ```

6. **If no PRDs exist:**
   ```
   No PRDs found.

   Create your first PRD:
     /prdx:plan "Your feature description"
   ```

---

## MODE 2: Search PRDs

**Search all PRD content by keyword:**

1. **Search using grep:**
   ```bash
   grep -i -n "<keyword>" ~/.claude/plans/*.md
   ```
   - Case-insensitive search
   - Show line numbers
   - Exclude templates

2. **For multiple keywords, use OR logic:**
   - Show PRDs matching ANY keyword

3. **Parse and rank results:**
   - Title matches: highest priority
   - Acceptance criteria matches: high
   - Approach/Goal matches: medium
   - Other content: normal

   For each result, extract and display `**Parent:**` if present, so users can see parent-child
   relationships at a glance. Show it on the status line: `Status: ... | Parent: {slug}` or omit
   if the PRD has no parent.

4. **Display results with context:**

```
Found 3 PRDs matching "auth0"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Optimize LoginViewModel (android)
   File: android-optimize-loginviewmodel.md
   Status: planning | Created: 2025-11-05 | Parent: biometric-auth

   [Goal]
   Simplify LoginViewModel by calling Auth0Client directly
   and using UIState instead of nested sealed classes.

   [Implementation]
   Replace DoLoginUseCase/ConfirmOtpUseCase with direct
   Auth0Client calls in the ViewModel.

   [3 matches total]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2. Fix Auth0 Token Refresh (backend)
   File: backend-fix-auth0-token-refresh.md
   Status: completed | Issue: #215 | PR #223 merged | (no parent)

   [Problem]
   The Auth0 token refresh mechanism is not properly
   handling expired tokens, causing users to be logged out.

   [5 matches total]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

3. Add Biometric Authentication (ios)
   File: ios-biometric-auth.md
   Status: planning | Created: 2025-11-02

   [Approach]
   Integrate with existing Auth0 authentication flow using
   LocalAuthentication framework for Face ID/Touch ID.

   [1 match total]

──────────────────────────────────────────────────────────
Found 3 PRDs (9 total matches)
Platforms: backend (1), android (1), ios (1)

Actions:
  /prdx:show <slug>        View detailed status
  /prdx:implement <slug>   Start working on one
```

5. **If no results:**
   ```
   No PRDs found matching "xyz"

   Tips:
   - Try different keywords or synonyms
   - Use /prdx:show to browse all PRDs
   - Check spelling
   ```

---

## MODE 3: Show Detailed Status

**Comprehensive status dashboard for one PRD:**

1. **Load PRD and parse:**
   - All metadata fields
   - Acceptance criteria (count total/completed)
   - Implementation tasks (if detailed plan exists)
   - Dependencies and blockers

2. **Check git status (if branch exists):**
   ```bash
   git show-ref --verify refs/heads/[branch-name]
   git rev-list --count [branch]..origin/main    # behind
   git rev-list --count origin/main..[branch]    # ahead
   git log -1 --format="%ct %s" [branch]         # last commit
   ```

3. **Check PR status (if PR exists):**
   ```bash
   gh pr view [number] --json state,isDraft,reviewDecision,reviews,mergeable
   ```

4. **Check issue status (if issue exists):**
   ```bash
   gh issue view [number] --json state,title
   ```

5. **Calculate workflow progress:**
   - Planning: 0-10%
   - Published: 10-20%
   - Development: 20-70% (based on task completion)
   - PR Review: 70-90%
   - Completed: 100%

6. **Display comprehensive dashboard:**

```
╔═══════════════════════════════════════════════════════╗
║  Optimize LoginViewModel (android)                    ║
╚═══════════════════════════════════════════════════════╝

Status: in-progress | Created: 2025-11-05 (3 days ago)
File: ~/.claude/plans/android-optimize-loginviewmodel.md

WORKFLOW PROGRESS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Planning       2025-11-05
✅ Development    Started 2025-11-05
   └─ Branch: feat/android-optimize-loginviewmodel
   └─ Tasks: 8/12 complete (67%)
   └─ Last commit: 2 hours ago

⏳ Verification   (next step)
⬜ PR Review
⬜ Completed

Progress: ████████████████░░░░ 65%

ACCEPTANCE CRITERIA ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Direct Auth0Client calls (no use cases)
✅ UIState pattern replaces sealed classes
⏳ Existing tests still pass
⬜ Code follows simplified architecture
⬜ No functionality regressions

[3/5 complete]

IMPLEMENTATION TASKS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase 1 - Foundation: 2/2 ✓
Phase 2 - Core Logic: 4/6 ⏳
  ✅ Remove DoLoginUseCase
  ✅ Remove ConfirmOtpUseCase
  ✅ Add Auth0Client to ViewModel
  ✅ Implement direct login call
  ⏳ Implement OTP confirmation
  ⬜ Update error handling

Phase 3 - Testing: 2/4 ⏳

DEPENDENCIES ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Depends on:
  ✅ #215: Fix Auth0 Token Refresh (completed)

Blocks:
  ⏳ #220: Complete Auth Refactor (waiting)

GIT STATUS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: feat/android-optimize-loginviewmodel
  8 commits | 2 ahead of main | Up to date
  Last commit: "refactor: simplify error handling" (2h ago)

NEXT ACTIONS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Recommended:
  1. ✨ Continue work: /prdx:dev
  2. 📝 Review plan: Read ~/.claude/plans/android-optimize-loginviewmodel.md

Quick commands:
  /prdx:implement  Continue implementation
  /prdx:show            Back to list

╚═══════════════════════════════════════════════════════╝
```

7. **If the PRD has a `## Children` section (parent PRD), show a children status dashboard:**

   - For each child slug listed in `## Children`, read `.prdx/state/{child-slug}.json` if it
     exists. Use the `phase` field from the state file as the child's current status.
   - If no state file exists, fall back to reading `**Status:**` from the child's PRD file.
   - Status ordering (ascending): planning < in-progress < review < implemented < completed
   - Parent status = minimum of all children statuses (i.e. the least-advanced child determines
     the overall progress).

   Display after the main dashboard:

```
CHILDREN STATUS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| Child                    | Platform | Status      |
|--------------------------|----------|-------------|
| biometric-auth-backend   | backend  | review      |
| biometric-auth-android   | android  | in-progress |

Overall: in-progress (derived from children)

Session commands:
  /prdx:implement biometric-auth-backend
  /prdx:implement biometric-auth-android
```

8. **Adapt display based on status:**
   - **planning**: Show planning info, suggest publish or start
   - **in-progress**: Show detailed tasks, git status, next steps
   - **review**: Emphasize testing status, user confirms before PR
   - **completed**: Show summary, timeline, what's unblocked

---

## Edge Cases

**Ambiguous input:**
```
Multiple PRDs match "android":
  1. android-optimize-loginviewmodel.md
  2. android-biometric-auth.md
  3. android-dark-mode.md

Which one? (enter number or 'c' to cancel):
```

**PRD directory doesn't exist:**
```
No PRDs directory found.

Create your first PRD:
  /prdx:plan "Your feature description"
```

**Malformed PRD:**
```
⚠️ Warning: android-something.md has invalid metadata
   Showing with defaults...
```

**Git/GitHub not available:**
- Gracefully skip git checks
- Show "Git status: unavailable"
- Show "GitHub integration: disabled"

---

## Implementation Strategy

**Use smart detection:**
1. Try exact slug match first (fastest)
2. Fall back to search if no match
3. Apply filters regardless of mode

**Optimize for speed:**
- Parse only first 20 lines of PRDs for list mode
- Cache git status checks (expensive)
- Parallel gh API calls if multiple PRs

**Progressive disclosure:**
- List mode: minimal info
- Search mode: relevant excerpts
- Status mode: everything

---

## Benefits

**One command, multiple modes:**
- No decision fatigue ("list or search or status?")
- Intuitive routing based on input
- Consistent interface

**Context-aware:**
- Shows what's relevant for each mode
- Adapts to PRD status
- Smart recommendations

**Fast and efficient:**
- Replaces 3 commands (list, search, status)
- Reduces 666 lines to ~400
- Single mental model

---

## Migration from Old Commands

**Users can still think in old terms:**
- "I want to list" → `/prdx:show`
- "I want to search for X" → `/prdx:show X`
- "I want to see status" → `/prdx:show [slug]`

**All three patterns work with ONE command.**
