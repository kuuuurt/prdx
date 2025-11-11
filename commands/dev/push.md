| description | argument-hint |
| Auto-verify and create PR with implementation plan | Feature slug or leave empty [--skip-check] |

# Create Pull Request

> **Auto-verify then create PR**
> Runs quality checks automatically, then creates PR with comprehensive description
> Manages GitHub **PRs only** (use `/prdx:sync` for issue updates)

## Options

- `--skip-check` - Skip automatic verification (not recommended)

---

## Phase 1: Automatic Verification

**Run quality checks before creating PR:**

1. **Find PRD:**
   - If slug provided: `ls .claude/prds/*[slug]*.md`
   - If not provided: Use context (last PRD worked on) or list and ask
   - **DO NOT PROCEED** without valid PRD

2. **Check for --skip-check flag:**
   - If present: Skip to Phase 2
   - If not present: Run verification

3. **Run /prdx:dev:check workflow inline:**

   Execute verification (from dev/check.md):
   - Load PRD and parse acceptance criteria
   - Parse implementation tasks
   - Run multi-agent verification:
     - Implementation quality (platform agent)
     - Testing verification (code-reviewer)
     - Security & performance (performance-optimizer)
   - Verify git commits exist
   - Validate file changes

4. **Display verification results:**
   ```
   Running pre-PR verification...

   ✓ Acceptance Criteria: 5/5 complete (100%)
   ✓ Implementation Tasks: 12/12 complete (100%)
   ✓ Code Quality: 9.2/10 (Excellent)
   ✓ Test Coverage: 87% (Target: 70%)
   ✓ Security & Performance: PASS
   ✓ Git Commits: 12 commits, conventional format

   Verification PASSED - Ready for PR
   ```

5. **Handle verification failures:**

   If verification fails:
   ```
   ⚠️ Verification Issues Found:

   ❌ Acceptance Criteria: 3/5 complete (60%)
      Missing: AC #3, AC #5

   ⚠️ Test Coverage: 45% (Below target: 70%)
      Missing tests: AuthViewModel, TokenRefresh

   ❌ Security: 1 issue
      Issue: API keys not stored securely

   Options:
   1. Fix issues and run again
   2. Continue anyway (not recommended)
   3. Cancel

   What would you like to do?
   ```

   - If user chooses to continue: proceed with warning in PR
   - If user chooses to fix: exit and show recommendations
   - If user chooses to cancel: exit

6. **Store verification results for PR description**

---

## Phase 2: Validate Current State

**Ensure everything is ready for PR:**

1. **Find PRD and Implementation Plan:**
   - If slug provided: `ls .claude/prds/*[slug]*.md`
   - If not: list all PRDs and ask user to select
   - **DO NOT PROCEED** without valid PRD

2. **Load implementation plan:**
   - Check: `.claude/prds/impl-plans/[slug]-impl-plan.md`
   - If missing: **WARN** but allow proceeding (will use PRD instead)

3. **Verify implementation status:**
   - Check PRD status is "implemented" or "in-progress"
   - If "draft": **WARN** that feature may not be implemented yet
   - If implementation plan exists, check for "Implementation Notes"

4. **Detect project:**
   - Extract project from PRD metadata (backend/android/ios)
   - Navigate to project directory: `cd your-[project]`

---

## Phase 2: Verify Branch & Commits

**Ensure clean git state:**

1. **Check current branch:**
   ```bash
   git branch --show-current
   ```
   - If on `main`/`master`/`develop`: **ERROR** - can't create PR from main
   - Verify branch matches PRD metadata (if specified)

2. **Check for uncommitted changes:**
   ```bash
   git status
   ```
   - If uncommitted changes: **WARN** and suggest committing first
   - Option to commit remaining changes or abort

3. **Verify commits exist:**
   ```bash
   git log --oneline
   ```
   - Ensure branch has commits
   - Check commits follow conventional format

4. **Check remote tracking:**
   ```bash
   git rev-parse --abbrev-ref --symbolic-full-name @{u}
   ```
   - Check if branch tracks remote
   - If not tracking: will need to push with `-u` flag

---

## Phase 3: Prepare PR Description

**Build skimmable 1-pager PR description:**

**Design Principles:**
- **Scannable**: Use bullets, short sentences, visual hierarchy
- **1-pager**: Should fit on one screen without scrolling
- **No walls of text**: Maximum 2-3 sentences per section
- **Essential only**: What changed, why, what to review

**Template Structure:**

```markdown
## What

[1-2 sentence summary from PRD goal - the "why" and high-level "what"]

## Changes

[3-5 bullet points of key changes - files/components affected, not implementation details]
- New: [Component/Feature]
- Updated: [Component/Feature]
- Fixed: [Component/Feature]

## Testing

✅ [X] tests passing | ✅ Coverage: [Y]% | [⚠️ Manual test needed: [scenario]]

## Review Focus

[1-2 specific areas reviewers should pay attention to]
- [ ] [Specific file/logic to review]
- [ ] [Edge case to verify]

---
Closes #[issue] | [Verification passed ✅ / ⚠️ Warnings]
```

**Detailed Guidance:**

1. **What section** (2-3 lines max):
   - Pull from PRD goal
   - Format: "This PR [adds/fixes/refactors] [X] to [achieve Y]"
   - Example: "Adds biometric authentication to replace password-only login for better UX and security"

2. **Changes section** (3-5 bullets max):
   - Focus on WHAT changed, not HOW
   - Group related changes
   - Use categories: "New:", "Updated:", "Fixed:", "Removed:"
   - Example bullets:
     - "New: `BiometricAuthService` handles fingerprint/face ID"
     - "Updated: `LoginViewModel` supports biometric flow"
     - "Fixed: Token refresh race condition"

3. **Testing section** (1 line):
   - Just the numbers and critical manual tests
   - Format: "✅ 23 tests | ✅ 87% coverage | ⚠️ Manual: Test on physical device"
   - If manual test needed, be specific about what/why

4. **Review Focus section** (2-3 checkboxes):
   - Guide reviewers to what matters
   - Specific files or logic patterns
   - Edge cases or security concerns
   - Example:
     - "[ ] Verify `BiometricAuthService.authenticate()` handles all failure modes"
     - "[ ] Check token storage uses Keychain (not UserDefaults)"

5. **Footer** (1 line):
   - Issue reference
   - Verification status from Phase 1
   - Format: "Closes #219 | Verification passed ✅" or "Closes #219 | ⚠️ Low test coverage (45%)"

**If Implementation Plan Exists:**
- Extract 3-5 key completed tasks for "Changes"
- Pull verification results for footer
- Use deviations for "Review Focus" if applicable

**If No Implementation Plan:**
- Use PRD Approach section for "Changes"
- Use PRD Acceptance Criteria for "Review Focus"
- Format ACs as review checkboxes

**Real-World Examples:**

<details>
<summary><b>Example 1: Backend Feature</b></summary>

```markdown
## What

Adds real-time location tracking API for drivers to enable live map updates in rider app.

## Changes

- New: `LocationService` handles WebSocket connections and Redis pub/sub
- New: `POST /api/v1/driver/location` endpoint validates and broadcasts location
- Updated: Driver model includes `last_location_update` timestamp
- Updated: Auth middleware validates driver session tokens

## Testing

✅ 15 tests passing | ✅ 89% coverage | ⚠️ Manual: Test WebSocket reconnection on network drop

## Review Focus

- [ ] Verify rate limiting prevents location spam (max 1/sec per driver)
- [ ] Check Redis pub/sub scales to 10k+ concurrent drivers
- [ ] Validate location data sanitization (no PII leakage)

---
Closes #234 | Verification passed ✅
```

</details>

<details>
<summary><b>Example 2: Mobile Bug Fix</b></summary>

```markdown
## What

Fixes crash when users rotate device during biometric prompt on Android 12+.

## Changes

- Fixed: `BiometricPrompt` lifecycle handling in `LoginFragment`
- Updated: Prompt cancellation clears state properly
- Added: Rotation config change handling in manifest

## Testing

✅ 8 regression tests | ✅ Manual: Tested on Pixel 6 (Android 12 & 13)

## Review Focus

- [ ] Verify no memory leaks in Fragment lifecycle
- [ ] Check prompt works after multiple rotations

---
Closes #456 | ⚠️ Manual testing required
```

</details>

<details>
<summary><b>Example 3: Refactor</b></summary>

```markdown
## What

Simplifies LoginViewModel by removing Use Case layer and calling Auth0Client directly per new architecture.

## Changes

- Removed: `DoLoginUseCase` and `ConfirmOtpUseCase` (deprecated pattern)
- Updated: `LoginViewModel` calls `Auth0Client` directly
- Simplified: State management using `UIState` sealed class
- Updated: 12 tests adapted to new structure

## Testing

✅ 24 tests passing | ✅ 91% coverage | ✅ No manual test needed

## Review Focus

- [ ] Verify error handling matches previous behavior
- [ ] Check Login flow still works end-to-end

---
Closes #789 | Verification passed ✅
```

</details>

**Anti-Patterns to Avoid:**

❌ **Too verbose**:
```markdown
## Implementation Details
In this PR, I've implemented a comprehensive solution for...
[3 paragraphs of prose]
```

❌ **Too technical**:
```markdown
## Changes
- Refactored the LocationService class to implement the Observer pattern
  with a custom EventEmitter that uses WeakRefs to prevent memory leaks...
```

❌ **Task dump**:
```markdown
## What was done
- Created LocationService.ts file
- Added imports for Redis and Socket.io
- Wrote validateLocation function
- Added unit tests for validateLocation
- Updated package.json with new dependencies
[20 more bullets...]
```

✅ **Good**:
```markdown
## What
Adds real-time location tracking for drivers.

## Changes
- New: LocationService handles WebSocket + Redis
- New: POST /api/v1/driver/location endpoint
- Updated: Driver model + auth middleware

## Testing
✅ 15 tests | 89% coverage

## Review Focus
- [ ] Rate limiting (1 update/sec max)
- [ ] Redis pub/sub scalability
```

---

## Phase 4: Push & Create PR

**Push branch and create PR:**

1. **Push to remote:**
   ```bash
   git push -u origin [branch-name]
   ```
   - If already tracking remote: `git push`
   - If push fails: show error and suggest resolution

2. **Determine base branch:**
   - Default: `main`
   - Check if project uses `develop` or `master`
   - Ask user if unsure:
     ```
     Which base branch should this PR target?
     - main (default)
     - develop
     - master
     - [custom]
     ```

3. **Create PR using `gh` CLI:**
   ```bash
   gh pr create \
     --base [base-branch] \
     --title "[Conventional prefix]: [Feature name]" \
     --body "$(cat <<'EOF'
   [PR description built in Phase 3]
   EOF
   )"
   ```

   Conventional title prefix:
   - `feat:` - New feature
   - `fix:` - Bug fix
   - `refactor:` - Code refactoring
   - `test:` - Test additions
   - `chore:` - Maintenance

4. **Handle PR creation:**
   - If successful: capture PR number and URL
   - If fails: show error and suggest manual creation
   - If already exists: warn and provide link to existing PR

---

## Phase 5: Update Documents

**Link PR back to PRD and implementation plan:**

1. **Update PRD metadata automatically:**
   - Use Edit tool to update PRD status:
     ```markdown
     **Status**: in-progress → **Status**: in-review
     # OR
     **Status**: implemented → **Status**: in-review
     ```
   - Add or update `**PR**: #[number]` field
   - Add PR creation date:
     ```markdown
     **PR Created**: [YYYY-MM-DD]
     ```

   Final metadata example:
   ```markdown
   **Project**: android | **Status**: in-review | **Created**: [date]
   **Issue**: #[number] | **PR**: #[pr-number] | **Branch**: [branch-name]
   **Started**: [date] | **PR Created**: [date]
   **Dependencies**: [deps] | **Blocks**: [blocks]
   ```

2. **Update implementation plan:**
   - Add PR link to Implementation Notes section
   ```markdown
   ## Implementation Notes

   **Implemented**: [date] | **Branch**: [branch-name] | **PR**: #[pr-number]
   ...
   ```

**IMPORTANT:** PRD and implementation plan files are NEVER committed to git. They remain in `.claude/prds/` directory only.

---

## Phase 6: Display Summary

**Show PR creation summary:**

```
✅ Pull Request Created Successfully!

Feature: [Feature Name]
Project: [project]

PR Details:
- Number: #[pr-number]
- URL: [pr-url]
- Base: [base-branch] ← [feature-branch]
- Title: [pr-title]

Commits: [count]
Files changed: [count]

Description includes:
✅ Verification results
✅ Summary
✅ Task breakdown ([count] tasks)
✅ Technical approach
✅ Testing results
✅ Acceptance criteria ([count])
✅ Related PRD and implementation plan

Documents updated (local only, not committed):
✅ PRD: .claude/prds/[prd-filename]
✅ Implementation Plan: .claude/prds/impl-plans/[impl-plan-filename]

Next steps:
- Review PR at [pr-url]
- Request reviews from team
- Update issue status: /prdx:sync [slug]
- Address review comments if any
- Merge when approved
```

**Additional actions:**
1. Ask if they want to assign reviewers
2. Ask if they want to add labels
3. Remind about any project-specific PR checklist

---

## Example Usage

```bash
# Auto-verify and create PR (recommended)
/prdx:dev:push android-feature-bug-fix

# Continue from context (remembers last PRD)
/prdx:dev:push

# Skip verification (not recommended)
/prdx:dev:push android-219 --skip-check

# After PR, sync issue status
/prdx:dev:push android-219
/prdx:sync android-219    # Updates issue to "in-review"
```

---

## Important Rules

### PR Requirements
- **CLEAN GIT STATE** - No uncommitted changes
- **NOT ON MAIN** - Must be on feature branch
- **COMMITS EXIST** - Branch must have commits to push
- **CONVENTIONAL TITLE** - Use conventional commit prefix in PR title

### PR Description
- **USE IMPL PLAN** - Implementation plan is primary source
- **FALLBACK TO PRD** - Use PRD if no implementation plan
- **BE COMPREHENSIVE** - Include summary, tasks, testing, acceptance criteria
- **LINK DOCUMENTS** - Reference PRD, impl plan, and GitHub issue
- **SHOW DEVIATIONS** - Include any documented deviations

### Document Updates
- **UPDATE PRD** - Add PR number and update status (local only)
- **UPDATE IMPL PLAN** - Add PR link to implementation notes (local only)
- **NEVER COMMIT PRDS** - PRD and implementation plan files are NEVER committed to git

### Error Handling
- **DIRTY WORKING TREE** - Warn and suggest commit/stash
- **ON MAIN BRANCH** - Error and suggest checkout feature branch
- **NO COMMITS** - Error and suggest completing implementation
- **GH CLI NOT AVAILABLE** - Provide manual PR creation instructions
- **PR ALREADY EXISTS** - Warn and provide link

### User Communication
- **CLEAR SUMMARY** - Show what was created and next steps
- **PR URL** - Always display clickable PR URL
- **ASK FOR REVIEWERS** - Offer to assign reviewers
- **PROJECT CHECKLIST** - Remind about any project-specific requirements
