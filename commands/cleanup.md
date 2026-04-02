---
description: "Clean up merged PRD plans and capture lessons learned"
argument-hint: ""
---

# /prdx:cleanup - Clean Up Merged PRD Plans

> Scans pushed-phase state files, captures lessons from merged PRs into CLAUDE.md, deletes PRD + state files. Runs as scheduled CI job or locally.

## Workflow

### Resolve Plans Directory

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-plans-dir.sh"
```

### Scan & Filter

```bash
ls .prdx/state/*.json 2>/dev/null
```

If none exist, display `No PRDs to clean up.` and stop.

For each state file where `phase == "pushed"`:

1. Check PR status: `gh pr view {pr_number} --json state --jq '.state'`
   - `MERGED` → capture lessons (below), then clean up
   - `CLOSED` → skip to clean up (no lessons for unmerged PRs)
   - Other → skip file (PR still open)

### Capture Lessons (Merged PRs Only)

Display: `Capturing lessons from merged PR #{pr_number} ({slug})...`

**Gather sources:**
- PRD file: `{PLANS_DIR}/prdx-{slug}.md` (extract title, platform, `## Implementation Notes`)
- PR body: `gh pr view {pr_number} --json body --jq '.body'`
- Inline review comments: `gh api "repos/{OWNER}/{REPO}/pulls/{pr_number}/comments" --jq '[.[] | "[\(.path):\(.line // .position)] \(.body)"] | join("\n---\n")'`
- PR review bodies: `gh pr view {pr_number} --json reviews --jq '[.reviews[] | .body | select(length > 0)] | join("\n---\n")'`

**Extract via agent:**

```
subagent_type: "general-purpose"

prompt: "Extract repo-wide learnings from this completed PRD. Only include insights applicable to ANY future feature — skip PR-specific observations.

Platform: {PLATFORM} | Title: {TITLE}

Implementation Notes: {NOTES}
PR Description: {PR_BODY}
Review Comments: {COMMENTS}

Return 1-5 flat bullet points (fewer is better). Prioritize anti-patterns and 'don't do X' entries. No category headers. If nothing is broadly applicable, respond: NO_LEARNINGS"
```

**Append to CLAUDE.md** (skip if `NO_LEARNINGS`):

- If no `## Lessons Learned` section exists, append one
- Add entry under it:
  ```markdown
  ### {TITLE} ({DATE}) - {PLATFORM}
  - {bullet}
  - {bullet}
  ```
- If section exceeds ~200 lines, trim oldest `###` subsections

**Commit:** `git add CLAUDE.md && git commit -m "chore: update lessons learned from {SLUG}"`

### Clean Up

Delete PRD and state file:
```bash
rm -f "{PLANS_DIR}/prdx-{slug}.md" ".prdx/state/{slug}.json"
git add -A .prdx/ "{PLANS_DIR}/" && git commit -m "chore: clean up PRD for {SLUG}"
```

Display per PR:
- Merged: `Cleaned up "{TITLE}" — lessons captured in CLAUDE.md`
- Closed: `Cleaned up "{TITLE}" — PR closed without merge, no lessons captured`

### Push

After all files processed, push if any commits were made: `git push`

Display: `Cleanup complete: {N} PRD(s) processed ({M} merged with lessons, {K} closed)`
