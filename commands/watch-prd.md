---
description: "One poll iteration of the PRD generator — generate and post a PRD for the queued issue"
---

## Pre-Computed Context

```bash
WATCH_DIR=".prdx/watch"
CURRENT_FILE="$WATCH_DIR/current.json"
HAS_CURRENT=$([ -f "$CURRENT_FILE" ] && echo "true" || echo "false")
if [ "$HAS_CURRENT" = "true" ]; then
  ISSUE_NUMBER=$(jq -r '.issue_number' "$CURRENT_FILE")
  ISSUE_TITLE=$(jq -r '.issue_title' "$CURRENT_FILE")
  PHASE=$(jq -r '.phase' "$CURRENT_FILE")
fi
```

# /prdx:watch-prd

One iteration of the PRD generator loop. Designed to run via `/loop 2m /prdx:watch-prd`.

Reads `.prdx/watch/current.json` and, if its phase is `queued`, generates a PRD for the issue by delegating to `/prdx:auto --issue N --plan-only`. On success, advances the phase to `awaiting-approval` so the next loop (`/prdx:watch-approvals`) takes over.

---

## Step 1: Guard — is there work?

If `HAS_CURRENT` is `false`:

```
[watch-prd] No issue queued. Nothing to do.
```

Stop here.

If `PHASE` is not `queued`:

```
[watch-prd] Issue #{ISSUE_NUMBER} is in phase '{PHASE}' — not my turn. Skipping.
```

Stop here. (This loop only acts on `queued`.)

---

## Step 2: Generate the PRD

Run the existing auto command in plan-only mode. This handles codebase exploration, PRD generation, and posting the `<!-- prdx-prd -->` comment on the issue:

```
/prdx:auto --issue {ISSUE_NUMBER} --plan-only
```

**Important:** wait for `/prdx:auto` to finish before continuing. Do NOT proceed if it errored.

After it returns, verify the PRD comment actually exists on the issue:

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
PRD_COUNT=$(gh api "repos/$REPO/issues/$ISSUE_NUMBER/comments" --paginate \
  --jq '[.[] | select(.body | contains("<!-- prdx-prd -->"))] | length')
```

If `PRD_COUNT` is 0, something went wrong. Print and stop without advancing the phase:

```
[watch-prd] /prdx:auto finished but no PRD comment found on issue #{ISSUE_NUMBER}. Will retry next tick.
```

The next loop tick will try again from `queued`. If it keeps failing, the user can inspect manually.

---

## Step 3: Capture the PRD comment ID

The approval watcher needs to know which comment to check 👍 reactions on. Capture the PRD comment ID:

```bash
PRD_COMMENT_ID=$(gh api "repos/$REPO/issues/$ISSUE_NUMBER/comments" --paginate \
  --jq '[.[] | select(.body | contains("<!-- prdx-prd -->"))] | last | .id')
```

---

## Step 4: Advance phase to awaiting-approval

Update `current.json` to record the PRD comment ID and flip the phase. Use `jq` to avoid races with manual edits:

```bash
jq --arg phase "awaiting-approval" \
   --argjson comment_id "$PRD_COMMENT_ID" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.phase = $phase | .prd_comment_id = $comment_id | .prd_posted_at = $ts' \
   "$CURRENT_FILE" > "$CURRENT_FILE.tmp" && mv "$CURRENT_FILE.tmp" "$CURRENT_FILE"
```

Print:

```
[watch-prd] PRD posted on issue #{ISSUE_NUMBER}. Awaiting 👍 on comment {PRD_COMMENT_ID}.
```

---

## Notes

- This loop is idempotent at the `queued` phase: if `/prdx:auto` fails mid-run, the phase stays `queued` and the next tick retries. `/prdx:auto` itself upserts the PRD comment, so retries won't duplicate it.
- If the user wants to force a PRD revision later, they comment feedback on the issue and manually re-run `/prdx:auto --issue N --plan-only` — this loop won't do that automatically (the issue is already past the `queued` phase).
- This loop is interactive. It runs inside a Claude Code session, so PRD generation draws from your subscription rather than the Agent SDK credit pool.
