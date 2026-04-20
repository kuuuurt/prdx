# PRDX Workflow Skill

Canonical specification for two recurring logic blocks in the PRDX entry-point commands: the entry-point routing table (Step 1) and the reviewing loop (Step 3b). Both `commands/prdx.md` and `commands/prdx-agent.md` reference this skill.

## Entry Point Routing

### Active State File Check

Before argument parsing, scan for active workflow state:

```bash
ls .prdx/state/*.json 2>/dev/null
```

If state files exist and **no argument was provided**, auto-resume if exactly one active (non-pushed, non-completed) state file exists; otherwise list and let user pick.

If exactly one active state file exists, route by `phase`:

| phase | action |
|-------|--------|
| `"planning"` | Fall through to normal Step 1 logic below |
| `"post-planning"` | Show post-planning decision via AskUserQuestion (see options below) |
| `"implementing"` | Jump to implementation phase, using slug from state file |
| `"post-implement"` | Jump to review decision, using slug from state file |
| `"reviewing"` | Jump to Reviewing Loop (see below), using slug + pr_number |
| `"pushing"` | Check if PR was actually created: `gh pr list --head {BRANCH} --json number --jq '.[0].number'`. If PR exists → transition to `"pushed"` + inform user. If no PR → transition to `"post-implement"` + offer to retry with `/prdx:push {slug}` |
| `"pushed"` | Inform user PR isn't merged yet. Ignore this state file and continue with normal Step 1 logic. |
| `"completed"` | Delete stale state file and continue with normal Step 1 logic |

**Post-planning decision point** (AskUserQuestion):
- **Normal mode**: Option 1: "Publish to GitHub" → Publish phase | Option 2: "Implement now" → Implementation phase | Option 3: "Stop here"
- **Quick mode**: Option 1: "Implement now" (Recommended) | Option 2: "Stop here"

If no active state file qualifies (or no state files exist), continue with normal logic below.

### Quick Flag Parsing

Strip `--quick` from arguments if present (can appear anywhere in the argument string).

If `--quick` is present:
- Remaining text MUST be a description (not a slug) — error if empty
- Error: `--quick requires a description. Usage: /prdx:prdx --quick "fix login validation"`
- Set `QUICK_MODE=true`, skip PRD matching, go directly to planning phase

If `--quick` is NOT present, continue with normal entry point logic below.

### CI and Issue Flag Parsing

**If `--ci` present:** Route to `/prdx:ci` with all arguments and stop.

**If `--issue N` or `--pr N` present (without `--ci`):** Resume a CI-created PRD locally.

```bash
# Set ISSUE_NUMBER or PR_NUMBER from the flag, then:
source "$(git rev-parse --show-toplevel)/hooks/prdx/resume-from-issue.sh"
# → sets: RESUME_SLUG, RESUME_PR_NUMBER, RESUME_PHASE
```

Route by `RESUME_PHASE`:

| `RESUME_PHASE` | action |
|----------------|--------|
| `"reviewing"` | Jump to Step 3b (Reviewing Loop) using `RESUME_SLUG` + `RESUME_PR_NUMBER` |
| `"post-implement"` | Jump to Step 3a (Review Status Decision) using `RESUME_SLUG` |

On hook error (`return 1`): show the error message, stop workflow.

**If `--issue {number}` present (without `--ci` and without resume intent — legacy behaviour):** Set `HAS_ISSUE=true`, `ISSUE_NUMBER`. Fetch: `gh issue view {ISSUE_NUMBER} --json title,body,labels`. Store `ISSUE_TITLE` + `ISSUE_BODY` as feature description. Continue with normal entry point logic.

> `--issue N` triggers resume when a `<!-- prdx-prd -->` comment exists on that issue; otherwise it falls through to legacy issue-as-description behaviour. The hook handles this distinction internally — it errors only when it finds no PRD comment.

### Auto-Detect from Current Branch

Runs BEFORE falling through to the "no active state / new feature" path, when all of the following are true: no state files exist in `.prdx/state/`, the current branch is not the default branch (`$DEFAULT_BRANCH`).

```bash
CURRENT_BRANCH=$(git branch --show-current)
PR_INFO=$(gh pr list --head "$CURRENT_BRANCH" --state all --json number,body --jq '.[0]' 2>/dev/null)
```

If a PR is found: extract `Closes/Fixes/Resolves #M` from `PR_INFO.body`. If an issue number `M` is found:

```bash
gh issue view "$M" --json title,comments \
  --jq '{title:.title, has_prd: ([.comments[] | select(.body | contains("<!-- prdx-prd -->"))] | length > 0)}'
```

If `has_prd` is true: derive the slug from the issue title (same rule as `/prdx:plan` Step 0 + `resume-from-issue.sh` Step 3). Show AskUserQuestion with message:

```
Resume CI-created PRD?
  Slug:   {DERIVED_SLUG}
  Issue:  #{M}
  PR:     #{PR_INFO.number}
```

- **Confirm** → `ISSUE_NUMBER=$M` + source the hook → route by `RESUME_PHASE` (same table above).
- **Decline** → fall through silently to new-feature path.

If any auto-detect check fails (no PR, no `Closes #M`, no PRD comment) → fall through silently. Never show an error in this path.

### Slug vs Description Resolution

**If the argument matches an existing PRD** (resolve using enhanced matching: exact → substring → word-boundary → disambiguation; see `/prdx:implement` for the full algorithm):

- Read PRD and check its `**Status:**` field
- **Detect quick mode from PRD:** If the PRD contains `**Quick:** true`, set `QUICK_MODE=true` internally
- **For parent PRDs** (has `## Children` section): Read child state files from `.prdx/state/` to determine progress. Display the child progress table (same as implement.md Step 2b). If all children are at `review` or beyond, ask if user wants to push each child. Otherwise, show which children still need work and display session instructions.
- **For single-platform and child PRDs**, resume from the appropriate phase:
  - `planning` → Continue planning
  - `in-progress` → Continue implementation
  - `review` → Ask user: Fix issues OR Create PR?
  - `implemented` → Check PRD for `## Pull Request` section with PR metadata. If PR exists, enter Reviewing Loop with PR number from PRD. If no PR, inform user and suggest `/prdx:push`
  - `completed` → Inform user the PRD is done

**If the argument is a feature description** (not an existing PRD):
- Proceed to planning phase

**If no argument provided:**

Scan `.prdx/state/*.json` for active state files (phase NOT `"pushed"` or `"completed"`). Present via AskUserQuestion:
- One active state file: "Continue {slug}" (Recommended) | "Choose a different PRD" | "Start a new feature"
- Multiple active: list all (slug, phase, quick) + "Start a new feature"
- None: list existing project PRDs (`grep -rl "^\*\*Project:\*\* $PROJECT_NAME" {PLANS_DIR}/*.md`) and ask: "Start a new feature or continue an existing PRD?"

## Reviewing Loop

**Triggered when:** state file has phase `"reviewing"`, or PRD status is `implemented` with `## Pull Request` section.

This loop lets the user iterate on PR review comments without leaving the workflow.

### Fetch PR State

1. **Fetch PR context:**
   ```bash
   gh pr view {PR_NUMBER} --json state,isDraft,reviews,comments,title
   ```

2. **Fetch review comments (unresolved):**
   ```bash
   gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/comments --jq '[.[] | select(.position != null)] | sort_by(.created_at) | .[] | "- \(.path):\(.position) — \(.body | split("\n") | first)"'
   ```

3. **Fetch PR-level review comments:**
   ```bash
   gh pr view {PR_NUMBER} --json reviews --jq '.reviews[] | select(.state != "APPROVED") | "[\(.state)] \(.body | split("\n") | first)"'
   ```

4. **Display summary:**
   ```
   PR #{PR_NUMBER}: {TITLE}
   Status: {Draft/Open}
   Reviews: {count pending/changes-requested/approved}
   Comments: {count unresolved}

   Recent comments:
   - path/file.ts:42 — "This should validate the input..."
   - path/other.ts:15 — "Consider using the existing helper..."
   ```

### Decision Point

Use AskUserQuestion to present options.

**If draft PR:**
- Option 1: "Fix from PR comments" — Auto-fetch and fix review comments
- Option 2: "Fix manually" — Describe issues to fix
- Option 3: "Mark ready for review" — Run `gh pr ready`, end workflow
- Option 4: "Done" — End workflow without further action

**If non-draft (entered via PRD resume):**
- Option 1: "Fix from PR comments" — Auto-fetch and fix review comments
- Option 2: "Fix manually" — Describe issues to fix
- Option 3: "Done" — End workflow

### Fix Routing

**"Fix from PR comments":**
- Fetch full comment details via `gh api`
- Read the referenced files
- Fix issues directly in conversation
- Commit fixes (using prdx.json commit config — same as `/prdx:implement` Step 5 commit logic)
- Push: `git push`
- Loop back to Fetch PR State (re-fetch, re-ask)

**"Fix manually":**
- Ask user to describe the issues
- Fix directly in conversation
- Commit fixes (using prdx.json commit config)
- Push: `git push`
- Loop back to Fetch PR State

**"Mark ready for review":**
- Run `gh pr ready {PR_NUMBER}`
- Update PRD status to `implemented`
- Write state: `{"slug": "{SLUG}", "phase": "pushed", "quick": {QUICK_MODE}, "pr_number": {PR_NUMBER}}` (do NOT delete — enables lesson capture)
- Display: `PR #{PR_NUMBER} marked ready for review. Lessons will be captured automatically after merge.`

**"Done":**
- Write state: `{"slug": "{SLUG}", "phase": "pushed", "quick": {QUICK_MODE}, "pr_number": {PR_NUMBER}}` (do NOT delete — PR exists, enables lesson capture)
- Display: `Lessons will be captured automatically after PR #{PR_NUMBER} is merged.`
