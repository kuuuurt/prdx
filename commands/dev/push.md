| description | argument-hint |
| Create PR with implementation plan as description | Feature slug or leave empty to list |

# Create Pull Request

> **Be simple. Be pragmatic. One phase = one committable work.**
> Create a PR with implementation plan as the description for comprehensive review.

---

## Phase 1: Validate Current State

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

**Build comprehensive PR description from implementation plan:**

1. **If implementation plan exists:**
   - Read entire implementation plan
   - Extract key sections for PR description:
     - Summary
     - Task Breakdown (what was done)
     - Technical Approach
     - Testing Strategy
     - Implementation Notes (deviations, issues)

2. **Build PR description:**
   ```markdown
   # [Feature Name]

   ## Summary

   [Summary from implementation plan or PRD goal]

   ## Implementation

   ### What was done

   [Task breakdown from implementation plan, organized by phase]

   **Phase 1: Foundation**
   - ✅ Task 1
   - ✅ Task 2

   **Phase 2: Core Logic**
   - ✅ Task 3
   - ✅ Task 4

   ### Technical Details

   [Architecture and key technical decisions from implementation plan]

   ## Testing

   [Testing strategy and results from implementation notes]

   - ✅ Unit tests: [count] passed
   - ✅ Integration tests: [status]
   - ✅ Manual testing: [status]
   - ✅ Linting: Passed

   ## Deviations

   [If any deviations were documented in implementation notes]

   ## Related

   - PRD: `.claude/prds/[prd-filename]`
   - Implementation Plan: `.claude/prds/impl-plans/[impl-plan-filename]`
   - Closes #[issue-number] (if GitHub issue exists)

   ## Acceptance Criteria

   [List all acceptance criteria from PRD with checkboxes]

   - ✅ [Criterion 1]
   - ✅ [Criterion 2]
   ```

3. **If no implementation plan:**
   - Use PRD as fallback
   - Build description from:
     - Goal
     - Approach
     - Acceptance Criteria
     - Implementation checklist

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
- Address review comments if any
- Merge when approved
- Run /prdx:sync [slug] to sync status back to GitHub issue
```

**Additional actions:**
1. Ask if they want to assign reviewers
2. Ask if they want to add labels
3. Remind about any project-specific PR checklist

---

## Example Usage

```bash
# Create PR for implemented feature
/prdx:dev:push android-feature-bug-fix

# Create PR by filename
/prdx:dev:push android-feature-bug-fix.md

# Create PR for backend feature
/prdx:dev:push backend-fix-context-storage-logger-tracing
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
