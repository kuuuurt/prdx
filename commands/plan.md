---
description: "Create PRD using native plan mode"
argument-hint: "[--quick] [description]"
---

## Pre-Computed Context

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-plans-dir.sh"
echo "PLANS_DIR=$PLANS_DIR"
echo "PROJECT_ROOT=$PROJECT_ROOT"
source "$(git rev-parse --show-toplevel)/hooks/prdx/ensure-gitignore.sh"
source "$(git rev-parse --show-toplevel)/hooks/prdx/first-run-setup.sh"
echo "FIRST_RUN=$FIRST_RUN"
echo "Branch: $(git branch --show-current)"
PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
echo "PROJECT_NAME=$PROJECT_NAME"
git branch -a --format='%(refname:short)' 2>/dev/null | head -50
```

# /prdx:plan - Create Product Requirements Document

Uses Claude's **native plan mode** to explore the codebase and create a business-focused PRD. This command ONLY creates a PRD document — no code, branches, tests, or commits.

## Exploration Rules

> ALWAYS use `prdx:code-explorer` and `prdx:docs-explorer` agents via the Task tool for exploration.
> NEVER use Glob, Grep, Read, or `subagent_type: "Explore"` directly.

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

Auto-detect ALL potential platforms from the description and codebase using an expanded heuristic scan:

**1. Description keywords (track all matches):**
- "backend", "API", "endpoint", "server", "REST", "GraphQL", "gRPC", "microservice" → `DETECTED_CONTEXTS` += `backend`
- "frontend", "web", "UI", "React", "Vue", "Svelte", "Next.js", "HTML", "CSS", "browser" → `DETECTED_CONTEXTS` += `frontend`
- "Android", "Kotlin", "Compose", "Jetpack" → `DETECTED_CONTEXTS` += `android`
- "iOS", "Swift", "SwiftUI", "UIKit", "Xcode" → `DETECTED_CONTEXTS` += `ios`
- "mobile", "app" (without platform specifics) → `DETECTED_CONTEXTS` += `android` + `ios`
- "Python", "Django", "FastAPI", "Flask", "pip", "conda", "ML", "machine learning" → `DETECTED_CONTEXTS` += `python`
- "Go", "Golang" → `DETECTED_CONTEXTS` += `go`
- "Rust", "Cargo", "crate" → `DETECTED_CONTEXTS` += `rust`
- "Flutter", "Dart" → `DETECTED_CONTEXTS` += `flutter`
- "React Native", "Expo" → `DETECTED_CONTEXTS` += `react-native`
- "Java", "Spring", "Maven", "Gradle" (without Kotlin/Android) → `DETECTED_CONTEXTS` += `java`
- "data pipeline", "ETL", "dbt", "Airflow", "Spark", "Kafka", "warehouse" → `DETECTED_CONTEXTS` += `data`
- "infrastructure", "Terraform", "Ansible", "Kubernetes", "k8s", "Helm", "IaC" → `DETECTED_CONTEXTS` += `infra`
- "CLI", "command line", "terminal tool", "shell script" → `DETECTED_CONTEXTS` += `cli`

**2. File system heuristics (check in project root):**
```bash
# Python
[ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] || ls *.py 2>/dev/null | head -1
→ DETECTED_CONTEXTS += python

# Go
[ -f "go.mod" ]
→ DETECTED_CONTEXTS += go

# Rust
[ -f "Cargo.toml" ]
→ DETECTED_CONTEXTS += rust

# Flutter / Dart
[ -f "pubspec.yaml" ]
→ DETECTED_CONTEXTS += flutter

# Java / Spring (without Kotlin)
([ -f "pom.xml" ] || [ -f "build.gradle" ]) && ! [ -f "build.gradle.kts" ]
→ DETECTED_CONTEXTS += java

# Android (Kotlin)
[ -f "build.gradle.kts" ] || [ -d "android" ]
→ DETECTED_CONTEXTS += android

# iOS
[ -f "Package.swift" ] || [ -d "ios" ]
→ DETECTED_CONTEXTS += ios

# React Native
[ -f "react-native.config.js" ]
→ DETECTED_CONTEXTS += react-native

# Node.js / backend or frontend
[ -f "package.json" ]: inspect for React/Vue/Svelte/Next → frontend; Express/Fastify/Hono/Koa/NestJS → backend
[ -f "tsconfig.json" ] (without frontend framework) → backend

# Data pipelines
grep -r "dbt\|airflow\|spark\|kafka" requirements.txt pyproject.toml package.json 2>/dev/null
→ DETECTED_CONTEXTS += data

# Infrastructure
[ -d "terraform" ] || [ -d "ansible" ] || ls *.tf 2>/dev/null | head -1
→ DETECTED_CONTEXTS += infra

# Dockerfile only (no other strong signal)
[ -f "Dockerfile" ] && [ ${#DETECTED_CONTEXTS[@]} -eq 0 ]
→ DETECTED_CONTEXTS += infra

# CLI tools (Makefile present, no web/app deps)
[ -f "Makefile" ] && [ ${#DETECTED_CONTEXTS[@]} -eq 0 ]
→ DETECTED_CONTEXTS += cli

# Directory structure fallbacks
[ -d "backend" ] || [ -d "server" ] || [ -d "api" ] → DETECTED_CONTEXTS += backend (if not already present)
[ -d "frontend" ] || [ -d "web" ] || [ -d "client" ] → DETECTED_CONTEXTS += frontend (if not already present)
```

**Deduplication:** `DETECTED_CONTEXTS` is a unique list. Do not add the same context twice.

**3. Branch convention detection (run before deriving branch name):**

Scan existing branches to identify the dominant naming pattern:

```bash
git branch -a --format='%(refname:short)' 2>/dev/null | head -50
```

Look for prefix patterns in the results:
- `feature/` or `feat/` → note as `PREFIX_FEAT`
- `fix/` or `bugfix/` or `hotfix/` → note as `PREFIX_FIX`
- `chore/` → note as `PREFIX_CHORE`
- `refactor/` → note as `PREFIX_REFACTOR`
- Ticket patterns like `ABC-\d+/` (e.g., `PROJ-123/some-feature`) → note as `PREFIX_TICKET`

Count occurrences of each pattern. If a single pattern appears 2+ times and accounts for >50% of prefixed branches, treat it as the **dominant pattern** and use it when constructing branch names:
- If `feature/` is dominant, use `feature/{slug}` (not `feat/{slug}`)
- If `feat/` is dominant, use `feat/{slug}`
- Ticket patterns: preserve the ticket prefix style but append the slug (e.g., `PROJ-{NEXT_NUMBER}/{slug}` — if no ticket number is available, fall back to conventional)

If no dominant pattern is found, fall back to the conventional PRDX defaults:
- feature → `feat/{slug}`
- bug-fix → `fix/{slug}`
- refactor → `refactor/{slug}`
- spike → `chore/{slug}`

**4. Multi-Platform Selection:**

**If QUICK_MODE is true:** Skip multi-platform selection entirely. Auto-detect the single most relevant context from the description (prefer the most specific match). Quick mode always targets a single platform — omit `**Platforms:**` and `**Implementation Order:**` fields.

**If exactly one context is detected** AND **QUICK_MODE is false:** Auto-select it without asking. No AskUserQuestion needed.

**If multiple contexts detected** AND **QUICK_MODE is false:**

Use **AskUserQuestion** with `multiSelect: true` to ask which platforms this PRD should target. **Only show detected contexts as options** — do not show a fixed list of 4 options:

```
Question: "Which platforms should this PRD cover?"
Header: "Platforms"
multiSelect: true
Options: [dynamically built from DETECTED_CONTEXTS only]
  Example entries (use only what was detected):
  - Label: "backend"      Description: "API, server-side logic"
  - Label: "frontend"     Description: "Web UI"
  - Label: "android"      Description: "Android app"
  - Label: "ios"          Description: "iOS app"
  - Label: "python"       Description: "Python service or script"
  - Label: "go"           Description: "Go service or tool"
  - Label: "rust"         Description: "Rust application or library"
  - Label: "flutter"      Description: "Flutter cross-platform app"
  - Label: "react-native" Description: "React Native mobile app"
  - Label: "java"         Description: "Java / Spring service"
  - Label: "data"         Description: "Data pipeline or analytics"
  - Label: "infra"        Description: "Infrastructure / IaC"
  - Label: "cli"          Description: "CLI tool"
```

The `**Platform:**` field in the PRD is **free-form** — it accepts any string value, not just the 4 legacy values. Use the detected context label directly (e.g., `python`, `go`, `rust`, `flutter`, `data`, `infra`, `cli`).

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
**Platform:** {DETECTED_PLATFORM}   ← free-form: any string (python, go, rust, flutter, data, infra, cli, etc.)
**Status:** planning
**Created:** {TODAY's DATE}
**Branch:** {BRANCH_NAME}

## Problem

[What pain point or opportunity exists? Why does this matter?]

## Goal

[What outcome do we want? Express in terms of user/business benefit.]

## User Stories   ← include only when the feature has identifiable end users (omit for infra, data pipelines, CLI tools, libraries)

- As a [user type], I want to [action] so that [benefit]

## Acceptance Criteria

- [ ] [User-observable outcome - testable]
- [ ] [User-observable outcome - testable]

## Scope   ← include only when there are meaningful exclusions worth calling out (omit if scope is obvious)

### Included
- [What this PRD covers]

### Excluded
- [What this PRD explicitly does NOT cover]

## Approach

[High-level strategy - general direction, NOT detailed dev tasks]

## Risks & Considerations   ← include only when non-trivial risks or constraints exist (omit for straightforward changes)

- [Technical/business risks and constraints]
```

**Conditional section guidance:**
- **User Stories** — include when end users interact with the feature (web/mobile/API consumers). Omit for infrastructure changes, data pipelines, internal tooling, CLI tools, and library/SDK work where there are no human end users.
- **Scope** — include when meaningful boundaries need to be drawn or when the feature could easily be misinterpreted as covering more ground. Omit when scope is self-evident from Problem + Goal.
- **Risks & Considerations** — include when there are real technical risks (performance, security, backwards compatibility), external dependencies, or significant unknowns. Omit for well-understood, low-risk changes.

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
## User Stories   (include if relevant — see guidance above)
...
## Acceptance Criteria
...
## Scope   (include if relevant — see guidance above)
...
## Approach
...
## Risks & Considerations   (include if relevant — see guidance above)
...
```

**Parent PRDs have NO `**Branch:**` field.** They are orchestration-only — they track children but are never directly implemented. Each child PRD gets its own branch (see Step 4.5).

**Field rules:**
- **Single platform:** Include `**Platform:**` and `**Branch:**`. Omit `**Platforms:**` and `**Implementation Order:**`.
- **Multiple platforms (parent):** Include `**Platforms:**` and `**Implementation Order:**`. Omit `**Platform:**` and `**Branch:**`.

**Branch naming convention (single-platform and child PRDs):**

Use the dominant pattern detected in Step 1 (sub-step 3) if one was found. Otherwise fall back to conventional defaults:
- feature → `feat/{slug}` (or `feature/{slug}` if that prefix is dominant)
- bug-fix → `fix/{slug}` (or `bugfix/{slug}` / `hotfix/{slug}` if dominant)
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
