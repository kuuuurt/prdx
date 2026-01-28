# Close PRD

Mark a PRD as completed when all work is done, PR is merged, and feature is deployed.

## Usage

```bash
/prdx:close <slug>
```

## Examples

```bash
/prdx:close android-219                    # Mark android-219 as completed
/prdx:close backend-auth-refactor          # Close backend PRD
```

## Instructions

You are helping the user close a PRD after all implementation work is complete.

### Phase 1: Validate PRD and Status

**Find and verify the PRD:**

1. **Find PRD file:**
   - If slug provided: `ls ~/.claude/plans/prdx-*[slug]*.md`
   - If multiple matches, prompt user to select
   - If not found, show error and suggest using `/prdx:list`

2. **Read PRD metadata:**
   - Check current status
   - Check for PR number
   - Check for issue number
   - Extract platform and dates

3. **Verify readiness to close:**
   ```
   Preparing to close PRD: [title]

   Current Status: [status]
   PR: [#number or "none"]
   Issue: [#number or "none"]

   Verification:
   ```

   - **If status is "draft" or "in-progress":**
     ```
     ⚠️  Warning: PRD status is "[status]"

     This PRD doesn't appear to be completed yet.
     Are you sure you want to close it? (y/n)

     Reasons to NOT close:
     - Work is still in progress
     - PR hasn't been created yet
     - PR hasn't been merged

     Reasons to close anyway:
     - Work was abandoned
     - Requirements changed and PRD is no longer relevant
     - Duplicate PRD
     ```

   - **If PR exists, check if it's merged:**
     ```bash
     gh pr view [pr-number] --json state,mergedAt
     ```
     If not merged:
     ```
     ⚠️  PR #[number] is not merged yet

     PR Status: [open/closed/draft]

     Options:
     1. Wait for PR to be merged (recommended)
     2. Close PRD anyway
     3. Cancel

     What would you like to do?
     ```

4. **Confirm closure:**
   Use AskUserQuestion to confirm:
   ```
   Ready to close this PRD?

   Title: [title]
   Platform: [platform]
   Status: [current] → completed
   PR: [number] (merged ✓)
   Issue: [number]

   This will:
   - Update status to "completed"
   - Add completion date
   - Archive the PRD

   Proceed? (y/n)
   ```

---

### Phase 2: Update PRD Metadata

**Mark PRD as completed:**

1. **Update status:**
   Use Edit tool to update:
   ```markdown
   **Status**: [current] → **Status**: completed
   ```

2. **Add completion date:**
   ```markdown
   **Completed**: [YYYY-MM-DD]
   ```

3. **Calculate duration (if Started date exists):**
   ```markdown
   **Duration**: [N days] (from [start-date] to [completion-date])
   ```

4. **Final metadata example:**
   ```markdown
   **Project**: android | **Status**: completed | **Created**: 2025-11-05
   **Issue**: #219 | **PR**: #245 | **Branch**: feat/android-219-login-fix
   **Started**: 2025-11-06 | **PR Created**: 2025-11-07 | **Completed**: 2025-11-08
   **Duration**: 2 days
   **Dependencies**: #215, #218 | **Blocks**: #220
   ```

---

### Phase 3: Optional Cleanup

**Ask about additional cleanup steps:**

Use AskUserQuestion with multi-select:
```
PRD marked as completed!

Would you like to perform additional cleanup? (select all that apply)
```

Options:
1. **Delete local branch** - Remove the feature branch locally
2. **Delete remote branch** - Remove the feature branch from GitHub (if already merged)
3. **Update blocked PRDs** - Remove this PRD from "Dependencies" in blocked PRDs
4. **Close GitHub issue** - Close the linked GitHub issue (if exists)

Handle each selected option:

#### Option 1: Delete local branch
```bash
git branch -D [branch-name]
```

#### Option 2: Delete remote branch
```bash
git push origin --delete [branch-name]
```

#### Option 3: Update blocked PRDs
- Find PRDs that list this PRD in their Dependencies
- Edit each to remove the dependency
- Show summary of updated PRDs

#### Option 4: Close GitHub issue
```bash
gh issue close [issue-number] --comment "Completed in PR #[pr-number]"
```

---

### Phase 4: Summary

**Display completion summary:**

```
╔════════════════════════════════════════════════════════════════════════════╗
║  PRD CLOSED SUCCESSFULLY                                                   ║
╚════════════════════════════════════════════════════════════════════════════╝

Feature: [title]
Platform: [platform]
Status: completed ✓

Timeline:
  Created:    [date]
  Started:    [date]
  PR Created: [date]
  Completed:  [date]
  Duration:   [N days]

Links:
  PRD:   ~/.claude/plans/[filename]
  Issue: #[number] [closed ✓ / still open]
  PR:    #[number] (merged ✓)

Cleanup Performed:
  ✓ Local branch deleted
  ✓ Remote branch deleted
  ✓ [N] blocked PRDs updated
  ✓ GitHub issue closed

Statistics:
  Commits: [N]
  Files changed: [N]
  Tasks completed: [N]

────────────────────────────────────────────────────────────────────────────

What's next?
  - Review completed work: gh pr view [pr-number]
  - Start blocked PRDs: /prdx:deps [slug] (to see what's unblocked)
  - Create new PRD: /prdx:prdx "feature description"

╚════════════════════════════════════════════════════════════════════════════╝
```

---

## Edge Cases

**PRD not found:**
```
❌ PRD not found: [slug]

Try:
- /prdx:list (show all PRDs)
- /prdx:search <keyword> (search PRDs)
```

**Already completed:**
```
ℹ️  PRD is already completed

Status: completed
Completed: [date]

Nothing to do!
```

**Multiple PRDs match:**
```
Multiple PRDs found for "[slug]":

1. android-219.md - Optimize LoginViewModel (in-progress)
2. android-219-v2.md - LoginViewModel Refactor v2 (draft)

Which one do you want to close?
```

---

## Implementation Notes

- Be conservative - warn if status suggests work isn't done
- Check PR merge status via GitHub API when possible
- Calculate accurate duration including only business/calendar days
- Update dependency chains to keep PRD relationships accurate
- Suggest next PRDs to work on based on what's now unblocked

## Integration with Other Commands

After closing, suggest:
```
Related commands:
- /prdx:deps [slug]      # See what PRDs are now unblocked
- /prdx:list             # View all PRDs
- /prdx:wizard           # Create next feature
```
