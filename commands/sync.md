| description | argument-hint |
| Bidirectional sync between GitHub issue and local PRD | PRD filename/slug or issue number |

# Feature Sync

> **Be simple. Be pragmatic. One phase = one committable work.**
> Smart bidirectional sync between GitHub issues and local PRDs.

---

## Phase 1: Identify Sync Target & Direction

**Goal**: Determine what to sync and detect optimal sync direction.

**Parse user input:**

1. **PRD filename or slug** (e.g., `android-feature-bug-fix` or `android-feature-bug-fix.md`):
   - Find PRD in `.claude/prds/`
   - Extract issue number from PRD metadata (`**Issue**: #123`)
   - If no issue number: **STOP** and suggest `/prdx:publish` first

2. **Issue number or URL** (e.g., `123` or `#123` or full GitHub URL):
   - Detect repo from current directory (your-backend-project/android/ios)
   - Check if local PRD exists with this issue number
   - If no local PRD: proceed with GitHub → Local sync (original behavior)

**Verify GitHub CLI:**
```bash
gh auth status
```
If not authenticated: **STOP** and show error

---

## Phase 2: Smart Sync Direction Detection

**Goal**: Compare timestamps to determine what changed and needs syncing.

**Fetch both sources:**

1. **Load local PRD**:
   - Read PRD file from `.claude/prds/`
   - Extract metadata: Status, Issue, Created, Last Modified (file timestamp)
   - Parse "Sync History" section for last sync timestamp
   - Store PRD content hash for change detection

2. **Fetch GitHub issue**:
   ```bash
   cd your-[project] && gh issue view [number] --json title,body,labels,state,createdAt,updatedAt
   ```
   - Extract `updatedAt` timestamp from GitHub
   - Store issue content

**Compare and decide sync direction:**

```
Decision Matrix:

1. GitHub issue updatedAt > Last local sync timestamp
   AND local PRD NOT modified since last sync
   → SYNC: GitHub → Local (one-way)

2. Local PRD modified > Last sync timestamp
   AND GitHub issue NOT updated since last sync
   → SYNC: Local → GitHub (post comment)

3. BOTH updated since last sync
   → CONFLICT: Prompt user (show diff, let user choose)

4. Neither updated since last sync
   → NO SYNC NEEDED: Report "Already in sync"
```

**Display sync plan:**
```
📋 Sync Analysis: [feature-name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Local PRD:  .claude/prds/[filename]
            Last modified: [timestamp]
            Last sync: [timestamp or "never"]

GitHub:     [org/repo] #[number]
            Last updated: [timestamp]
            Status: [open/closed]

Decision:   [GitHub → Local / Local → GitHub / CONFLICT / In Sync]
```

---

## Phase 3: Resolve Conflicts (If Needed)

**Goal**: Handle cases where both local and GitHub were modified.

**Only runs if CONFLICT detected in Phase 2.**

**Show differences:**
```
⚠️ CONFLICT: Both local and GitHub updated since last sync

Local changes:
- Modified: [section names]
- Last edit: [timestamp]

GitHub changes:
- Modified: [timestamp]
- Comment activity: [count] new comments

How to resolve?
1. Keep local changes and push to GitHub (Local → GitHub)
2. Pull GitHub changes and update local (GitHub → Local)
3. Show detailed diff to merge manually
4. Cancel sync

Choose (1/2/3/4):
```

**If option 3 (detailed diff):**
- Show section-by-section comparison
- Highlight changed lines
- Let user edit PRD directly
- After manual merge, post summary comment to GitHub

---

## Phase 4: Execute Sync (GitHub → Local)

**Goal**: Pull GitHub issue content and update local PRD.

**Only runs if sync direction is GitHub → Local (or user chose option 2 in conflict resolution).**

**Create/find local filename:**

1. If syncing from issue number only (no existing PRD):
   - Clean issue title: remove `[Feature]`, `Feature:`, `feat:` prefixes
   - Convert to slug: lowercase, hyphenated
   - Add project prefix: `[project]-[slug].md`

2. If syncing to existing PRD: use existing filename

**Parse GitHub issue content:**
- Extract markdown sections: `## Problem`, `## Goal`, `## Acceptance Criteria`, etc.
- Expand `<details>` sections
- Preserve checkbox states: `- [ ]`, `- [x]`
- Extract issue metadata: title, labels, state, timestamps

**If creating new PRD:**
```markdown
# [Issue Title]

**Project**: [project] | **Status**: synced | **Issue**: #[number] | **Created**: [date]

---

## Problem
[From issue]

## Goal
[From issue]

**Out of scope**: [From issue if present]

---

## Acceptance Criteria
[From issue - preserve checkboxes]

---

## Approach
[From issue]

---

## Implementation
[From issue implementation plan]

---

## Notes

**Synced from GitHub**: #[number] on [date]

---

## Sync History
- **[date]**: Initial sync from issue #[number]
```

**If updating existing PRD (merge mode):**
- Compare sections between local and GitHub
- Add new content with `**Updated from GitHub ([date])**:` marker
- Use strikethrough for changed content:
  ```markdown
  ~~[Old local version]~~ *(Updated from GitHub)*

  **From GitHub ([date])**: [New GitHub version]
  ```
- Update "Last Synced" timestamp in metadata
- Append to "Sync History" section:
  ```markdown
  - **[date]**: Synced from GitHub #[number] (merged updates)
  ```

---

## Phase 5: Execute Sync (Local → GitHub)

**Goal**: Push local PRD changes to GitHub issue as a comment.

**Only runs if sync direction is Local → GitHub (or user chose option 1 in conflict resolution).**

**Detect local changes:**
1. Compare current PRD with last synced version (from Sync History)
2. Identify changed sections: Problem, Goal, Acceptance Criteria, Implementation, etc.
3. Build a summary of changes

**Format GitHub comment:**
```markdown
🔄 **PRD Updated Locally**

The local PRD for this feature has been updated. Here's a summary of changes:

### Changes Made
- **[Section name]**: [brief description of change]
- **[Section name]**: [brief description of change]

### Updated Acceptance Criteria
[List any AC changes with checkboxes]

### Updated Implementation Plan
[List any task changes]

---

**Local PRD**: `.claude/prds/[filename]`
**Last synced**: [timestamp]

*This comment was automatically generated by `/prdx:sync`*
```

**Post comment to GitHub:**
```bash
cd your-[project] && gh issue comment [number] --body "[formatted comment]"
```

**Update PRD metadata:**
- Update "Last Synced" timestamp
- Append to "Sync History":
  ```markdown
  - **[date]**: Pushed local changes to GitHub #[number] (comment posted)
  ```

---

## Phase 6: Validate & Summarize

**Goal**: Provide clear feedback on sync operation results.

**Quality check and report:**

**For GitHub → Local sync:**
```
✅ PRD Synced: GitHub → Local

Source:    [org/repo] #[number]
Local:     .claude/prds/[filename]
Action:    [Created/Updated/Merged]
Direction: GitHub → Local

Summary:
- Title: [name]
- Acceptance Criteria: [count]
- Implementation Tasks: [count]
- GitHub Status: [open/closed]
- Last synced: [timestamp]

PRD Completeness:
✓ Problem: [OK/Missing]
✓ Goal: [OK/Missing]
✓ Acceptance Criteria: [count]
✓ Implementation: [count] tasks

Next steps:
- Review: /prdx:review [slug]
- Implement: /prdx:implement [slug]
```

**For Local → GitHub sync:**
```
✅ PRD Synced: Local → GitHub

Local:     .claude/prds/[filename]
GitHub:    [org/repo] #[number]
Action:    Comment posted with changes
Direction: Local → GitHub

Changes pushed:
- [Section 1]: [change description]
- [Section 2]: [change description]

Comment URL: [GitHub comment URL]
Last synced: [timestamp]

Next steps:
- View comment: gh issue view [number] --web
- Continue work: /prdx:implement [slug]
```

**For "already in sync":**
```
✅ Already in Sync

Local:  .claude/prds/[filename]
GitHub: [org/repo] #[number]

No changes detected since last sync ([timestamp]).
Both sources are up to date.

Next steps:
- Update PRD: /prdx:update [slug]
- Implement: /prdx:implement [slug]
```

**If manual merge was needed:**
```
✅ Conflict Resolved

PRD has been updated based on your choice.
Sync history recorded in PRD.

⚠️ If you chose "Show detailed diff":
   Search for "MERGED" markers in PRD for manual review.

Next steps:
- Review merged content in .claude/prds/[filename]
- Consider syncing again after reviewing
```

---

## Important Rules

- **SMART AUTO-DETECTION** - compare timestamps to determine sync direction automatically
- **PRESERVE LOCAL WORK** - never overwrite without user confirmation
- **TRACK SYNC HISTORY** - record every sync operation with timestamps
- **BIDIRECTIONAL SUPPORT** - handle both GitHub → Local and Local → GitHub
- **DETECT CONFLICTS** - prompt user when both sources changed
- **CLEAR FEEDBACK** - always show what happened and next steps
- **VALIDATE COMPLETENESS** - warn if PRD sections are missing

---

## Edge Cases

### No Issue Number in PRD
If user provides PRD slug but PRD has no `**Issue**: #[number]`:
```
❌ Cannot sync: No GitHub issue linked to this PRD

This PRD hasn't been published to GitHub yet.

Next steps:
- Publish to GitHub first: /prdx:publish [slug]
- Then sync: /prdx:sync [slug]
```

### Issue Closed on GitHub
If GitHub issue is closed but local PRD shows "in-progress":
```
⚠️ Status Mismatch

GitHub issue #[number] is CLOSED
Local PRD status: in-progress

Sync will proceed, but consider:
- Updating PRD status to "implemented" or "cancelled"
- Using /prdx:verify to check completion
```

### First Sync (No History)
If PRD has no "Sync History" section:
- Treat current PRD content as "local baseline"
- Add "Last Synced: never" to detection logic
- Any GitHub changes will trigger GitHub → Local prompt

### Deleted GitHub Issue
If issue number exists in PRD but issue is deleted on GitHub:
```
❌ Cannot sync: GitHub issue #[number] not found

The issue may have been deleted or you lack access.

Next steps:
- Verify issue exists: gh issue view [number]
- Remove issue link from PRD if deleted
- Create new issue: /prdx:publish [slug]
```

---

## Example Usage

```bash
# Sync by PRD slug (auto-detect direction)
/prdx:sync android-feature-bug-fix

# Sync by PRD filename (auto-detect direction)
/prdx:sync android-feature-bug-fix.md

# Sync from issue number (GitHub → Local)
/prdx:sync 216

# Sync from issue URL (GitHub → Local)
/prdx:sync https://github.com/your-org/your-android-project/issues/216
```

---

## Comparison with Other Commands

- **`/prdx:publish`**: One-way Local → GitHub (creates new issue)
- **`/prdx:sync`**: Bidirectional, auto-detect direction (updates existing issue/PRD)
- **`/prdx:update`**: Local-only PRD updates (optional GitHub sync)

**When to use `/prdx:sync`:**
- After updating GitHub issue and want to pull changes locally
- After updating local PRD and want to notify GitHub (as comment)
- Periodically to keep PRD and issue in sync
- When returning to a feature after time away
