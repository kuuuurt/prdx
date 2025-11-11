| description | argument-hint |
| Sync PRD status/updates to linked GitHub issue | Feature slug or leave empty for context |

# Sync PRD to GitHub Issue

> **Keep GitHub issues in sync with PRD changes**
> Updates issue status, labels, and posts PRD updates as comments

## Scope

**`/prdx:sync`** manages **GitHub Issues** ↔ PRD synchronization.
**`/prdx:dev:push`** manages **GitHub PRs** (separate concern).

**Clean separation:**
- Issues = Planning/tracking (this command)
- PRs = Code review (dev:push command)

---

## Usage

```bash
# Sync specific PRD
/prdx:sync android-219

# Sync current PRD from context
/prdx:sync

# Force sync even if no changes detected
/prdx:sync android-219 --force
```

---

## Phase 1: Load PRD and Context

**Find PRD with context awareness:**

1. **Load context:**
   ```bash
   source .prdx-context 2>/dev/null || true
   ```

2. **Determine PRD:**
   - If slug provided: use it
   - If no slug + context exists: use `LAST_PRD_SLUG`
   - If neither: list PRDs and ask user to select

3. **Read PRD:**
   - Parse metadata: Issue number, status, dependencies
   - Check if issue exists (must have `**Issue**: #[number]`)
   - If no issue: error and suggest `/prdx:publish` first

---

## Phase 2: Detect Changes

**Compare PRD with last sync:**

1. **Check sync history** (stored in PRD metadata):
   ```markdown
   **Last Synced**: [YYYY-MM-DD HH:MM] | **Sync Hash**: [hash]
   ```

2. **Calculate current hash:**
   - Hash of: Goal + Acceptance Criteria + Approach + Status
   - If hash matches last sync: no changes detected
   - If `--force`: skip hash check

3. **Detect specific changes:**
   - Status changed? (draft → published → in-progress → etc.)
   - Acceptance criteria added/modified?
   - Approach updated?
   - Dependencies changed?
   - PRD revised? (check Revision History section)

4. **Display changes:**
   ```
   Changes detected since last sync (2 days ago):

   Status: in-progress → in-review
   Acceptance Criteria: 1 new criterion added
   Revision: Updated 2025-11-10 (added OAuth support)
   ```

5. **If no changes and not forced:**
   ```
   ✓ PRD is already in sync with issue #219
   Last synced: 2 hours ago

   Use --force to sync anyway
   ```

---

## Phase 3: Sync to GitHub Issue

**Update issue based on PRD changes:**

1. **Update issue status via labels:**

   **PRD Status → GitHub Labels:**
   - `draft` → No sync (issue shouldn't exist yet)
   - `published` → `status: todo`
   - `in-progress` → `status: in-progress`
   - `in-review` → `status: in-review` (when PR exists)
   - `implemented` → `status: done`
   - `completed` → Close issue

   ```bash
   # Remove old status label
   gh issue edit [number] --remove-label "status: todo"
   # Add new status label
   gh issue edit [number] --add-label "status: in-progress"
   ```

2. **Post update comment to issue:**

   **If status changed:**
   ```bash
   gh issue comment [number] --body "$(cat <<'EOF'
   ## 📊 Status Update

   **Status**: published → in-progress
   **Branch**: feat/android-219-biometric
   **Started**: 2025-11-10

   Implementation has begun.
   EOF
   )"
   ```

   **If PRD revised:**
   ```bash
   gh issue comment [number] --body "$(cat <<'EOF'
   ## 🔄 PRD Updated

   **Revision**: #2 (2025-11-10)
   **Reason**: [reason from PRD revision history]

   ### Changes
   - ~~Old approach~~ → New approach with OAuth
   - **NEW**: Added Google/GitHub OAuth support

   **Full PRD**: `.claude/prds/android-219-biometric.md`
   EOF
   )"
   ```

   **If acceptance criteria changed:**
   ```bash
   gh issue comment [number] --body "$(cat <<'EOF'
   ## ✅ Acceptance Criteria Updated

   **Added**:
   - [ ] OAuth providers support Google and GitHub

   **Current Status**: 3/5 complete
   EOF
   )"
   ```

3. **Update issue body** (if major changes):

   Only if: First sync OR revision count changed

   ```bash
   gh issue edit [number] --body "$(cat <<'EOF'
   [Updated issue body with current PRD goal and ACs]
   EOF
   )"
   ```

4. **Handle dependencies:**

   If dependencies changed:
   ```bash
   # Add references in issue body
   gh issue edit [number] --body "$(cat <<'EOF'
   ...

   **Depends on**: #215, #218
   **Blocks**: #220
   EOF
   )"
   ```

---

## Phase 4: Update PRD Metadata

**Record sync in PRD:**

1. **Update sync metadata:**
   ```markdown
   **Last Synced**: 2025-11-10 15:30 | **Sync Hash**: a3f9c2b1
   ```

2. **Add sync history entry** (optional, for auditing):
   ```markdown
   ---

   ## Sync History

   ### 2025-11-10 15:30
   - Status synced: in-progress
   - Label updated: status: in-progress
   - Comment posted: Status update

   ### 2025-11-08 10:15
   - Status synced: published
   - Label updated: status: todo
   - Issue created: #219
   ```

---

## Phase 5: Display Summary

**Show what was synced:**

```
✓ Synced to GitHub Issue #219

Changes applied:
  ✓ Status: in-progress → in-review
  ✓ Label: "status: in-review" added
  ✓ Comment: Status update posted
  ✓ PRD metadata: Last synced timestamp updated

Issue: https://github.com/org/repo/issues/219

Last synced: Just now
Previous sync: 2 days ago
```

---

## When to Use This Command

**Use `/prdx:sync` when:**
- ✅ PRD status changes (draft → published → in-progress → etc.)
- ✅ PRD is updated/revised (via `/prdx:update`)
- ✅ Acceptance criteria change
- ✅ Dependencies change
- ✅ Want to keep issue in sync with PRD state

**Don't need `/prdx:sync` for:**
- ❌ Creating PR (use `/prdx:dev:push` - handles PR workflow)
- ❌ Creating issue (use `/prdx:publish` - creates issue initially)
- ❌ Closing issue (use `/prdx:close` - closes both PRD and issue)

**Flow:**
```
/prdx:publish     → Creates GitHub issue from PRD
/prdx:sync        → Syncs PRD updates to issue (as needed)
/prdx:dev:push    → Creates PR, links to issue
/prdx:close       → Marks complete, closes issue
```

---

## Edge Cases

**No issue linked:**
```
❌ PRD has no linked GitHub issue

Create an issue first:
  /prdx:publish android-219
```

**Issue doesn't exist:**
```
⚠️ Issue #219 not found on GitHub

Options:
1. Remove issue reference from PRD
2. Create issue with /prdx:publish
3. Update issue number manually
```

**GitHub CLI not available:**
```
❌ GitHub CLI (gh) not found

Install: brew install gh
Or manually sync at: https://github.com/org/repo/issues/219
```

**No changes detected:**
```
✓ PRD is already in sync with issue #219

Last synced: 2 hours ago
No changes detected

Use --force to sync anyway
```

**PRD has PR but issue status outdated:**
```
Syncing to issue #219...

Note: PR #234 exists for this PRD
Updating issue status to "in-review" to reflect PR state

✓ Synced successfully
```

---

## Integration with Other Commands

**`/prdx:publish`** → Creates issue, sets initial metadata
- First sync happens automatically
- Issue number saved to PRD

**`/prdx:update`** → Updates PRD
- **Does NOT auto-sync** (you control when)
- Run `/prdx:sync` after update to push changes to issue

**`/prdx:dev:start`** → Changes PRD status to "in-progress"
- **Does NOT auto-sync**
- Run `/prdx:sync` to update issue status

**`/prdx:dev:push`** → Creates PR
- Links PR to issue (via issue number in PR description)
- Updates **PR**, not issue directly
- Run `/prdx:sync` to update issue status to "in-review"

**`/prdx:close`** → Marks PRD complete
- Closes both PRD and GitHub issue
- Final sync happens automatically

---

## Examples

**After updating PRD:**
```bash
/prdx:update android-219
# Made changes to PRD...
/prdx:sync android-219
→ Posts update comment to issue #219
```

**After starting implementation:**
```bash
/prdx:dev:start android-219
# PRD status changed to "in-progress"
/prdx:sync
→ Updates issue status label
```

**Check if sync needed:**
```bash
/prdx:show android-219
→ Shows: "Last synced: 2 days ago, changes detected"

/prdx:sync android-219
→ Syncs latest changes
```

**Force sync (even if no changes):**
```bash
/prdx:sync android-219 --force
→ Syncs anyway, useful for fixing manual edits
```

---

## Important Rules

### Scope
- **ONLY syncs to GitHub Issues** (not PRs)
- PR management is separate (handled by `/prdx:dev:push`)

### When It Runs
- **MANUAL command** - you control when to sync
- **NOT automatic** - other commands don't auto-sync
- **Exception**: `/prdx:publish` and `/prdx:close` do auto-sync

### What It Syncs
- ✅ PRD status → Issue status labels
- ✅ PRD updates → Issue comments
- ✅ Acceptance criteria → Issue comments
- ✅ Dependencies → Issue body
- ❌ NOT code changes (that's PR territory)
- ❌ NOT commits (that's git territory)

### Hash-Based Detection
- Prevents unnecessary syncs
- Detects: status, ACs, approach, revision changes
- Use `--force` to bypass hash check

### Context Awareness
- Remembers last PRD (can omit slug)
- Reads `.prdx-context` file
- Works with `/prdx:dev:start` and `/prdx:dev:push` context

---

## Comparison with Dev Commands

| Command | Manages | When to Use |
|---------|---------|-------------|
| `/prdx:sync` | GitHub Issues | After PRD updates, status changes |
| `/prdx:dev:push` | GitHub PRs | After implementation, create PR |
| `/prdx:publish` | Creates issue | Initial issue creation from PRD |
| `/prdx:close` | Closes both | Mark feature complete |

**Clean separation of concerns:**
- Issues = Planning/tracking lifecycle
- PRs = Code review lifecycle
