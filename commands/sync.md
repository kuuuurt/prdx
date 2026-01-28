---
description: "Sync PRD with current implementation state"
argument-hint: "[slug]"
---

# /prdx:sync - Sync PRD with Implementation

Update the PRD to reflect the current implementation state by analyzing commits, code changes, and test results.

## Usage

```bash
/prdx:sync backend-auth        # Sync specific PRD
/prdx:sync                     # Sync PRD for current branch
/prdx:sync --github            # Also sync to GitHub issue
```

## How It Works

This command analyzes the current implementation and updates the PRD to reflect:
- What was actually implemented (vs what was planned)
- Acceptance criteria completion status
- Implementation notes and technical details
- Any deviations or additions from the original plan

## Workflow

### Phase 1: Load PRD

**Find PRD file:**

```bash
# If slug provided
if [ -n "$SLUG" ]; then
  PRD_FILE=$(ls ~/.claude/plans/prdx-*${SLUG}*.md 2>/dev/null | head -1)
fi

# If no slug, detect from branch name
if [ -z "$PRD_FILE" ]; then
  BRANCH=$(git branch --show-current)
  # Extract slug from branch: feat/backend-auth -> backend-auth
  SLUG=$(echo "$BRANCH" | sed 's/^[^/]*\///')
  PRD_FILE=$(ls ~/.claude/plans/prdx-*${SLUG}*.md 2>/dev/null | head -1)
fi

if [ -z "$PRD_FILE" ]; then
  echo "❌ PRD not found"
  echo ""
  echo "Provide slug: /prdx:sync <slug>"
  echo "Or switch to feature branch"
  exit 1
fi
```

**Parse PRD:**

Extract from PRD file:
- Title
- Type (feature, bug-fix, refactor, spike)
- Platform
- Status
- Acceptance Criteria (with checkboxes)
- Branch name
- Existing Implementation Notes (if any)

### Phase 2: Analyze Implementation

**Get commits since branch divergence:**

```bash
# Get base branch
BASE_BRANCH=$(git merge-base main HEAD)

# Get all commits on this branch
git log ${BASE_BRANCH}..HEAD --oneline

# Get detailed commit messages
git log ${BASE_BRANCH}..HEAD --format="%H|%s|%b"
```

**Analyze changed files:**

```bash
# Files changed on this branch
git diff ${BASE_BRANCH}..HEAD --name-status

# Summary of changes
git diff ${BASE_BRANCH}..HEAD --stat
```

**Read key implementation files:**

Based on the platform and changed files, read the main implementation files to understand:
- Architecture decisions made
- Patterns used
- Key classes/functions created

**Check test status:**

```bash
# Find and run tests (platform-specific)
# Backend: bun test
# Android: ./gradlew test
# iOS: xcodebuild test
```

### Phase 3: Determine Acceptance Criteria Status

For each acceptance criterion in the PRD:

1. **Search code for implementation:**
   - Look for related functions, classes, UI components
   - Check if tests exist for the criterion

2. **Determine status:**
   - `[x]` - Implemented and tested
   - `[ ]` - Not implemented
   - `[~]` - Partially implemented (note what's missing)

3. **Build status report:**

```markdown
## Acceptance Criteria Status

- [x] User can log in with email/password
  - Implemented in `src/auth/login.ts:42`
  - Tested in `src/auth/__tests__/login.test.ts`

- [x] Invalid credentials show error message
  - Implemented in `src/auth/login.ts:67`
  - Tested in `src/auth/__tests__/login.test.ts`

- [ ] Password reset via email
  - Not implemented (deferred to next sprint)
```

### Phase 4: Build Implementation Summary

Create a comprehensive implementation summary:

```markdown
## Implementation Notes

**Branch:** {BRANCH}
**Implemented:** {DATE}
**Commits:** {COMMIT_COUNT}

### Architecture

{Description of architectural decisions and how implementation fits into codebase}

### Key Changes

**Created:**
- `path/to/new/file.ts` - {purpose}
- `path/to/another/file.ts` - {purpose}

**Modified:**
- `path/to/existing/file.ts` - {what changed}

### Testing

**Test Files:**
- `path/to/test.ts` - {COUNT} tests

**Coverage:**
- {SUMMARY of what's tested}

### Deviations from Plan

{List any differences between original PRD and actual implementation}
- Original: {what was planned}
- Actual: {what was implemented}
- Reason: {why it changed}

### Commits

{List of commits with conventional commit format}
- `abc1234` feat: add login endpoint
- `def5678` feat: add auth middleware
- `ghi9012` test: add login tests
```

### Phase 5: Update PRD

**Update Status:**

```bash
# Change status based on implementation state
if all_acceptance_criteria_complete; then
  STATUS="review"
elif any_acceptance_criteria_complete; then
  STATUS="in-progress"
else
  STATUS="planning"
fi
```

**Update Acceptance Criteria checkboxes:**

Mark completed criteria with `[x]`.

**Append/Update Implementation Notes:**

If Implementation Notes section exists, update it.
If not, append it after the main PRD content.

**Write updated PRD file.**

### Phase 6: GitHub Sync (Optional)

If `--github` flag provided and PRD has linked issue:

```bash
# Update issue status label
gh issue edit {NUMBER} --remove-label "status: todo"
gh issue edit {NUMBER} --add-label "status: in-progress"

# Post sync comment
gh issue comment {NUMBER} --body "$(cat <<'EOF'
## 📊 Implementation Sync

**Status:** in-progress
**Branch:** {BRANCH}
**Commits:** {COUNT}

### Progress
{ACCEPTANCE_CRITERIA_STATUS}

### Recent Commits
{LAST_5_COMMITS}

---
Synced via `/prdx:sync`
EOF
)"
```

### Phase 7: Display Summary

```
✅ PRD Synced!

📄 PRD: {PRD_FILE}
📊 Status: {STATUS}

Acceptance Criteria:
  ✓ {COMPLETED_COUNT}/{TOTAL_COUNT} complete

Changes detected:
  - {COMMIT_COUNT} commits analyzed
  - {FILES_CREATED} files created
  - {FILES_MODIFIED} files modified

Updated:
  ✓ Status: planning → in-progress
  ✓ Acceptance criteria: 3/5 marked complete
  ✓ Implementation notes: added/updated

{If --github}
GitHub Issue #123:
  ✓ Label updated: status: in-progress
  ✓ Progress comment posted
```

## Options

### --github

Also sync changes to linked GitHub issue:

```bash
/prdx:sync backend-auth --github
```

Updates:
- Issue status label
- Posts progress comment

### --dry-run

Show what would be updated without making changes:

```bash
/prdx:sync --dry-run
```

### --force

Overwrite existing implementation notes:

```bash
/prdx:sync --force
```

Without force, new notes are appended to existing notes.

## Error Handling

### PRD Not Found

```
❌ PRD not found

Available PRDs:
- backend-auth (in-progress)
- android-login (planning)

Usage: /prdx:sync <slug>
```

### Not on Feature Branch

```
❌ Not on a feature branch

Current branch: main

Switch to feature branch:
  git checkout feat/backend-auth

Or specify PRD:
  /prdx:sync backend-auth
```

### No Implementation Found

```
⚠️  No implementation found

Branch has no commits yet.
PRD status unchanged.

Start implementation:
  /prdx:implement backend-auth
```

### GitHub CLI Not Available

```
⚠️  GitHub CLI not found

PRD updated locally.
GitHub sync skipped.

Install: brew install gh
```

## When to Use This Command

**Use `/prdx:sync` when:**
- ✅ Mid-implementation checkpoint
- ✅ Before creating PR (to update PRD)
- ✅ After making changes outside `/prdx:implement`
- ✅ To update acceptance criteria status
- ✅ To document what was actually built

**Automatic sync happens in:**
- `/prdx:implement` - Updates PRD after completion
- `/prdx:push` - Ensures PRD is current before PR

**Manual sync for:**
- Manual code changes
- Implementation deviations
- Mid-sprint status updates

## Examples

### Basic Sync

```
User: /prdx:sync backend-auth

→ Finds ~/.claude/plans/backend-auth.md
→ Analyzes 8 commits on feat/backend-auth
→ Checks acceptance criteria against code
→ Updates PRD with implementation notes

✅ PRD Synced!

📄 PRD: ~/.claude/plans/backend-auth.md
📊 Status: in-progress

Acceptance Criteria:
  ✓ 4/5 complete

Updated:
  ✓ Acceptance criteria marked
  ✓ Implementation notes added
```

### Sync from Current Branch

```
User: /prdx:sync

→ Detects branch: feat/android-biometric
→ Finds matching PRD
→ Analyzes implementation

✅ PRD Synced!

📄 PRD: ~/.claude/plans/android-biometric.md
📊 Status: implemented

Acceptance Criteria:
  ✓ 5/5 complete

All criteria met!
```

### Sync with GitHub

```
User: /prdx:sync backend-auth --github

→ Updates PRD locally
→ Syncs to GitHub issue #42

✅ PRD Synced!

📄 PRD: ~/.claude/plans/backend-auth.md
📊 Status: in-progress

GitHub Issue #42:
  ✓ Label: status: in-progress
  ✓ Progress comment posted
  🔗 https://github.com/org/repo/issues/42
```

### Dry Run

```
User: /prdx:sync --dry-run

Proposed changes:

PRD: ~/.claude/plans/backend-auth.md
Status: planning → in-progress

Acceptance Criteria:
  [x] User can log in (was [ ])
  [x] Error messages shown (was [ ])
  [ ] Password reset (unchanged)

Implementation Notes:
  + Branch: feat/backend-auth
  + Implemented: 2025-11-28
  + 8 commits analyzed
  + 5 files created
  + 3 files modified

Run without --dry-run to apply changes.
```

## Integration with Other Commands

| Command | Sync Behavior |
|---------|---------------|
| `/prdx:plan` | Creates PRD (no sync needed) |
| `/prdx:implement` | Auto-syncs after completion |
| `/prdx:sync` | Manual sync anytime |
| `/prdx:push` | Reads synced PRD for PR description |
| `/prdx:close` | Final sync + close |

**Typical flow:**

```
/prdx:plan "add auth"     → Creates PRD
/prdx:implement auth      → Auto-syncs at end
# Manual changes...
/prdx:sync auth           → Update PRD with manual changes
/prdx:push auth           → Create PR from synced PRD
```

## Implementation Notes

### Commit Analysis

Commits are analyzed to understand:
- **Type**: feat, fix, refactor (from conventional commits)
- **Scope**: What area of code changed
- **Description**: What the change does

This information populates the Implementation Notes section.

### Acceptance Criteria Matching

The sync process attempts to match acceptance criteria to code by:

1. **Keyword extraction**: Pull key terms from each criterion
2. **Code search**: Find related functions, classes, tests
3. **Test verification**: Check if tests exist for the criterion

If uncertain, marks as `[ ]` with a note to verify manually.

### Preserving Manual Edits

By default, sync appends to existing Implementation Notes rather than overwriting. Use `--force` to replace entirely.

This allows:
- Manual additions to be preserved
- Multiple sync operations without data loss
- Human refinement of auto-generated notes
