---
description: "Complete PRD workflow with agent teams: plan → team implement → push"
argument-hint: "[--quick] [feature description or PRD slug]"
---

## Pre-Computed Context

```bash
echo "=== Git Context ==="
echo "Branch: $(git branch --show-current)"
echo "Default: $(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')"
git status --short
echo ""
echo "=== Config ==="
# Walk up to find prdx.json
DIR="$PWD"; while [ "$DIR" != "/" ]; do
  [ -f "$DIR/prdx.json" ] && echo "Config: $DIR/prdx.json" && break
  [ -f "$DIR/.prdx/prdx.json" ] && echo "Config: $DIR/.prdx/prdx.json" && break
  DIR=$(dirname "$DIR")
done
[ "$DIR" = "/" ] && echo "Config: (defaults)"
echo ""
echo "=== Plans Directory ==="
PLANS_DIR=$(jq -r '.plansDirectory // empty' .claude/settings.local.json 2>/dev/null)
if [ -z "$PLANS_DIR" ]; then
  PLANS_DIR="$HOME/.claude/plans"
elif [[ "$PLANS_DIR" != /* ]]; then
  PLANS_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/$PLANS_DIR"
fi
echo "Plans directory: $PLANS_DIR"
echo ""
echo "=== Available PRDs (this project) ==="
PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
grep -rl "^\*\*Project:\*\* $PROJECT_NAME" "$PLANS_DIR"/*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^prdx-//' || echo "No PRDs found"
echo ""
echo "=== Agent Teams ==="
echo "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-not set}"
```

# /prdx:prdx:agent - Agent Teams Workflow

> **Alternative entry point for PRDX using Claude Code's experimental agent teams.**
> Same workflow as `/prdx:prdx` but uses persistent teammates instead of sequential subagents.
> Falls back to `/prdx:prdx` if agent teams are unavailable.

## Team Composition

| Role | Name | Based On | Responsibility |
|---|---|---|---|
| **Lead** | _(main session)_ | You | Steers project, makes decisions, relays between teammates |
| **Architect** | `architect` | `prdx:code-explorer` + `prdx:dev-planner` | Explores codebase, creates PRD, creates dev plan, answers questions |
| **Platform Dev** | `{platform}-dev` | `prdx:{platform}-developer` | Implements the dev plan for their platform |
| **Auditor** | `auditor` | `prdx:ac-verifier` + `prdx:code-reviewer` | Verifies ACs, then reviews code quality |

**Rules:**
- **1:1 rule**: Exactly one developer per platform. No exceptions.
- **Cross-platform changes**: Platform devs NEVER edit files outside their platform scope. If they need changes elsewhere, they message the lead who delegates to the appropriate dev.
- **Architect stays alive**: Available throughout implementation for codebase questions from platform devs.

## Workflow

### Step 0: Auto-Capture Lessons from Merged PRs

**Identical to `/prdx:prdx` Step 0.** Run the same lesson capture logic before any other work.

Scan `.prdx/state/` for state files with `"phase": "pushed"`, check if PRs are merged via `gh pr view`, extract learnings, append to CLAUDE.md, clean up state files.

---

### Step 1: Determine Entry Point

**Identical to `/prdx:prdx` Step 1.** Same state file checking, argument parsing, `--quick` flag handling, PRD matching, and resume logic.

The only difference: when resuming from `"implementing"` phase, jump to Step 4 (team implementation) instead of calling `/prdx:implement`.

---

### Step 2: Create Team

**This is the first real action after entry point determination.** Spawn the team immediately so the architect is available for all planning work.

#### Step 2a: Feature Gate Check

Verify agent teams are available by attempting to use the TeamCreate tool.

**If TeamCreate is not available** (tool not found, feature not enabled, wrong environment):

```
Agent teams not available in this environment.
Falling back to sequential mode (/prdx:prdx).

To enable agent teams:
  Add to settings.json: {"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}}
```

Then run the standard `/prdx:prdx` workflow with the same arguments and STOP. Do not continue with the steps below.

#### Step 2b: Initialize State

**Derive slug from description** (same logic as `/prdx:plan` Step 0):
Convert description to kebab-case. For quick mode, prefix with `quick-`.

```bash
mkdir -p .prdx/state .prdx
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "planning", "quick": {QUICK_MODE}}
EOF
```

#### Step 2c: Detect Platform

**Same logic as `/prdx:plan` Step 1.** Auto-detect platforms from description and codebase. For multi-platform, ask user which platforms and implementation order via AskUserQuestion.

For quick mode: auto-detect single platform, skip multi-platform selection.

#### Step 2d: Spawn Team and Architect

Create the team:
```
TeamCreate:
  team_name: "prdx-{SLUG}"
```

Spawn the architect teammate:

```
Agent tool:
  team_name: "prdx-{SLUG}"
  name: "architect"
  subagent_type: "prdx:dev-planner"
  prompt: "You are the **architect** on team prdx-{SLUG}.

    ## Your Role

    You handle ALL planning for this feature — both the PRD (product requirements)
    and the dev plan (technical implementation). You explore the codebase ONCE and
    retain that context for both phases.

    ## Phase 1: PRD Creation

    The lead will message you with a feature description. Your job:

    1. Read the relevant skill files:
       - .claude/skills/impl-patterns.md
       - .claude/skills/testing-strategy.md
       - .claude/skills/prd-review.md
    2. Explore the codebase thoroughly to understand:
       - Existing patterns and architecture
       - Related features and code
       - Testing patterns
       - Potential risks and constraints
    3. Draft a PRD using the PRDX template format (see CLAUDE.md for templates)
    4. Send the draft to the lead via SendMessage for review
    5. Iterate based on lead's feedback until approved
    6. When approved, write the final PRD to {PLANS_DIR}/prdx-{SLUG}.md

    {QUICK_MODE_INSTRUCTION}

    ## Phase 2: Dev Planning

    After the lead approves the PRD and asks for a dev plan:

    1. Create a detailed implementation plan with phased task groups
    2. Use <!-- phase-summary [...] --> JSON block for machine parsing
    3. Include parallel/sequential annotations per phase
    4. Map tests to acceptance criteria
    5. Send the dev plan to the lead via SendMessage

    ## Ongoing: Answer Questions

    During implementation, platform devs may message you with codebase questions.
    Answer them using the context you built during exploration.

    ## Communication

    - Send PRD drafts and dev plans to the lead via SendMessage
    - Respond to direct messages from platform devs
    - Keep messages concise (PRD: full template, dev plan: ~3KB, answers: ~1KB)

    ## Platform Context

    Platform: {PLATFORM}
    Project: {PROJECT_NAME}
    Date: {TODAY's DATE}
    Branch convention: {BRANCH_PREFIX}/{SLUG}

    WAIT for the lead to message you with the feature description before starting."
```

Where `{QUICK_MODE_INSTRUCTION}` is:
- If quick mode: `"Use the lightweight quick template: Problem (1-2 sentences), Goal (1 sentence), Acceptance Criteria, Approach (1-2 sentences). Save as prdx-quick-{SLUG}.md. Use current branch: {CURRENT_BRANCH}."`
- If normal mode: `"Use the full PRDX PRD template with all sections (Problem, Goal, User Stories, Acceptance Criteria, Scope, Approach, Risks). Save as prdx-{SLUG}.md."`

---

### Step 3: Planning (Architect)

The architect is already spawned and waiting. All planning is delegated to the architect — the lead never explores the codebase or drafts the PRD directly.

#### Step 3a: Lead Initiates Planning

Send the feature description to the architect:

```
SendMessage:
  type: "message"
  recipient: "architect"
  content: "Explore the codebase and create a PRD for this feature:

  {FEATURE_DESCRIPTION}

  Platform: {PLATFORM}
  Type: {TYPE_IF_DETECTED}

  Send me the PRD draft when ready."
```

#### Step 3b: PRD Review Loop

Wait for the architect's PRD draft message.

When received, display the PRD draft to the user and use AskUserQuestion:

- Option 1: "Approve" (Recommended) — PRD looks good
- Option 2: "Revise" — Send feedback to architect
- Option 3: "Stop" — End workflow

**If "Revise":** Ask user for their feedback, then relay to architect:
```
SendMessage:
  type: "message"
  recipient: "architect"
  content: "Revise the PRD based on this feedback:

  {USER_FEEDBACK}

  Send me the updated draft."
```
Loop back to waiting for architect's revised draft.

**If "Approve":** Message the architect to finalize:
```
SendMessage:
  type: "message"
  recipient: "architect"
  content: "PRD approved. Write the final version to {PLANS_DIR}/prdx-{SLUG}.md

  Then confirm when the file is saved."
```

Wait for architect's confirmation. Then verify the file exists:
```bash
ls {PLANS_DIR}/prdx-{SLUG}.md 2>/dev/null
```

Update state:
```bash
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "post-planning", "quick": {QUICK_MODE}}
EOF
```

**If "Stop":** Shut down team, delete state, end workflow.

#### Step 3c: Post-Planning Decision Point

**Same decision point as `/prdx:prdx` Step 2:**

**Normal mode:**
- Option 1: "Publish to GitHub" — Create issue for team visibility
- Option 2: "Implement now" — Start coding
- Option 3: "Stop here" — Review PRD later

**Quick mode:**
- Option 1: "Implement now" (Recommended)
- Option 2: "Stop here"

Route: Publish → Step 3d, Implement → Step 4, Stop → shut down team, delete state, end workflow.

#### Step 3d: Publish (Optional)

If user chose to publish, run `/prdx:publish {slug}` (same as `/prdx:prdx` Step 2a).

After issue is created, ask: Implement now? / Stop here?

---

### Step 4: Team Implementation

**Update workflow state:**
```bash
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "implementing", "quick": {QUICK_MODE}}
EOF
```

#### Step 4.0: Load Configuration

**Same as `/prdx:implement` Step 1:** Read `prdx.json`, validate, build `COMMIT_INSTRUCTIONS`.

#### Step 4.1: Detect PRD Type

Read the PRD from `{PLANS_DIR}/prdx-{SLUG}.md`.

**For parent PRDs (has `## Children` section):**

Parent PRDs cannot be implemented in a single team session (teammates share working directory = git branch conflicts).

Display the child progress table and session instructions (same as `/prdx:implement` Step 2b), but recommend using `/prdx:prdx:agent {child-slug}` for each child.

Shut down the team. Delete `.prdx/state/{SLUG}.json`. End workflow.

**For child PRDs (has `**Parent:**` field):**

Run prerequisite check (same as `/prdx:implement` Step 2c). If prerequisites not met, warn user and offer to override.

Continue with implementation below.

**For single-platform PRDs:**

Continue with implementation below.

#### Step 4.2: Git Setup

**Same as `/prdx:implement` Step 4:** Checkout/create the PRD's designated branch.

#### Step 4.3: Run Pre-Implement Hook

```bash
if [ -f hooks/prdx/pre-implement.sh ]; then
  ./hooks/prdx/pre-implement.sh "{slug}"
fi
```

If hook fails, stop and show error.

#### Step 4.4: Dev Planning (Architect)

The architect teammate is already alive from Step 3. Message it to create the dev plan:

```
SendMessage:
  type: "message"
  recipient: "architect"
  content: "PRD is approved and we're on branch {BRANCH}. Create a detailed dev plan.

  Read the skills files if you haven't already:
  - .claude/skills/impl-patterns.md (focus on {PLATFORM} section)
  - .claude/skills/testing-strategy.md

  Produce a phased implementation plan with:
  - Phase-summary JSON block (<!-- phase-summary [...] -->)
  - Parallel/sequential annotations per phase
  - Specific files to create/modify
  - Tests mapped to acceptance criteria

  Send me the dev plan when ready (~3KB max)."
```

Wait for the architect's dev plan message. Store it as `DEV_PLAN`.

Display:
```
Dev plan received from architect.
```

#### Step 4.5: Spawn Platform Developer and Auditor

Now spawn the remaining teammates:

**Platform Developer:**
```
Agent tool:
  team_name: "prdx-{SLUG}"
  name: "{PLATFORM}-dev"
  subagent_type: "prdx:{PLATFORM}-developer"
  prompt: "You are the **{PLATFORM} developer** on team prdx-{SLUG}.

    ## Your Role

    Implement the feature described in the dev plan you'll receive from the lead.
    You manage your own phases — execute them sequentially, one commit per phase.

    ## Rules

    - **1:1 RULE**: You ONLY modify files within your platform scope ({PLATFORM}).
      If you need changes in files outside your scope, message the lead via SendMessage
      and ask them to delegate. Do NOT edit those files yourself.
    - **Ask the architect**: If you need to understand codebase patterns, existing code,
      or architecture decisions, message 'architect' directly via SendMessage.
    - **TDD**: Write tests first, verify they fail, then implement.
    - **Atomic commits**: One commit per phase.
    - **TodoWrite**: Track tasks — mark in_progress when starting, completed when done.

    ## Commit Format

    {COMMIT_INSTRUCTIONS}

    ## Communication

    - The lead will send you the dev plan. Wait for it before starting.
    - Message 'architect' directly for codebase questions.
    - When ALL phases are done, send the lead your implementation summary (~2KB max):
      Files created, files modified, tests written, commits, test results.

    WAIT for the lead to send you the dev plan before starting."
```

**Auditor (AC Verifier):**
```
Agent tool:
  team_name: "prdx-{SLUG}"
  name: "auditor"
  subagent_type: "prdx:ac-verifier"
  prompt: "You are the **auditor** (AC verification) on team prdx-{SLUG}.

    ## Your Role

    Verify acceptance criteria are met using the 3-point check:
    1. Code exists — implementation addresses the AC
    2. Test exists — at least one test covers the AC
    3. Coverage — test covers happy path AND error/edge cases

    ## Acceptance Criteria

    {ACCEPTANCE_CRITERIA from PRD}

    ## Communication

    - WAIT for the lead to message you before starting
    - Send your AC verification summary to the lead via SendMessage (~1KB max)
    - If the lead asks you to re-verify after fixes, do so

    WAIT for the lead to tell you when to start."
```

**Auditor (Code Reviewer):**
```
Agent tool:
  team_name: "prdx-{SLUG}"
  name: "reviewer"
  subagent_type: "prdx:code-reviewer"
  prompt: "You are the **reviewer** (code quality) on team prdx-{SLUG}.

    ## Your Role

    Review implementation for bugs, security issues, quality problems, and convention adherence.

    ## Rules

    - Only report issues with >80% confidence
    - Categorize issues: bug, security, quality
    - Include file path and line number for each issue
    - Do NOT check acceptance criteria (handled by ac-verifier)

    ## Communication

    - WAIT for the lead to message you before starting
    - Send your review summary to the lead via SendMessage (~2KB max)
    - If the lead asks you to re-review after fixes, do so

    WAIT for the lead to tell you when to start."
```

#### Step 4.6: Implementation (Platform Developer)

Send the dev plan to the platform developer:

```
SendMessage:
  type: "message"
  recipient: "{PLATFORM}-dev"
  content: "Here is the dev plan. Begin implementation now.

  ## PRD (for reference)

  **Title:** {PRD_TITLE}
  **Acceptance Criteria:**
  {ACCEPTANCE_CRITERIA}

  ## Dev Plan

  {DEV_PLAN}

  ## Instructions

  1. Execute ALL phases in the dev plan sequentially
  2. TDD: write tests first, then implement
  3. One atomic commit per phase
  4. Message 'architect' if you have codebase questions
  5. When done, send me your implementation summary

  Go."
```

Wait for the platform dev's implementation summary. Store it as `IMPL_SUMMARY`.

Display:
```
Implementation complete. Starting AC verification.
```

#### Step 4.7a: AC Verification (Auditor)

Message the auditor to verify acceptance criteria:

```
SendMessage:
  type: "message"
  recipient: "auditor"
  content: "Implementation is complete. Verify acceptance criteria now.

  Base branch: {DEFAULT_BRANCH}
  Run: git diff {DEFAULT_BRANCH}..HEAD

  Perform the 3-point check for each AC.
  Send me your AC verification summary."
```

Wait for auditor's AC verification message.

**If all ACs verified:** Proceed to Step 4.7b.

**If ACs unmet (AC fix loop — max 3 attempts):**

1. Display AC verification summary to user
2. Relay unmet ACs to platform dev:
   ```
   SendMessage:
     type: "message"
     recipient: "{PLATFORM}-dev"
     content: "The auditor found unmet acceptance criteria. Fix them:

     {UNMET_ACS}

     Write missing tests where indicated.
     Commit fixes and message me when done."
   ```
3. Wait for platform dev's fix confirmation
4. Message auditor to re-verify:
   ```
   SendMessage:
     type: "message"
     recipient: "auditor"
     content: "Fixes applied. Re-verify ACs (git diff {DEFAULT_BRANCH}..HEAD).

     Send me your updated AC verification."
   ```
5. Wait for auditor's re-verification
6. If ACs still unmet and attempts < 3, loop back to step 2
7. **If ACs still unmet after 3 attempts:** Offer user choice via AskUserQuestion:
   - Option 1: "Proceed to code review" (Recommended) — Continue with noted AC gaps
   - Option 2: "Fix manually" — Stop, user fixes AC issues
   - Option 3: "Stop" — End workflow

#### Step 4.7b: Code Review (Reviewer)

Message the reviewer to begin code quality review:

```
SendMessage:
  type: "message"
  recipient: "reviewer"
  content: "Review the implementation now.

  Base branch: {DEFAULT_BRANCH}
  Run: git diff {DEFAULT_BRANCH}..HEAD

  Check for bugs, security issues, quality problems, and convention adherence.
  Only report issues with >80% confidence.

  Send me your review summary."
```

Wait for reviewer's review message.

**If no issues found:** Proceed to Step 4.8.

**If issues found (review cycle 1):**

1. Display review summary to user
2. Relay issues to platform dev:
   ```
   SendMessage:
     type: "message"
     recipient: "{PLATFORM}-dev"
     content: "The reviewer found these issues. Fix them:

     {REVIEW_ISSUES}

     Commit fixes and message me when done."
   ```
3. Wait for platform dev's fix confirmation
4. Message reviewer to re-review:
   ```
   SendMessage:
     type: "message"
     recipient: "reviewer"
     content: "Fixes applied. Re-review the diff (git diff {DEFAULT_BRANCH}..HEAD).

     Send me your updated review."
   ```
5. Wait for reviewer's second review
6. **If issues remain after cycle 2:** Note remaining issues, offer user choice via AskUserQuestion:
   - Option 1: "Proceed anyway" (Recommended) — Continue with noted issues
   - Option 2: "Fix manually" — Stop, user fixes remaining issues
   - Option 3: "Stop" — End workflow

**If no issues after fixes:** Proceed to Step 4.8.

#### Step 4.8: Shutdown Team

After review completes:

1. **Shut down all teammates** (send shutdown requests or let them go idle)

2. **Clean up team:**
   ```
   TeamDelete
   ```

3. **Append implementation notes to PRD** (same as `/prdx:implement` Step 5d):
   ```markdown
   ---
   ## Implementation Notes ({PLATFORM})

   **Branch:** {BRANCH}
   **Implemented:** {TODAY's DATE}

   {IMPL_SUMMARY}
   ```

4. **Run post-implement hook:**
   ```bash
   if [ -f hooks/prdx/post-implement.sh ]; then
     ./hooks/prdx/post-implement.sh "{slug}"
   fi
   ```

5. **Update state:**
   ```bash
   cat > .prdx/state/{SLUG}.json << EOF
   {"slug": "{SLUG}", "phase": "post-implement", "quick": {QUICK_MODE}}
   EOF
   ```

---

### Step 5: Post-Implementation Decision Point

**Identical to `/prdx:prdx` Step 3 (after implementation).**

**If QUICK_MODE:**
- Option 1: "Create PR" (Recommended)
- Option 2: "Create Draft PR"
- Option 3: "Done" — Commit only, no PR
- Option 4: "Test first"

**If NOT QUICK_MODE:**
- Option 1: "Test first" (Recommended)
- Option 2: "Create PR now"
- Option 3: "Create Draft PR"

Route: same as `/prdx:prdx`. PR creation uses `/prdx:push {slug}`.

---

### Step 5a: Review Status Decision

**Identical to `/prdx:prdx` Step 3a.** When PRD status is `review`, offer Create PR / Draft PR / Fix issues / View summary.

When "Fix issues" is chosen: fix directly in conversation (no team needed), commit, ask again.

---

### Step 5b: Reviewing Loop (Draft PR)

**Identical to `/prdx:prdx` Step 3b.** Fetch PR comments, offer fix/push/mark-ready options. Fixes happen in the main session (no team).

---

### Step 6: Create Pull Request

**Identical to `/prdx:prdx` Step 4.** Uses `/prdx:push {slug}` (with `--draft` if applicable).

State transitions: `pushing` → `pushed` (for non-draft) or `reviewing` (for draft).

---

### Step 7: Cleanup (Quick Mode Only)

**Identical to `/prdx:prdx` Step 5.** Delete temporary PRD and state files when user chose "Done" (no PR). For PRs, cleanup happens after lesson capture on next startup.

---

## Important Guidelines

**All guidelines from `/prdx:prdx` apply.** Additionally:

**Team-specific guidelines:**

- **Always shut down the team** before entering post-implementation decision points. The team is only active during planning and implementation (Steps 3-4). Decision points, PR creation, and fix loops happen in the main session.
- **Relay, don't duplicate.** The lead relays messages between teammates. Do not re-explore the codebase yourself — the architect already has that context.
- **Trust the 1:1 rule.** If a platform dev reports needing changes outside their scope, acknowledge it and note it for the user. Do not spawn additional devs or override the rule.
- **Handle teammate failures gracefully.** If a teammate stops responding or errors:
  - Architect fails: fall back to invoking `prdx:dev-planner` as a standard subagent (Agent tool)
  - Platform dev fails: offer user choice — retry (spawn new dev), continue manually, or stop
  - Auditor fails: fall back to invoking `prdx:ac-verifier` then `prdx:code-reviewer` as standard subagents
- **Task tools are advisory.** Attempt TaskCreate/TaskList/TaskUpdate for visibility. If they fail (VSCode limitation), skip silently. SendMessage is the primary coordination mechanism.

**Context efficiency:**

The lead's context stays lean. Teammate messages are the only data entering the main context:
- Architect PRD draft: full template (~2KB normal, ~500B quick)
- Architect dev plan: ~3KB
- Platform dev summary: ~2KB
- Auditor AC verification: ~1KB
- Reviewer code quality: ~2KB
- Total: ~9KB for a full workflow (vs ~8KB in sequential mode — comparable)

**Error handling:**
- If TeamCreate fails → fall back to `/prdx:prdx`
- If any teammate fails → fall back to equivalent subagent
- State files ensure workflow is resumable regardless of team state
- Team shutdown is best-effort (teammates may be already idle)
