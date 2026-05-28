---
description: "One poll iteration of the implementer — implement the approved PRD and open a PR"
---

## Pre-Computed Context

```bash
MAIN_REPO_DIR=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$MAIN_REPO_DIR")
WATCH_DIR="$MAIN_REPO_DIR/.prdx/watch"
CURRENT_FILE="$WATCH_DIR/current.json"
HISTORY_FILE="$WATCH_DIR/history.jsonl"
HAS_CURRENT=$([ -f "$CURRENT_FILE" ] && echo "true" || echo "false")
if [ "$HAS_CURRENT" = "true" ]; then
  ISSUE_NUMBER=$(jq -r '.issue_number' "$CURRENT_FILE")
  PHASE=$(jq -r '.phase' "$CURRENT_FILE")
  WORKTREE_PATH=$(jq -r '.worktree_path // empty' "$CURRENT_FILE")
fi
```

# /prdx:watch-implement

One iteration of the implementer loop. Designed to run via `/loop 2m /prdx:watch-implement`.

Reads `.prdx/watch/current.json` and, if its phase is `approved`, runs `/prdx:auto --issue N` to implement the PRD and open a PR. **All work happens in an isolated git worktree** so your main checkout stays on its current branch — you can keep working in this repo while implementation runs. On success, archives `current.json` to `history.jsonl`, removes the worktree, and clears the state file so the pipeline picks up the next issue.

---

## Step 1: Guard — is there work?

If `HAS_CURRENT` is `false`:

```
[watch-implement] No issue in pipeline. Nothing to do.
```

Stop here.

If `PHASE` is not `approved`:

```
[watch-implement] Issue #{ISSUE_NUMBER} is in phase '{PHASE}' — not my turn. Skipping.
```

Stop here.

---

## Step 2: Create a worktree and mark phase as implementing

The implementation runs in a sibling directory (a git worktree) so the main checkout is untouched. Worktrees live at `<repo-parent>/<repo>-prdx-<issue>`.

```bash
WORKTREE_PATH="${MAIN_REPO_DIR%/*}/${REPO_NAME}-prdx-${ISSUE_NUMBER}"

# If a worktree from a previous failed tick still exists, reuse it.
if [ ! -d "$WORKTREE_PATH" ]; then
  git -C "$MAIN_REPO_DIR" worktree add --detach "$WORKTREE_PATH" >/dev/null
fi
```

Update the state file to record the worktree path and flip the phase. If anything below fails, the next tick will see `implementing` and the recorded worktree, and can resume:

```bash
jq --arg phase "implementing" \
   --arg wt "$WORKTREE_PATH" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.phase = $phase | .worktree_path = $wt | .implement_started_at = $ts' \
   "$CURRENT_FILE" > "$CURRENT_FILE.tmp" && mv "$CURRENT_FILE.tmp" "$CURRENT_FILE"
```

> If this Claude Code session is killed mid-implementation, the state file stays at `implementing` with the worktree path recorded. To retry: flip the phase back to `approved` (the worktree will be reused). To skip: delete `current.json` and `git worktree remove <path>` manually.

---

## Step 3: Run the implementation inside the worktree

Spawn a fresh interactive Claude *inside the worktree* to run `/prdx:auto --issue N` (which does the full flow: read PRD, create branch, implement, push, open PR). Running in a separate process keeps this watcher session's context clean and ensures the working directory is the worktree, not the main checkout:

```bash
cd "$WORKTREE_PATH" && claude --model opus --effort medium "/prdx:auto --issue ${ISSUE_NUMBER}"
```

**Important:** wait for it to complete. Do NOT proceed if it errors.

> The spawned `claude` session will prompt for tool permissions inside its own pane just like any interactive session. If you want unattended runs, you can add `--dangerously-skip-permissions` to the spawned command — but only do so deliberately, since it disables all approval gates for that session.

---

## Step 4: Verify a PR was opened

Use the issue's linked PR references — this is the same field GitHub displays as "linked PRs" and is set automatically when a PR body contains `Closes #N`:

```bash
PR_NUMBER=$(gh issue view "$ISSUE_NUMBER" \
  --json closedByPullRequestsReferences \
  --jq '[.closedByPullRequestsReferences[] | select(.state != "CLOSED") | .number] | first // empty')
```

If `PR_NUMBER` is empty:

```
[watch-implement] /prdx:auto finished but no PR found linked to #{ISSUE_NUMBER}. Will retry next tick.
```

Reset phase back to `approved` so the next tick retries:

```bash
jq --arg phase "approved" \
   '.phase = $phase | del(.implement_started_at)' \
   "$CURRENT_FILE" > "$CURRENT_FILE.tmp" && mv "$CURRENT_FILE.tmp" "$CURRENT_FILE"
```

Stop here.

---

## Step 5: Archive, clear current.json, remove worktree

Append the completed record to `history.jsonl`, remove `current.json`, and tear down the worktree so the main checkout is the only remaining copy:

```bash
jq --arg phase "done" \
   --argjson pr "$PR_NUMBER" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.phase = $phase | .pr_number = $pr | .completed_at = $ts' \
   "$CURRENT_FILE" >> "$HISTORY_FILE"
rm "$CURRENT_FILE"

# Remove the worktree. --force handles any leftover untracked files (e.g. build artifacts).
git -C "$MAIN_REPO_DIR" worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
```

Print:

```
[watch-implement] Issue #{ISSUE_NUMBER} → PR #{PR_NUMBER}. Worktree removed, pipeline cleared for next issue.
```

---

## Notes

- This loop never reviews or merges PRs — that's still on you. The pipeline ends when a PR is opened.
- If the PR needs revisions, `cd` into the worktree (or re-checkout the branch in any directory) and run `/prdx:auto --issue N` again — it has a fix-iteration path.
- If implementation gets stuck at `implementing`, manually flip the phase back to `approved` (the worktree is reused) or delete `current.json` + `git worktree remove <path>` to skip.
- The worktree lives at `<repo-parent>/<repo>-prdx-<issue>` and is removed after a successful PR. To inspect work in progress, `cd` there at any time — your main checkout is unaffected.
- Like the other watchers, this runs as an interactive Claude Code session — implementation draws from your subscription, not the Agent SDK credit pool.
