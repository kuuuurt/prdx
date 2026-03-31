---
description: "Clean up merged PRD plans and capture lessons learned"
argument-hint: ""
---

# /prdx:cleanup - Clean Up Merged PRD Plans

> Scans for completed workflows (merged/closed PRs), captures lessons learned, deletes PRD plan files and state files.
> Designed to run as a scheduled CI job but can also be run locally.

## Workflow

### Step 1: Resolve Plans Directory

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CONFIG_FILE=""
SEARCH_DIR="$PROJECT_ROOT"
while [ "$SEARCH_DIR" != "/" ]; do
  [ -f "$SEARCH_DIR/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/prdx.json" && break
  [ -f "$SEARCH_DIR/.prdx/prdx.json" ] && CONFIG_FILE="$SEARCH_DIR/.prdx/prdx.json" && break
  SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done
PLANS_SUBDIR=$(jq -r '.plansDirectory // ".prdx/plans"' "$CONFIG_FILE" 2>/dev/null || echo '.prdx/plans')
PLANS_DIR="$PROJECT_ROOT/$PLANS_SUBDIR"
```

### Step 2: Scan for Pushed-Phase State Files

```bash
if [ -d .prdx/state ]; then
  for f in .prdx/state/*.json; do
    [ -f "$f" ] || continue
    # process each file in steps 3-8 below
  done
fi
```

If no state files exist or directory is absent, display "No PRDs to clean up." and stop.

### Step 3: Filter to Pushed Phase

For each state file, read it and check if `phase` is `"pushed"`:
```bash
cat .prdx/state/{file}.json
```
If `phase` is not `"pushed"`, skip this file.

### Step 4: Check PR Status

```bash
gh pr view {pr_number} --json state --jq '.state' 2>/dev/null
```

- If `"MERGED"` → proceed with lesson capture (steps 5-7), then cleanup (step 8)
- If `"CLOSED"` → skip to cleanup (step 8) — no lessons for unmerged PRs
- Otherwise → skip this file (PR still open, leave for next run)

### Step 5: Gather Lesson Sources (Merged PRs Only)

Display:
```
Capturing lessons from merged PR #{pr_number} ({slug})...
```

a. Read the PRD file to extract title, platform, and `## Implementation Notes` section(s):
```bash
cat {PLANS_DIR}/prdx-{slug}.md
```
(For quick-mode slugs: `{PLANS_DIR}/prdx-{slug}.md` — the `quick-` prefix is part of the slug itself)

b. Fetch PR body:
```bash
gh pr view {pr_number} --json body --jq '.body' 2>/dev/null
```

c. Fetch PR review comments (inline code review comments):
```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
gh api "repos/$REPO/pulls/{pr_number}/comments" --jq '[.[] | "[\(.path):\(.line // .position)] \(.body)"] | join("\n---\n")' 2>/dev/null
```

d. Fetch PR-level review bodies:
```bash
gh pr view {pr_number} --json reviews --jq '[.reviews[] | .body | select(length > 0)] | join("\n---\n")' 2>/dev/null
```

### Step 6: Extract Learnings (Merged PRs Only)

```
subagent_type: "general-purpose"

prompt: "Extract ONLY repository-wide learnings from this completed PRD.

Platform: {PLATFORM}
Title: {TITLE}

Implementation Notes:
{IMPLEMENTATION_NOTES from PRD}

PR Description:
{PR_BODY}

PR Review Comments:
{PR_REVIEW_COMMENTS}

PR Review Bodies:
{PR_REVIEW_BODIES}

IMPORTANT: Only extract learnings that are broadly applicable to the ENTIRE repository — patterns, conventions, or insights that would help ANY future feature in this codebase. Do NOT include learnings that are specific to this particular PR, feature, or task. Skip observations that only matter for this one change.

Extract concise learnings (1-5 bullet points total, fewer is better). Prioritize DO NOT DO entries — anti-patterns, mistakes, and things to avoid are the most valuable learnings. Use these categories:

**Do NOT:** What mistakes, anti-patterns, or approaches should be avoided repo-wide? (highest priority — always check for these first)
**Patterns:** What reusable patterns or conventions were established that apply repo-wide?
**Challenges & Solutions:** What problems came up that could recur in unrelated features?

If no learnings are broadly applicable to the repository, respond with exactly: NO_LEARNINGS

Format your response as markdown bullet points, grouped by category. Only include categories that have learnings. Each bullet should be one line, starting with a dash.

Keep entries specific and actionable. Skip generic observations and anything specific to this PR's feature."
```

### Step 7: Append Learnings to CLAUDE.md (Merged PRs Only)

If the agent responded with `NO_LEARNINGS`, skip this step entirely and go to step 8.

Read the project's `CLAUDE.md` (in the repository root).

- If `CLAUDE.md` doesn't exist, create it with just the `## Lessons Learned` section
- If `CLAUDE.md` exists but has no `## Lessons Learned` section, append the section at the end of the file
- If the section already exists, append the new entry under it

Use Edit tool to append the entry:

```markdown
### {TITLE} ({DATE}) - {PLATFORM}
{EXTRACTED_LEARNINGS}
```

If the `## Lessons Learned` section exceeds ~200 lines, trim the oldest entries (remove earliest `###` subsections) to stay under the limit.

**Commit the CLAUDE.md update:**
```bash
git add CLAUDE.md
git commit -m "chore: update lessons learned from {SLUG}"
```

### Step 8: Clean Up PRD and State File

Delete the PRD plan file (both quick and normal mode — git history is the archive):
```bash
rm -f {PLANS_DIR}/prdx-{slug}.md
```

Delete the state file:
```bash
rm -f .prdx/state/{slug}.json
```

**Commit the cleanup:**
```bash
git add -A .prdx/
git add -A {PLANS_DIR}/
git commit -m "chore: clean up PRD for {SLUG}"
```

### Step 9: Display Confirmation

For merged PRs:
```
Cleaned up "{TITLE}" — lessons captured in CLAUDE.md
```

For closed PRs:
```
Cleaned up "{TITLE}" — PR was closed without merge, no lessons captured
```

### Step 10: Push Changes

**Process all pushed-phase state files sequentially** (one at a time, not in parallel).

After all files are processed, push if any commits were made:
```bash
git push
```

Display summary:
```
Cleanup complete: {N} PRD(s) processed ({M} merged with lessons, {K} closed)
```

If no PRDs were processed:
```
No merged or closed PRDs to clean up.
```
