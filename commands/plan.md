---
description: "Create PRD using native plan mode"
argument-hint: "[--quick] [description]"
---

# /prdx:plan - Create Product Requirements Document

Uses Claude's **native plan mode** to explore the codebase and create a business-focused PRD.

## Philosophy

The plan phase is about **recon, planning, and feasibility**:
- What problem are we solving?
- Who benefits and how?
- Is this feasible? What are the risks?
- What's the general approach? (high-level, not detailed dev tasks)

Detailed implementation planning is done in `/prdx:implement` using the dev-planner agent.

**⛔ SCOPE BOUNDARY: This command ONLY creates a PRD document. It does NOT implement anything.**
- Do NOT write application code (no Edit/Write on source files)
- Do NOT create branches, run tests, or make commits
- Do NOT call `/prdx:implement` or platform agents
- The ONLY files you create/edit are PRD files in `{PLANS_DIR}/` and state files in `.prdx/`
- When the user approves the plan, you call ExitPlanMode → verify file → show decision point → STOP

## Usage

```bash
/prdx:plan "add biometric authentication to Android app"
/prdx:plan "fix user login failures on slow networks"
/prdx:plan "improve checkout conversion rate"

# Quick mode — lightweight template, ephemeral PRD
/prdx:plan --quick "fix login validation"
/prdx:plan --quick "address PR review comments on auth"
```

## MANDATORY: Use Isolated Exploration Agents

> **DO NOT use Glob, Grep, Read, or the built-in `Explore` subagent for codebase exploration.**
> **DO NOT use `subagent_type: "Explore"` - this is FORBIDDEN.**
>
> Instead, ALWAYS use these PRDX agents via the Task tool:
> - `subagent_type: "prdx:code-explorer"` — for understanding code, patterns, architecture
> - `subagent_type: "prdx:docs-explorer"` — for looking up library/API documentation
>
> These run in isolated context and return concise summaries, keeping the planning context clean.
> Launch multiple agents in parallel when possible.

## How It Works

This command enters **native plan mode** to:
1. Detect platform from description/codebase
2. Explore codebase using `prdx:code-explorer` agent (NOT `Explore`, NOT direct Glob/Grep/Read)
3. Create PRD using the PRDX template format
4. Iterate with user until approval
5. Plan auto-saved to `{PLANS_DIR}/`

## Workflow

### Resolve Plans Directory

Read the configured plans directory from `prdx.json`, falling back to `.prdx/plans` if not set:

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

**Use `$PLANS_DIR` throughout this command.**

### Plans Directory Setup (First Run Only)

Check if plans directory has been configured:

```bash
ls .prdx/plans-setup-done 2>/dev/null
```

If the file does NOT exist (first PRDX run in this project):

1. Auto-configure project-local plans (no user prompt):
   ```bash
   PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
   mkdir -p .claude .prdx "$PLANS_DIR"
   # Merge plansDirectory into settings.local.json (preserve existing keys)
   if [ -f .claude/settings.local.json ]; then
     jq --arg dir "$PLANS_SUBDIR" '. + {plansDirectory: $dir}' .claude/settings.local.json > .claude/settings.local.json.tmp && mv .claude/settings.local.json.tmp .claude/settings.local.json
   else
     echo "{\"plansDirectory\": \"$PLANS_SUBDIR\"}" > .claude/settings.local.json
   fi
   echo "local" > .prdx/plans-setup-done
   ```

If the file DOES exist, skip this step entirely.

### Gitignore Check (Every Run)

Ensure the gitignore is configured appropriately for the plans directory location:

```bash
GITIGNORE="$PROJECT_ROOT/.gitignore"
if echo "$PLANS_SUBDIR" | grep -q "^\.prdx/"; then
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF '.prdx/*' "$GITIGNORE"; then
    # Neither rule exists — add both
    echo '' >> "$GITIGNORE"
    echo '# PRDX - only track plans (ignore state, markers, etc.)' >> "$GITIGNORE"
    echo '.prdx/*' >> "$GITIGNORE"
    echo "!$PLANS_SUBDIR/" >> "$GITIGNORE"
  elif ! grep -qxF "!$PLANS_SUBDIR/" "$GITIGNORE"; then
    # .prdx/* exists but exception is wrong/missing — add correct exception
    echo "!$PLANS_SUBDIR/" >> "$GITIGNORE"
  fi
else
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF '.prdx/*' "$GITIGNORE"; then
    echo '' >> "$GITIGNORE"
    echo '# PRDX state (ignore all)' >> "$GITIGNORE"
    echo '.prdx/*' >> "$GITIGNORE"
  fi
fi
```

### Step 0: Parse Flags, Detect Project, and Derive Slug

**Parse `--quick` flag FIRST (before platform detection):**
- Strip `--quick` from arguments if present
- If `--quick` is present: set `QUICK_MODE=true`
- If `--quick` is NOT present: set `QUICK_MODE=false`

**Detect project name from git remote:**
```bash
gh repo view --json name --jq '.name' 2>/dev/null
```
Store the result as `{PROJECT_NAME}`. If the command fails (no remote, no `gh`), fall back to the repo root directory name:
```bash
basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null
```
If both fail, omit the `**Project:**` field from the PRD.

**Derive slug from description:**

Extract the **core concept** (2-4 words max) from the description and convert to kebab-case to produce `{SLUG}`. Strip filler words (add, implement, create, update, fix, refactor, improve), prepositions (the, a, for, from, to, in, on, of, with), and implementation details — keep only the domain-specific nouns and key verbs. For quick mode, prefix with `quick-`.

Examples:
- "Add biometric authentication to Android app" → `biometric-auth`
- "Read monthly report directly from Firestore instead of aggregating daily reports" → `monthly-report-read`
- "Fix user login failures on slow networks" → `login-failures`
- "Refactor checkout flow to use new payment provider" → `checkout-payment-refactor`
- Quick: "fix login validation" → `quick-login-validation`

**Write state file immediately:**
```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "planning", "quick": {QUICK_VALUE}}
EOF
```

This ensures the workflow is recoverable from the very start. The slug is derived from the description and stays consistent through the entire workflow — no tentative IDs needed.

### Step 1: Platform Detection

Auto-detect ALL potential platforms from the description and codebase:

**1. Description keywords (track all matches):**
- "backend", "API", "endpoint", "server" → `HAS_BACKEND`
- "frontend", "web", "UI", "React", "Vue", "Svelte", "Next.js" → `HAS_FRONTEND`
- "Android", "Kotlin", "Compose" → `HAS_ANDROID`
- "iOS", "Swift", "SwiftUI" → `HAS_IOS`
- "mobile", "app" (without platform specifics) → `HAS_ANDROID` + `HAS_IOS`

**2. Directory structure:**
```bash
if [ -d "backend" ] || [ -d "server" ] || [ -d "api" ]; then HAS_BACKEND=true; fi
if [ -d "frontend" ] || [ -d "web" ] || [ -d "client" ]; then HAS_FRONTEND=true; fi
if [ -d "android" ]; then HAS_ANDROID=true; fi
if [ -d "ios" ]; then HAS_IOS=true; fi
```

**3. Config files:**
- `package.json` + `tsconfig.json` → `HAS_BACKEND` (or `HAS_FRONTEND` if React/Vue/etc. detected)
- `build.gradle.kts` → `HAS_ANDROID`
- `Package.swift` → `HAS_IOS`

**4. Multi-Platform Selection:**

**If QUICK_MODE is true:** Skip multi-platform selection entirely. Auto-detect the single most relevant platform from the description (prefer the most specific match). Quick mode always targets a single platform — omit `**Platforms:**` and `**Implementation Order:**` fields.

If **multiple platform types detected** AND **QUICK_MODE is false** (e.g., backend + android, or android + ios):

Use **AskUserQuestion** with `multiSelect: true` to ask which platforms this PRD should target. Only show detected platforms as options:

```
Question: "Which platforms should this PRD cover?"
Header: "Platforms"
multiSelect: true
Options: [only the detected platforms from the list below]
  - Label: "Backend"
    Description: "API, server-side logic"
  - Label: "Frontend"
    Description: "Web UI"
  - Label: "Android"
    Description: "Android app"
  - Label: "iOS"
    Description: "iOS app"
```

**5. Implementation Order (when 2+ platforms selected):**

If user selected 2+ platforms, ask about implementation order using **AskUserQuestion**:

Present smart defaults based on platform combination:
- **Backend + mobile platforms** → "Backend first, then mobile platforms (Recommended)"
- **Frontend + mobile platforms** → "Frontend first, then mobile platforms"
- **Mobile only (android + ios)** → "Android first, then iOS (Recommended)"
- **All same tier** → "All in parallel"

```
Question: "What implementation order?"
Header: "Order"
Options:
  - Label: "{Smart default} (Recommended)"
    Description: "{description of the default order}"
  - Label: "All sequential"
    Description: "One at a time in listed order"
  - Label: "Custom"
    Description: "You specify the order"
```

If user picks "Custom", ask them to describe the order (they'll type it in the "Other" field).

Parse the result into the `**Implementation Order:**` field format:
```
**Implementation Order:**
1. backend
2. android, ios
```
Numbered steps. Platforms on the same step separated by commas. Steps execute sequentially.

**6. Single platform detected clearly** → use it directly (no selection needed)

### Step 2: Enter Plan Mode

Use **EnterPlanMode** tool to begin planning. (`QUICK_MODE` was already parsed in Step 0.)

**⛔ REMINDER: You are entering plan mode to WRITE A DOCUMENT, not to implement a feature.** Your output in plan mode is a PRD (markdown document). You are NOT writing application code. When the user approves the document, you exit plan mode — you do NOT start coding.

Once in plan mode, explore the codebase using **ONLY the PRDX exploration agents** (see mandatory section above):

```
Task tool: subagent_type="prdx:code-explorer", prompt="[your exploration question]"
Task tool: subagent_type="prdx:docs-explorer", prompt="[your docs question]"
```

**NEVER use:** `subagent_type: "Explore"`, Glob, Grep, or Read for exploration. These pollute the main context.

**If QUICK_MODE — use this lightweight template:**

Quick mode does a brief codebase scan (not a deep dive) and uses a streamlined template:

```markdown
# [Title]

**Type:** bug-fix | feature | refactor
**Project:** {PROJECT_NAME}
**Platform:** {DETECTED_PLATFORM}
**Quick:** true
**Status:** planning
**Created:** {TODAY's DATE}
**Branch:** {CURRENT_BRANCH}

## Problem

[1-2 sentences — what's broken or what needs to change]

## Goal

[1 sentence — the desired outcome]

## Acceptance Criteria

- [ ] [Testable outcome]

## Approach

[1-2 sentences — how to fix/implement this]
```

`{CURRENT_BRANCH}` = output of `git branch --show-current`. Quick mode stays on the current branch — no new branch is created.

**Filename convention for quick mode:** `prdx-quick-{slug}.md` (e.g., `prdx-quick-fix-login-validation.md`)

**If NOT QUICK_MODE — use the full PRD template:**

**Single-platform template:**

```markdown
# [Title]

**Type:** feature | bug-fix | refactor | spike
**Project:** {PROJECT_NAME}
**Platform:** {DETECTED_PLATFORM}
**Status:** planning
**Created:** {TODAY's DATE}
**Branch:** {BRANCH_NAME}

## Problem

[What pain point or opportunity exists? Why does this matter?]

## Goal

[What outcome do we want? Express in terms of user/business benefit.]

## User Stories

- As a [user type], I want to [action] so that [benefit]

## Acceptance Criteria

- [ ] [User-observable outcome - testable]
- [ ] [User-observable outcome - testable]

## Scope

### Included
- [What this PRD covers]

### Excluded
- [What this PRD explicitly does NOT cover]

## Approach

[High-level strategy - general direction, NOT detailed dev tasks]

## Risks & Considerations

- [Technical/business risks and constraints]
```

**Multi-platform (parent) template** — used when 2+ platforms are selected:

```markdown
# [Title]

**Type:** feature | bug-fix | refactor | spike
**Project:** {PROJECT_NAME}
**Platforms:** {PLATFORMS_LIST}
**Implementation Order:**
1. {first step platforms}
2. {second step platforms}
**Status:** planning
**Created:** {TODAY's DATE}

## Problem
...
## Goal
...
## User Stories
...
## Acceptance Criteria
...
## Scope
...
## Approach
...
## Risks & Considerations
...
```

**Parent PRDs have NO `**Branch:**` field.** They are orchestration-only — they track children but are never directly implemented. Each child PRD gets its own branch (see Step 4.5).

**Field rules:**
- **Single platform:** Include `**Platform:**` and `**Branch:**`. Omit `**Platforms:**` and `**Implementation Order:**`.
- **Multiple platforms (parent):** Include `**Platforms:**` and `**Implementation Order:**`. Omit `**Platform:**` and `**Branch:**`.

**Branch naming convention (single-platform and child PRDs):**
- feature → `feat/{slug}`
- bug-fix → `fix/{slug}`
- refactor → `refactor/{slug}`
- spike → `chore/{slug}`

**Quick mode exception:** Quick mode uses the current branch (`git branch --show-current`) instead of generating a new branch name.

### Step 3: Iterate Until Approval

Present the PRD draft and iterate based on user feedback:
- Revise sections as requested
- Add/remove scope items
- Adjust approach based on discussion

When user approves (says "looks good", "approve", "let's do it", etc.), the plan **document** is finalized.

**⛔ "Approval" means the PRD document is ready — NOT that you should start implementing.** When the user approves, proceed to Step 4 (ExitPlanMode). Do NOT interpret approval as permission to write application code, create branches, or start the implementation pipeline.

### Step 4: Save State and Exit Plan Mode

When the user approves:

**4a. Update state to `post-planning` BEFORE exiting plan mode.**

This is critical because Claude Code may offer a "clear context" option after ExitPlanMode. If the user chooses it, all post-exit steps are lost. By saving state first, re-running `/prdx:prdx` picks up from `post-planning` and shows the decision point correctly.

```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "post-planning", "quick": {QUICK_VALUE}}
EOF
```

**4b. Call ExitPlanMode.**

**IMPORTANT:** Do NOT ask "Should I exit plan mode?" or "Ready to exit?" - just call ExitPlanMode directly when the user approves the plan. The approval to exit is implicit in their approval of the plan.

---

**⛔ CRITICAL — POST-PLAN-MODE INSTRUCTIONS ⛔**

**After calling ExitPlanMode, you MUST follow Steps 4c→4.5→5→5.5 below BEFORE doing anything else.**

**DO NOT skip ahead to implementation. DO NOT call `/prdx:implement`. DO NOT start coding.**

The ONLY things you should do after ExitPlanMode are:
1. Verify the plan file naming (Step 4c)
2. Generate child PRDs if multi-platform (Step 4.5)
3. Verify plan file exists (Step 5)
4. Show decision point (Step 5.5)
5. **STOP and wait for user input**

If you find yourself about to implement or write code after plan mode exits — STOP. You are in the wrong phase.

**NOTE:** If context was cleared after ExitPlanMode, the state file already says `post-planning` (saved in Step 4a). Re-running `/prdx:prdx` will find it and show the decision point correctly — no work is lost.

---

**4c. Verify Plan File Naming:**

**Quick mode:** The filename **MUST** be `prdx-quick-{slug}.md` (e.g., `prdx-quick-fix-login-validation.md`).

**Normal mode:** The filename **MUST** be `prdx-{slug}.md` (e.g., `prdx-biometric-login.md`).

This prefix is how all PRDX commands discover plans. Without it, the plan is invisible to the workflow.

- Quick mode full path: `{PLANS_DIR}/prdx-quick-{slug}.md`
- Normal mode full path: `{PLANS_DIR}/prdx-{slug}.md`

### Step 4.5: Auto-Generate Child PRDs (Multi-Platform Only)

**Only run this step if ALL of the following are true:**
- `QUICK_MODE` is `false`
- The approved PRD has `**Platforms:**` with 2 or more platforms

**If not applicable, skip to Step 5.**

For each platform listed in `**Platforms:**`, create a child PRD at `{PLANS_DIR}/prdx-{parent-slug}-{platform}.md`.

**Child PRD template:**

```markdown
# [Parent Title] — [Platform Name]

**Type:** {same as parent}
**Project:** {PROJECT_NAME}
**Platform:** {platform}
**Parent:** {parent-slug}
**Status:** planning
**Created:** {same date as parent}
**Branch:** {type-prefix}/{parent-slug}-{platform}

## Problem

[Scoped from parent — platform-specific aspects only]

## Goal

[Scoped from parent — platform-specific goal]

## Acceptance Criteria

[Only ACs relevant to this platform, extracted from parent's ACs]

## Approach

[Platform-specific approach, derived from parent's Approach section]
```

Each child gets its **own branch** derived from the parent slug + platform (e.g., `feat/biometric-auth-backend`, `feat/biometric-auth-android`). This allows children on the same Implementation Order step to run in parallel sessions without git conflicts.

Use your judgment to scope the parent's ACs and Approach to what is relevant for each platform. Do not include ACs that belong to other platforms.

**After creating all child PRD files, append a `## Children` section to the parent PRD:**

```markdown
## Children

- prdx-{parent-slug}-{platform1}.md — {platform1} (`planning`) — branch: {type-prefix}/{parent-slug}-{platform1}
- prdx-{parent-slug}-{platform2}.md — {platform2} (`planning`) — branch: {type-prefix}/{parent-slug}-{platform2}
```

(Add one line per platform, in the order listed in `**Platforms:**`.)

**Write state files for each child** (parent state file was already created in Step 0):

```bash
mkdir -p .prdx/state
```

For each child platform:
```bash
echo '{"slug": "{parent-slug}-{platform}", "phase": "planning", "quick": false, "parent": "{parent-slug}"}' > .prdx/state/{parent-slug}-{platform}.json
```

### Step 5: Verify Plan File Naming

**After ExitPlanMode**, verify the saved plan has the correct prefix:

1. Check if the plan was saved with the correct name:
   ```bash
   # Quick mode:
   ls {PLANS_DIR}/prdx-quick-{slug}.md 2>/dev/null
   # Normal mode:
   ls {PLANS_DIR}/prdx-{slug}.md 2>/dev/null
   ```

2. If not found, search for the plan by its title or recent creation:
   ```bash
   # Find recently created plans without prdx- prefix
   find {PLANS_DIR}/ -name "*.md" -mmin -5 -not -name "prdx-*" 2>/dev/null
   # Or search by title content
   grep -rl "^# {TITLE}" {PLANS_DIR}/*.md 2>/dev/null | grep -v "prdx-"
   ```

3. If a non-prefixed plan is found, rename it:
   ```bash
   # Quick mode:
   mv {PLANS_DIR}/{old-name}.md {PLANS_DIR}/prdx-quick-{slug}.md
   # Normal mode:
   mv {PLANS_DIR}/{old-name}.md {PLANS_DIR}/prdx-{slug}.md
   ```

4. If no plan file is found at all, the plan may not have saved. Warn the user:
   ```
   Plan file not found at expected path.

   Check {PLANS_DIR}/ for recently created files and rename if needed.
   ```

**Display summary:**

**Quick mode:**
```
Quick plan created and saved

PRD: {PLANS_DIR}/prdx-quick-{slug}.md
Platform: {PLATFORM}
Status: planning
Branch: {BRANCH}

Next steps:
- Run /prdx:implement quick-{slug} to start implementation
- Or run /prdx:prdx quick-{slug} for guided workflow
```

**Normal mode (single platform):**
```
PRD created and saved

PRD: {PLANS_DIR}/prdx-{slug}.md
Platform: {PLATFORM}
Status: planning
Branch: {BRANCH}

Next steps:
- Run /prdx:implement {slug} to start implementation
- Or run /prdx:prdx {slug} for guided workflow
```

**Normal mode (multi-platform):**
```
PRD created and saved

Parent PRD: {PLANS_DIR}/prdx-{slug}.md
Platforms: {PLATFORMS_LIST}
Implementation Order: {ORDER_SUMMARY}
Status: planning

Child PRDs created:
  - prdx-{slug}-{platform1}.md ({platform1}) — branch: {type-prefix}/{slug}-{platform1}
  - prdx-{slug}-{platform2}.md ({platform2}) — branch: {type-prefix}/{slug}-{platform2}
  [one line per platform]

Next steps:
- Run /prdx:implement {slug} to see implementation instructions
- Or implement children directly in separate sessions:
  /prdx:implement {slug}-{platform1}
  /prdx:implement {slug}-{platform2}
  [one line per platform]
```

### Step 5.5: Decision Point

**State file was already written in Steps 0 and 4a.** No need to write it here.

**Check if this was called from a `/prdx:prdx` workflow:**

Read the state file:
```bash
cat .prdx/state/{SLUG}.json 2>/dev/null
```

**If the state file exists with `"phase": "post-planning"`** (called from `/prdx:prdx`):

---

**⛔ MANDATORY DECISION POINT — DO NOT SKIP ⛔**

**You are NOT allowed to proceed to implementation. You MUST ask the user what to do next.**

---

Show the decision point via **AskUserQuestion**:

**Normal mode** (quick is false):
- Option 1: "Publish to GitHub" — Create issue for team visibility
- Option 2: "Implement now" — Start coding immediately
- Option 3: "Stop here" — Review PRD later

**Quick mode** (quick is true):
- Option 1: "Implement now" (Recommended) — Start coding immediately
- Option 2: "Stop here" — Review plan later

**⛔ FULL STOP.** Do NOT proceed beyond this AskUserQuestion. Do NOT call `/prdx:implement`. Do NOT start coding. Do NOT explore the codebase for implementation. Just display the user's choice and STOP. The `/prdx:prdx` workflow (if still in context) or the user's next invocation will handle routing.

**If no state file exists** (standalone `/prdx:plan` call):

Just display the summary above and end. No decision point needed.

## Error Handling

### No Description Provided

```
No description provided

Usage: /prdx:plan "description"

Examples:
  /prdx:plan "add user authentication"
  /prdx:plan "fix memory leak in image loading"
```

### Platform Detection Ambiguous

Use AskUserQuestion to let user choose platform.

## Optional Flags

### --quick

Use lightweight template for ephemeral tasks:
```bash
/prdx:plan --quick "fix login validation"
```

Creates `prdx-quick-{slug}.md` with a streamlined template (Problem, Goal, AC, Approach only). No User Stories, Scope, or Risks sections. Brief codebase scan instead of deep exploration.

### --platform

Override platform detection:
```bash
/prdx:plan "add caching" --platform=backend
```

### --type

Override type inference:
```bash
/prdx:plan "improve performance" --type=refactor
```

Valid types: `feature`, `bug-fix`, `refactor`, `spike`

## Key Points

1. **Uses native plan mode** - Not a custom agent
2. **Follow the PRD template exactly** - Full template for normal mode, lightweight for `--quick`
3. **Plans auto-save** - To `{PLANS_DIR}/` directory
4. **Naming convention** - `prdx-{slug}.md` (normal) or `prdx-quick-{slug}.md` (quick mode)
5. **Status starts as `planning`** - Updated by implement/push commands
6. **Branch name in PRD** - Used by implement command
7. **Quick mode** - Adds `**Quick:** true` field, uses lightweight template, brief exploration
