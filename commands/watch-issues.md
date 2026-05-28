---
description: "One poll iteration of the issue watcher — pick the next open issue to queue for PRD generation"
---

## Pre-Computed Context

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
WATCH_DIR=".prdx/watch"
CURRENT_FILE="$WATCH_DIR/current.json"
mkdir -p "$WATCH_DIR"
HAS_CURRENT=$([ -f "$CURRENT_FILE" ] && echo "true" || echo "false")
```

# /prdx:watch-issues

One iteration of the issue watcher. Designed to run via `/loop 5m /prdx:watch-issues`.

This loop picks the next open issue that should enter the PRDX pipeline and writes it to `.prdx/watch/current.json`. The downstream loops (`/prdx:watch-prd`, `/prdx:watch-approvals`, `/prdx:watch-implement`) all read from that same file.

**Single source of truth:** an issue is "in flight" iff `current.json` exists. An issue is "done" (or never picked yet) iff the issue is open AND has no `<!-- prdx-prd -->` comment. There is no other state. This makes every loop idempotent — re-running them never double-processes anything.

**One issue at a time:** while `current.json` exists, this loop does nothing. The file is cleared by `/prdx:watch-implement` after a PR is opened.

---

## Step 1: Guard — one issue at a time

If `HAS_CURRENT` is `true`, read `current.json` and print:

```
[watch-issues] Issue #{number} already in pipeline (phase: {phase}). Skipping.
```

Stop here. Do NOT pick another issue.

---

## Step 2: Find the next candidate

Fetch open issues assigned to the current user, oldest first:

```bash
gh issue list --state open --assignee @me --limit 100 \
  --json number,title,createdAt \
  --jq 'sort_by(.createdAt)'
```

For each issue in order, check whether it already has a `<!-- prdx-prd -->` comment. Stop at the first one that does NOT:

```bash
gh api "repos/$REPO/issues/{number}/comments" --paginate \
  --jq '[.[] | select(.body | contains("<!-- prdx-prd -->"))] | length'
```

If the count is 0, this issue is the next candidate. Stop scanning.

If you reach the end with no candidate:

```
[watch-issues] No new issues. Nothing to queue.
```

Stop here.

---

## Step 3: Write current.json

For the chosen issue, write:

```bash
TITLE_JSON=$(jq -Rn --arg t "{TITLE}" '$t')
cat > "$CURRENT_FILE" << EOF
{
  "issue_number": {NUMBER},
  "issue_title": $TITLE_JSON,
  "phase": "queued",
  "queued_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

Print:

```
[watch-issues] Queued issue #{number}: {title}
```

---

## Notes

- State is just two things: `current.json` (in flight) and the issue's PRD comment (done). Nothing else. The loops are idempotent because re-deriving "what's next?" only needs these two facts.
- To skip an issue without implementing it: close the issue, or post a stub `<!-- prdx-prd -->` comment so it's treated as done.
- If `current.json` gets stuck (e.g., a downstream loop crashed and never recovered), delete it manually to unblock the pipeline. The next tick will re-pick whichever issue still has no PRD comment.
