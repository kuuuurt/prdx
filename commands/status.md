# PRD Status Visualization

Display detailed status, progress, and workflow phase for a specific PRD with visual progress tracking.

## Usage

```bash
/prdx:status <slug>
```

## Examples

```bash
/prdx:status android-219                    # Show status for android-219
/prdx:status backend-auth-refactor          # Show backend PRD status
```

## Instructions

You are helping the user visualize the current status and progress of a PRD.

---

## Phase 1: Load and Parse PRD

**Find and extract all relevant information:**

1. **Find PRD file:**
   ```bash
   ls .claude/prds/*[slug]*.md
   ```
   - If multiple matches, prompt user to select
   - If not found, show error with suggestions

2. **Parse PRD metadata:**
   Extract from metadata lines:
   - **Title** (first line with #)
   - **Project/Platform**
   - **Status**
   - **Created** date
   - **Issue** number (if exists)
   - **PR** number (if exists)
   - **Branch** name (if exists)
   - **Started** date (if exists)
   - **PR Created** date (if exists)
   - **Completed** date (if exists)
   - **Dependencies**
   - **Blocks**

3. **Parse PRD content:**
   - Count total acceptance criteria
   - Count completed acceptance criteria (marked with [x])
   - Check for "## Detailed Implementation Plan" section
   - If exists, count total tasks and completed tasks

4. **Check git status (if branch exists):**
   ```bash
   git show-ref --verify refs/heads/[branch-name]
   ```

   If branch exists:
   ```bash
   git fetch origin main
   git rev-list --count [branch-name]..origin/main  # commits behind
   git rev-list --count origin/main..[branch-name]  # commits ahead
   git log -1 --format=%ct [branch-name]            # last commit timestamp
   ```

5. **Check PR status (if PR number exists):**
   ```bash
   gh pr view [pr-number] --json state,isDraft,mergeable,reviewDecision,reviews
   ```

6. **Check Issue status (if issue number exists):**
   ```bash
   gh issue view [issue-number] --json state,title
   ```

---

## Phase 2: Determine Workflow Phase

**Map status to workflow phase:**

Workflow phases:
1. **Planning** - Status: draft, no issue
2. **Published** - Status: published OR has issue number
3. **Development** - Status: in-progress, has branch
4. **Verification** - Development complete, awaiting review
5. **PR Review** - Status: in-review, has PR
6. **Completed** - Status: completed

**Calculate progress percentage:**
- Planning: 0-10%
- Published: 10-20%
- Development: 20-70% (based on task completion)
- Verification: 70-80%
- PR Review: 80-95%
- Completed: 100%

**Development phase progress:**
```
progress = 20 + ((completed_tasks / total_tasks) * 50)
```

---

## Phase 3: Visualize Status

**Display comprehensive status dashboard:**

```
╔════════════════════════════════════════════════════════════════════════════╗
║  PRD STATUS: [title]                                                       ║
╚════════════════════════════════════════════════════════════════════════════╝

📄 PRD: [platform]-[slug].md
🏷️  Type: [feature/bug-fix/refactor/spike]
📍 Platform: [backend/android/ios]

CURRENT STATUS
────────────────────────────────────────────────────────────────────────────
Status: [status] | Created: [date] | [Duration if started]

WORKFLOW PROGRESS
────────────────────────────────────────────────────────────────────────────

✅ Planning       (completed [date])
    └─ PRD created with [N] acceptance criteria
    └─ Multi-agent review completed

✅ Published      (completed [date])
    └─ GitHub Issue: #[number] (open/closed)

⏳ Development    (in progress, started [date])
    └─ Branch: [branch-name] (feat/fix/refactor)
    └─ Tasks: [X]/[N] completed ([percentage]%)
    └─ Commits: [N] commits ([X] ahead of main)
    └─ Last activity: [X days/hours ago]

⬜ Verification   (pending)
    └─ Awaiting: Final testing and quality check

⬜ PR Review      (pending)
    └─ PR: Not created yet

⬜ Completed      (pending)

Progress: ████████████░░░░░░░░ 55%

────────────────────────────────────────────────────────────────────────────

DETAILED BREAKDOWN
────────────────────────────────────────────────────────────────────────────

Acceptance Criteria: [X]/[N] complete
  ✅ Architecture: Key structural requirement met
  ✅ Functional: Core user flow works
  ⏳ Error: Critical error handling (in progress)
  ⬜ Non-Functional: Performance requirement
  ⬜ Edge Case: Lifecycle behavior

[If detailed plan exists:]
Implementation Tasks: [X]/[N] complete
  Phase 1 (Foundation): [X]/[Y] complete
  Phase 2 (Core Logic): [X]/[Y] complete
  Phase 3 (Integration): [X]/[Y] complete
  Testing: [X]/[Y] complete

────────────────────────────────────────────────────────────────────────────

DEPENDENCIES & BLOCKERS
────────────────────────────────────────────────────────────────────────────

Dependencies: [status]
  ✅ #215: Fix Auth0 Token Refresh (completed)
  ⏳ #218: Add UIState Helper (in-progress - BLOCKING)

This PRD blocks:
  ⏳ #220: Complete Auth Refactor (waiting)
  ⏳ android-signup: Refactor Signup Flow (waiting)

────────────────────────────────────────────────────────────────────────────

[If branch exists:]
GIT STATUS
────────────────────────────────────────────────────────────────────────────

Branch: [branch-name]
  Status: [X] commits ahead, [Y] commits behind main
  [If behind > 0:]
  ⚠️  Branch is behind main - consider rebasing
  [If age > 7 days:]
  ⚠️  Branch is [N] days old - may be stale

Commits: [N] total
  Last commit: [message] ([time ago])

────────────────────────────────────────────────────────────────────────────

[If PR exists:]
PULL REQUEST STATUS
────────────────────────────────────────────────────────────────────────────

PR: #[pr-number] ([state])
  Title: [pr-title]
  URL: [pr-url]

  Review Status: [approved/changes-requested/pending]
  Mergeable: [yes/no/conflicts]
  Checks: [passing/failing/pending]

  Reviews:
    ✅ [reviewer1]: Approved
    ⏳ [reviewer2]: Pending
    ❌ [reviewer3]: Changes requested

────────────────────────────────────────────────────────────────────────────

RECOMMENDATIONS
────────────────────────────────────────────────────────────────────────────

Next Actions:
  [Based on status, provide 2-3 actionable next steps]

[Examples based on phase:]

[If in Development:]
  1. ✨ Continue implementation: /prdx:dev:start [slug]
  2. 📋 Review plan: Read .claude/prds/[filename]
  3. ⚠️  Rebase branch: git rebase origin/main (branch is behind)

[If Development complete:]
  1. ✅ Run verification: /prdx:dev:check [slug]
  2. 🚀 Create PR: /prdx:dev:push [slug]

[If PR created:]
  1. 👀 Address review comments
  2. 🔄 Update PR: git push (after changes)
  3. 📝 Sync status: /prdx:sync [slug]

[If completed:]
  1. 🎉 Mark as closed: /prdx:close [slug]
  2. 🔗 Check what's unblocked: /prdx:deps [slug]
  3. 🆕 Start next feature: /prdx:wizard

Warnings:
  [If any blocking issues, dependency problems, or stale branches]

  [Example warnings:]
  ⚠️  Blocked by #218 (in-progress) - cannot start until completed
  ⚠️  Branch is 10 days old - consider rebasing or archiving
  ⚠️  PR has merge conflicts - rebase needed
  ⚠️  No commits in 7 days - work stalled?

────────────────────────────────────────────────────────────────────────────

QUICK REFERENCE
────────────────────────────────────────────────────────────────────────────

Files:
  PRD: .claude/prds/[filename]
  [If impl plan:] Plan: .claude/prds/impl-plans/[slug]-impl-plan.md

Links:
  [If issue:] Issue: https://github.com/[org]/[repo]/issues/[number]
  [If PR:] PR: https://github.com/[org]/[repo]/pull/[number]

Commands:
  /prdx:update [slug]       # Update PRD
  /prdx:dev:start [slug]    # Start/continue work
  /prdx:dev:check [slug]    # Verify implementation
  /prdx:dev:push [slug]     # Create PR
  /prdx:deps [slug]         # View dependencies
  /prdx:help                # All commands

╚════════════════════════════════════════════════════════════════════════════╝
```

---

## Variation by Status

### For "draft" status:
- Show planning progress
- Suggest: `/prdx:publish [slug]` or `/prdx:dev:start [slug]`
- Highlight dependencies if any

### For "published" status:
- Show issue link
- Suggest: `/prdx:dev:start [slug]` to begin work
- Check if dependencies are ready

### For "in-progress" status:
- Detailed task breakdown
- Git branch status
- Show commits and activity
- Highlight blocking dependencies
- Suggest: continue work or push for review

### For "in-review" status:
- PR status front and center
- Review status and comments
- Suggest: address feedback or sync status

### For "completed" status:
- Summary of completed work
- Timeline from start to finish
- PRDs that are now unblocked
- Suggest: `/prdx:close [slug]` if not yet closed

---

## Edge Cases

**PRD not found:**
```
❌ PRD not found: [slug]

Try:
  - /prdx:list (show all PRDs)
  - /prdx:search <keyword>
```

**Minimal PRD (just created):**
```
Status: draft

This PRD was just created.

Next steps:
  1. Review and refine: Read .claude/prds/[filename]
  2. Publish to GitHub: /prdx:publish [slug]
  3. Start implementation: /prdx:dev:start [slug]
```

**Complex dependencies:**
- Show full dependency tree
- Highlight critical path
- Calculate if ready to start

---

## Implementation Notes

- Use visual progress bars (Unicode block characters)
- Color code status if terminal supports it:
  - Green: completed/success
  - Yellow: in-progress/pending
  - Red: blocked/errors
  - Blue: in-review
- Calculate accurate time estimates from git history
- Pull real-time data from GitHub when possible
- Show actionable next steps, not just status
- Make it scannable - important info stands out

## Integration

This command ties together information from:
- PRD metadata and content
- Git branch status
- GitHub issues and PRs
- Dependency relationships
- Implementation plan progress

It's the "control panel" for a PRD - everything you need to know at a glance.
