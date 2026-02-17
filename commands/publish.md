---
description: "Publish PRD to GitHub issue for tracking"
argument-hint: "[slug] [--issue #123]"
---

# /prdx:publish - Publish PRD to GitHub

> Push local PRDs to GitHub for team visibility.
> Creates a new issue or links to an existing one.

---

## Step 0: Validate GitHub CLI

**Before any GitHub operations, verify `gh` is available and authenticated:**

1. Check if `gh` CLI is installed:
   ```bash
   command -v gh
   ```
   If not found, show error and stop:
   ```
   GitHub CLI (gh) not found.

   This command requires the GitHub CLI to publish PRDs as issues.

   Install:
     macOS: brew install gh
     Linux: See https://github.com/cli/cli#installation
     Windows: winget install GitHub.cli
   ```

2. Check authentication status:
   ```bash
   gh auth status
   ```
   If not authenticated, show error and stop:
   ```
   Not authenticated with GitHub.

   Please authenticate:
     gh auth login

   Then try again.
   ```

---

## Phase 1: Locate & Validate PRD

**Find the PRD:**

1. If slug provided, resolve using enhanced matching (exact → substring → word-boundary → disambiguation):
   ```bash
   # 1. Exact: ~/.claude/plans/prdx-{slug}.md
   # 2. Substring: ls ~/.claude/plans/prdx-*{slug}*.md
   # 3. Word-boundary: split slug into words, find PRDs containing all words
   # 4. Multiple matches → ask user to select
   ```
2. If not: list all PRDs and ask user to select
3. **DO NOT PROCEED** without valid PRD

4. Read PRD and verify:
   - Not already published (no issue # in metadata)
   - Platform is identified (backend/android/ios)
   - PRD has required sections (Problem, Goal, Acceptance Criteria)

5. If already published, inform user and exit

---

## Phase 2: Check for Existing Issue

**Parse the argument for issue number:**

- If `--issue #123` or `--issue 123` provided → Use existing issue (Phase 2a)
- If no issue specified → Ask user (Phase 2b)

### Phase 2a: Link to Existing Issue

If issue number provided:

1. Verify issue exists:
   ```bash
   gh issue view [number] --json number,title,state,url
   ```

2. If issue doesn't exist or is closed, warn and ask to proceed or create new

3. Skip to Phase 3b (add comment instead of creating issue)

### Phase 2b: Ask User

Use AskUserQuestion:
- Option 1: "Create new issue"
- Option 2: "Link to existing issue"

If "Link to existing":
- Ask for issue number
- Proceed to Phase 2a validation

If "Create new":
- Proceed to Phase 3a

---

## Phase 3a: Create New Issue

**Determine target repository:**

1. Verify repo access:
   ```bash
   gh repo view --json nameWithOwner
   ```

2. Create issue title from PRD title

3. Format issue body:
   ```markdown
   ## Problem
   [From PRD]

   ## Goal
   [From PRD]

   ## Acceptance Criteria
   [Checkboxes from PRD - GitHub makes interactive]

   ## Approach
   [High-level summary from PRD]

   ---
   *PRD managed by PRDX*
   ```

4. Check available labels:
   ```bash
   gh label list --json name
   ```
   Only use labels that exist (e.g., `enhancement`, `feature`, platform labels)

5. **Confirm with user:**
   ```
   Ready to create GitHub issue:

   Repo: [org/repo]
   Title: [title]
   Labels: [labels]

   Proceed? (y/n)
   ```

6. **Create issue:**
   ```bash
   gh issue create \
     --title "[title]" \
     --body "[body]" \
     --label "[labels]"
   ```

7. Capture issue number and URL from output

8. Proceed to Phase 4

---

## Phase 3b: Add Comment to Existing Issue

**Link PRD to existing issue:**

1. Format comment body:
   ```markdown
   ## PRD Linked

   A Product Requirements Document has been created for this issue.

   ### Goal
   [From PRD]

   ### Acceptance Criteria
   [Checkboxes from PRD]

   ### Approach
   [High-level summary from PRD]

   ---
   *PRD managed by PRDX*
   ```

2. **Confirm with user:**
   ```
   Ready to add PRD comment to issue #[number]:

   Issue: [title]
   URL: [url]

   Proceed? (y/n)
   ```

3. **Add comment:**
   ```bash
   gh issue comment [number] --body "[body]"
   ```

4. Proceed to Phase 4

---

## Phase 4: Update PRD Metadata

**Link PRD to issue:**

1. Update PRD metadata with Edit tool:
   - Add or update `**Issue:**` field with `#[number]`
   - Status stays unchanged (publishing is metadata, not a workflow state)

2. Save original filename for Phase 5

---

## Phase 5: Rename PRD File

**Simplify PRD filename to platform-issue format:**

1. Extract information:
   - Platform from PRD metadata: `backend`, `android`, or `ios`
   - Issue number from Phase 3a or 3b

2. Construct new filename:
   - Format: `prdx-[platform]-[issue-number].md`
   - Examples: `prdx-android-216.md`, `prdx-backend-1114.md`, `prdx-ios-431.md`

3. Rename file:
   ```bash
   mv ~/.claude/plans/[old-filename].md ~/.claude/plans/prdx-[platform]-[issue-number].md
   ```

4. Display success:
   ```
   ✓ PRD published to GitHub!

   Issue: #[number]
   URL: [full URL]
   Action: [Created new issue / Linked to existing issue]

   PRD renamed:
   - From: ~/.claude/plans/[old-filename].md
   - To:   ~/.claude/plans/prdx-[platform]-[issue-number].md

   Next steps:
   - View issue: gh issue view [number] --web
   - Implement: /prdx:implement [platform]-[issue-number]
   ```

---

## Usage Examples

```bash
# Create new issue from PRD
/prdx:publish biometric-login

# Link to existing issue
/prdx:publish biometric-login --issue 123
/prdx:publish biometric-login --issue #456
```

---

## Important Rules

- **NO DUPLICATES** - check if PRD already published
- **VERIFY EXISTING ISSUES** - confirm issue exists and is open
- **CONFIRM FIRST** - GitHub changes are visible to team
- **UPDATE PRD** - always link back to issue number
- **PRESERVE CHECKBOXES** - GitHub renders `- [ ]` interactively
