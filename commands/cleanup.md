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

prompt: "Extract two categories of learnings from this completed PRD:

1. **Lessons** — broad insights applicable to ANY future feature (philosophy, anti-patterns, process improvements). Goes to CLAUDE.md.
2. **Conventions** — project-specific tactical patterns (this repo uses X for Y, prefer Z over W in this module, file paths, naming rules). Goes to .prdx/conventions.md.

Platform: {PLATFORM} | Title: {TITLE}

Implementation Notes: {NOTES}
PR Description: {PR_BODY}
Review Comments: {COMMENTS}

Return JSON:
{
  \"lessons\": [\"bullet\", ...],          // 0-3 entries, broad/philosophical only
  \"conventions\": [\"bullet\", ...]       // 0-5 entries, codebase-specific patterns
}

If neither category yields anything, return: {\"lessons\": [], \"conventions\": []}. Prefer fewer, higher-signal entries. Conventions should reference concrete paths/names from this repo when relevant."
```

**Append lessons to CLAUDE.md** (skip if `lessons` is empty):

- If no `## Lessons Learned` section exists, append one
- Add entry under it:
  ```markdown
  ### {TITLE} ({DATE}) - {PLATFORM}
  - {bullet}
  - {bullet}
  ```
- If section exceeds ~200 lines, trim oldest `###` subsections

**Append conventions to `.prdx/conventions.md`** (skip if `conventions` is empty):

- **First-time setup:** if `.prdx/conventions.md` does not exist, create it AND add a gitignore exception so the file is tracked despite `.prdx/` being globally ignored:
  ```bash
  if [ ! -f .prdx/conventions.md ]; then
    grep -qxF '!.prdx/conventions.md' .gitignore 2>/dev/null || echo '!.prdx/conventions.md' >> .gitignore
    cat > .prdx/conventions.md <<'HEADER'
  # Project Conventions

  Auto-maintained by `/prdx:cleanup`. Read by `prdx:dev-planner` and developer agents at the start of work.

  Each entry: `- {pattern} (PR #{N}, {DATE})`. Capped at ~100 entries — oldest are pruned first.

  ---
  HEADER
  fi
  ```
  Conventions are committed by default so the whole team benefits. Users can opt out by removing the gitignore exception.
- Append each convention as: `- {bullet} (PR #{pr_number}, {DATE})`
- If the file exceeds ~100 bulleted entries, remove the oldest entries first (keep the header).

**Commit:** stage and commit only the files that actually changed:
```bash
git add CLAUDE.md .gitignore .prdx/conventions.md 2>/dev/null
git commit -m "chore: capture lessons and conventions from {SLUG}"
```

### Clean Up

Delete PRD, state file, and sharded state directory:
```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh"
rm -f "{PLANS_DIR}/prdx-{slug}.md" ".prdx/state/{slug}.json"
shard_cleanup "{slug}"   # rm -rf .prdx/state/{slug}/
git add -A .prdx/ "{PLANS_DIR}/" && git commit -m "chore: clean up PRD for {SLUG}"
```

Display per PR:
- Merged: `Cleaned up "{TITLE}" — captured {N} lesson(s), {M} convention(s)` (omit categories with zero entries; if both zero, say `no learnings extracted`)
- Closed: `Cleaned up "{TITLE}" — PR closed without merge, no learnings captured`

### Push

After all files processed, push if any commits were made: `git push`

Display: `Cleanup complete: {N} PRD(s) processed ({M} merged with lessons, {K} closed)`
