---
description: "Publish PRD to GitHub issue for tracking"
argument-hint: "[slug] [--issue #123]"
---

# /prdx:publish - Publish PRD to GitHub

> Push local PRDs to GitHub for team visibility.
> Creates a new issue or links to an existing one.

---

## Pre-Computed Context

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-plans-dir.sh"
```

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

1. If slug provided:
   ```bash
   source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-slug.sh" "$SLUG_INPUT"
   # → sets: RESOLVED_SLUG, PRD_FILE, RENAMED
   # → on ambiguity or not-found: writes to stderr and returns 1 — use AskUserQuestion to disambiguate
   ```
2. If not: list all PRDs and ask user to select
3. **DO NOT PROCEED** without valid PRD

4. Read PRD and verify:
   - Not already published (no issue # in metadata)
   - Platform is identified (backend/android/ios)
   - PRD has required sections (Problem, Goal, Acceptance Criteria)

5. If already published, inform user and exit

6. **Detect parent-child relationship:**
   - If PRD has `**Parent:** {parent-slug}` field → set `IS_CHILD=true`, `PARENT_SLUG={parent-slug}`.
   - Otherwise → `IS_CHILD=false`.

---

## Phase 1.5: Ensure Parent Issue Exists (Children Only)

**Skip this phase entirely if `IS_CHILD=false`.**

When publishing a child PRD for the first time, the parent issue must exist on GitHub so the child can reference it.

1. Locate parent PRD: `{PLANS_DIR}/prdx-{PARENT_SLUG}.md`. If missing, error out: `Parent PRD not found: prdx-{PARENT_SLUG}.md. Run /prdx:plan to create it first.`

2. Check parent PRD for `**Issue:** #{N}` field:
   - **If present:** capture `PARENT_ISSUE=N`. Skip to Phase 2.
   - **If absent:** create the parent issue now (continue below).

3. **Create parent issue** with a tracking-issue body:

   ```bash
   PARENT_TITLE=$(grep -m1 '^# ' "{PLANS_DIR}/prdx-{PARENT_SLUG}.md" | sed 's/^# //')
   PARENT_PROBLEM=$(awk '/^## Problem/{flag=1; next} /^## /{flag=0} flag' "{PLANS_DIR}/prdx-{PARENT_SLUG}.md")
   PARENT_GOAL=$(awk '/^## Goal/{flag=1; next} /^## /{flag=0} flag' "{PLANS_DIR}/prdx-{PARENT_SLUG}.md")
   ```

   Body format:

   ```markdown
   ## Problem
   {PARENT_PROBLEM}

   ## Goal
   {PARENT_GOAL}

   ## Children

   <!-- prdx-children-start -->
   <!-- prdx-children-end -->

   ---
   *Parent PRD managed by PRDX. Each child gets its own issue, branch, and PR. Children are listed above as they are published.*
   ```

   The empty markers between `<!-- prdx-children-start -->` and `<!-- prdx-children-end -->` are where Phase 4.5 will inject child checkboxes. Children appear as they're published.

4. Confirm with user before creating, then:

   ```bash
   PARENT_ISSUE_URL=$(gh issue create --title "$PARENT_TITLE" --body "$PARENT_BODY")
   PARENT_ISSUE=$(echo "$PARENT_ISSUE_URL" | grep -oE '[0-9]+$')
   ```

5. Update the parent PRD file with `**Issue:** #{PARENT_ISSUE}` (insert after the `**Status:**` field).

6. Display: `Created parent issue #{PARENT_ISSUE} for {PARENT_SLUG}.`

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

   **If `IS_CHILD=true`:** prepend a `Parent: #{PARENT_ISSUE}` line above `## Problem` so the child issue links back to the parent on GitHub.

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

7. Capture issue number and URL from output. Set `CHILD_ISSUE` to the captured number — Phase 4.5 reads this variable when `IS_CHILD=true`.

8. Proceed to Phase 4

---

## Phase 3b: Add Comment to Existing Issue

**Link PRD to existing issue by posting the full PRD with marker:**

1. Read the full PRD content from the local file:
   ```bash
   PRD_BODY=$(cat "$PRD_FILE")
   ```

2. **Confirm with user:**
   ```
   Ready to add or update PRD comment on issue #[number]:

   Issue: [title]
   URL: [url]

   Proceed? (y/n)
   ```

3. **Upsert comment** (PATCHes existing `<!-- prdx-prd -->` comment in place; POSTs new one if none exists):
   ```bash
   source "$(git rev-parse --show-toplevel)/hooks/prdx/upsert-prd-comment.sh"
   upsert_prd_comment "[number]" "$PRD_BODY"
   # PRD_COMMENT_ID and PRD_COMMENT_URL are now exported
   ```

4. Set `CHILD_ISSUE=[number]` (the issue number provided in Phase 2a) so Phase 4.5 can reference it when `IS_CHILD=true`.

5. Proceed to Phase 4

---

## Phase 4: Update PRD Metadata

**Link PRD to issue:**

1. Update PRD metadata with Edit tool:
   - Add or update `**Issue:**` field with `#[number]`
   - Status stays unchanged (publishing is metadata, not a workflow state)

2. Save original filename for Phase 5

---

## Phase 4.5: Append Child Entry to Parent Issue (Children Only)

**Skip this phase if `IS_CHILD=false`.**

After the child issue is created/linked, append it to the parent issue's `## Children` checklist so the parent has a live view of progress.

1. Fetch parent issue body:

   ```bash
   PARENT_BODY=$(gh issue view "$PARENT_ISSUE" --json body --jq '.body')
   ```

2. Build the new child line — `PLATFORM` comes from the child PRD's `**Platform:**` field, `CHILD_ISSUE` is the issue number from Phase 3:

   ```
   - [ ] #{CHILD_ISSUE} — {PLATFORM}
   ```

3. Inject the line between the markers `<!-- prdx-children-start -->` and `<!-- prdx-children-end -->`.

   **If a line for the same child issue is already present**, leave the body unchanged (idempotent — handles re-publishes).

   **If the markers are missing from `PARENT_BODY`** (parent issue was edited by hand), append a fresh `## Children` block with both markers and the new child line at the end of the body. Do NOT fail — the markers should self-heal:

   ```markdown

   ## Children

   <!-- prdx-children-start -->
   - [ ] #{CHILD_ISSUE} — {PLATFORM}
   <!-- prdx-children-end -->
   ```

4. Update the parent issue:

   ```bash
   gh issue edit "$PARENT_ISSUE" --body "$NEW_PARENT_BODY"
   ```

5. Display: `Linked child #{CHILD_ISSUE} to parent #{PARENT_ISSUE}.`

**Note:** GitHub does not auto-tick `- [ ]` checkboxes when the linked issue closes. Users (or a future post-merge hook) can tick manually.

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
   mv {PLANS_DIR}/[old-filename].md {PLANS_DIR}/prdx-[platform]-[issue-number].md
   ```

4. Display success:
   ```
   ✓ PRD published to GitHub!

   Issue: #[number]
   URL: [full URL]
   Action: [Created new issue / Linked to existing issue]

   PRD renamed:
   - From: {PLANS_DIR}/[old-filename].md
   - To:   {PLANS_DIR}/prdx-[platform]-[issue-number].md

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
