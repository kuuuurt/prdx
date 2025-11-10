| description | argument-hint |
| Publish PRD to GitHub issue for tracking | PRD filename or feature slug |

# Feature Publish

> **Be simple. Be pragmatic. One phase = one committable work.**
> Push local PRDs to GitHub for team visibility.

---

## Phase 1: Locate & Validate PRD

**Find the PRD:**

1. If slug provided: `ls .claude/prds/*[slug]*.md`
2. If not: list all PRDs and ask user to select
3. **DO NOT PROCEED** without valid PRD

4. Read PRD and verify:
   - Not already published (no issue # in metadata)
   - Project is identified (backend/android/ios)
   - PRD is reasonably complete

5. If incomplete, warn and suggest `/prdx:review` first

---

## Phase 2: Detect Repo & Prepare Issue

**Determine target repository:**

1. Extract project from PRD metadata/filename:
   - `backend` → `your-backend-project`
   - `android` → `your-android-project`
   - `ios` → `your-ios-project`

2. Verify repo access:
   ```bash
   cd your-[project] && gh repo view
   ```

3. Create issue title: `[Brief description from PRD]`

4. Format issue body:
   ```markdown
   ## Problem
   [From PRD]

   ## Goal
   [From PRD]

   ## Acceptance Criteria
   [Checkboxes from PRD - GitHub makes interactive]

   ## Approach
   [High-level summary from PRD]

   <details>
   <summary>Implementation Plan</summary>

   [Full checklist from PRD]

   </details>
   ```

---

## Phase 3: Determine Labels & Create Issue

**Apply labels:**

1. Default labels:
   - `feature` (or `enhancement`)
   - Project label: `backend`, `android`, `ios`

2. Check available labels:
   ```bash
   cd your-[project] && gh label list
   ```
   Only use labels that exist

3. **Confirm with user:**
   ```
   Ready to create GitHub issue:

   Repo: [org/repo]
   Title: [title]
   Labels: [labels]

   Proceed? (y/n)
   ```

4. **Create issue:**
   ```bash
   cd your-[project] && gh issue create \
     --title "[title]" \
     --body "[body]" \
     --label "[labels]"
   ```

5. Capture issue number from output

---

## Phase 4: Update PRD Metadata

**Link PRD to issue:**

1. Update PRD metadata with Edit tool:
   ```markdown
   **Project**: [project] | **Status**: published | **Issue**: #[number] | **Created**: [date]
   ```

2. Save original filename for Phase 5

---

## Phase 5: Rename PRD File

**Simplify PRD filename to platform-issue format:**

1. Extract information:
   - Platform from PRD metadata: `backend`, `android`, or `ios`
   - Issue number from GitHub CLI output (captured in Phase 3)

2. Construct new filename:
   - Format: `[platform]-[issue-number].md`
   - Examples:
     - `android-216.md`
     - `backend-1114.md`
     - `ios-431.md`

3. Rename file:
   ```bash
   mv .claude/prds/[old-filename].md .claude/prds/[platform]-[issue-number].md
   ```

4. Display success:
   ```
   ✓ GitHub issue created!

   Repo: [org/repo]
   Issue: #[number]
   URL: [full URL]

   PRD renamed:
   - From: .claude/prds/[old-filename].md
   - To:   .claude/prds/[platform]-[issue-number].md

   Next steps:
   - View issue: gh issue view [number] --web
   - Implement: /prdx:implement [platform]-[issue-number]
   - Update if needed: /prdx:update [platform]-[issue-number]
   ```

5. Optional: ask to open in browser
   ```bash
   cd your-[project] && gh issue view [number] --web
   ```

**Why rename?**
- Shorter, cleaner filenames
- Easy to reference by issue number
- Consistent naming across all published PRDs
- GitHub issue becomes the canonical identifier

---

## Important Rules

- **NO DUPLICATES** - check if already published
- **CONFIRM FIRST** - GitHub issues are permanent
- **UPDATE PRD** - always link back to issue
- **USE EXPANDABLE SECTIONS** - keep issue readable with `<details>`
- **PRESERVE CHECKBOXES** - GitHub renders `- [ ]` interactively
