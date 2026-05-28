---
description: "One poll iteration of the implementer — implement the approved PRD and open a PR"
---

## Pre-Computed Context

```bash
WATCH_DIR=".prdx/watch"
CURRENT_FILE="$WATCH_DIR/current.json"
HISTORY_FILE="$WATCH_DIR/history.jsonl"
HAS_CURRENT=$([ -f "$CURRENT_FILE" ] && echo "true" || echo "false")
if [ "$HAS_CURRENT" = "true" ]; then
  ISSUE_NUMBER=$(jq -r '.issue_number' "$CURRENT_FILE")
  PHASE=$(jq -r '.phase' "$CURRENT_FILE")
fi
```

# /prdx:watch-implement

One iteration of the implementer loop. Designed to run via `/loop 2m /prdx:watch-implement`.

Reads `.prdx/watch/current.json` and, if its phase is `approved`, runs `/prdx:auto --issue N` to implement the PRD and open a PR. On success, archives `current.json` to `history.jsonl` and clears it so the pipeline picks up the next issue.

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

## Step 2: Mark phase as implementing

Before starting (the implement step takes a while), advance the phase so other watcher ticks see it's in flight:

```bash
jq --arg phase "implementing" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.phase = $phase | .implement_started_at = $ts' \
   "$CURRENT_FILE" > "$CURRENT_FILE.tmp" && mv "$CURRENT_FILE.tmp" "$CURRENT_FILE"
```

> Note: if this Claude Code session is killed mid-implementation, the file will be stuck at `implementing`. The user can manually flip it back to `approved` to retry, or delete the file to skip.

---

## Step 3: Run the implementation

`/prdx:auto --issue N` (without `--plan-only`) does the full flow: read the PRD comment, create a branch, run `/prdx:implement`, push, and open a PR via `prdx:pr-author`:

```
/prdx:auto --issue {ISSUE_NUMBER}
```

**Important:** wait for it to complete. Do NOT proceed if it errors.

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

## Step 5: Archive and clear current.json

Append the completed record to `history.jsonl` and remove `current.json` so `/prdx:watch-issues` is free to pick the next one:

```bash
jq --arg phase "done" \
   --argjson pr "$PR_NUMBER" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.phase = $phase | .pr_number = $pr | .completed_at = $ts' \
   "$CURRENT_FILE" >> "$HISTORY_FILE"
rm "$CURRENT_FILE"
```

Print:

```
[watch-implement] Issue #{ISSUE_NUMBER} → PR #{PR_NUMBER}. Pipeline cleared for next issue.
```

---

## Notes

- This loop never reviews or merges PRs — that's still on you. The pipeline ends when a PR is opened.
- If the PR needs revisions, you handle them manually (or via `/prdx:auto --issue N` again, which has a fix-iteration path).
- If implementation gets stuck at `implementing`, manually flip the phase back to `approved` (or delete `current.json` to skip the issue).
- Like the other watchers, this runs as an interactive Claude Code session — implementation draws from your subscription, not the Agent SDK credit pool.
