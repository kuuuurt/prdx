---
description: "One poll iteration of the approval watcher — check for 👍 on the PRD comment"
---

## Pre-Computed Context

```bash
WATCH_DIR=".prdx/watch"
CURRENT_FILE="$WATCH_DIR/current.json"
HAS_CURRENT=$([ -f "$CURRENT_FILE" ] && echo "true" || echo "false")
if [ "$HAS_CURRENT" = "true" ]; then
  ISSUE_NUMBER=$(jq -r '.issue_number' "$CURRENT_FILE")
  PHASE=$(jq -r '.phase' "$CURRENT_FILE")
  PRD_COMMENT_ID=$(jq -r '.prd_comment_id // empty' "$CURRENT_FILE")
fi
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
ME=$(gh api user --jq '.login' 2>/dev/null)
```

# /prdx:watch-approvals

One iteration of the approval watcher. Designed to run via `/loop 2m /prdx:watch-approvals`.

Polls 👍 (`+1`) reactions on the PRD comment captured by `/prdx:watch-prd`. When the repo owner (or the configured approver — defaults to the authenticated `gh` user) thumbs-ups the PRD comment, the phase flips to `approved` so `/prdx:watch-implement` picks it up.

---

## Step 1: Guard — is there work?

If `HAS_CURRENT` is `false`:

```
[watch-approvals] No issue in pipeline. Nothing to do.
```

Stop here.

If `PHASE` is not `awaiting-approval`:

```
[watch-approvals] Issue #{ISSUE_NUMBER} is in phase '{PHASE}' — not my turn. Skipping.
```

Stop here.

If `PRD_COMMENT_ID` is empty (shouldn't happen if `/prdx:watch-prd` finished cleanly):

```
[watch-approvals] No PRD comment ID recorded for #{ISSUE_NUMBER}. Cannot check approval.
```

Stop here. The user can either manually edit `current.json` to add `prd_comment_id`, or reset `phase` to `queued` to retry the PRD generation.

---

## Step 2: Check for 👍 reactions on the PRD comment

```bash
APPROVERS=$(gh api "repos/$REPO/issues/comments/$PRD_COMMENT_ID/reactions" --paginate \
  --jq '[.[] | select(.content == "+1") | .user.login]')
```

If `APPROVERS` is empty `[]`:

```
[watch-approvals] No 👍 yet on PRD comment {PRD_COMMENT_ID}. Waiting.
```

Stop here.

---

## Step 3: Confirm the approver is authorized

The approver must be `ME` (the authenticated gh user). Reactions from bots or other users do not count:

```bash
echo "$APPROVERS" | jq -e --arg me "$ME" 'any(. == $me)' > /dev/null
```

If the check fails (no match):

```
[watch-approvals] PRD comment has 👍 from {APPROVERS}, but not from {ME}. Waiting for your approval.
```

Stop here.

---

## Step 4: Advance phase to approved

```bash
jq --arg phase "approved" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.phase = $phase | .approved_at = $ts' \
   "$CURRENT_FILE" > "$CURRENT_FILE.tmp" && mv "$CURRENT_FILE.tmp" "$CURRENT_FILE"
```

Print:

```
[watch-approvals] Approval detected from {ME} on issue #{ISSUE_NUMBER}. Handing off to implement.
```

---

## Notes

- The approver is whoever ran `gh auth login` in the terminal where this loop runs. If you want a different approver, run this loop under a different gh account, or extend `current.json` with an `approvers` array and check membership instead.
- This loop never revises a PRD. If you want changes, post a comment on the issue describing the revision, then either re-run `/prdx:auto --issue N --plan-only` manually or reset `phase` to `queued` so `/prdx:watch-prd` re-generates it.
- 👎 reactions are ignored. To skip an issue, manually delete `.prdx/watch/current.json` and append the issue number to `.prdx/watch/seen.txt`.
