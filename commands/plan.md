---
description: "Create PRD using native plan mode"
argument-hint: "[--lite] [description]"
---

## Pre-Computed Context

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-plans-dir.sh"
source "$(git rev-parse --show-toplevel)/hooks/prdx/ensure-gitignore.sh"
source "$(git rev-parse --show-toplevel)/hooks/prdx/first-run-setup.sh"
PROJECT_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
BRANCH_LIST=$(git branch -a --format='%(refname:short)' 2>/dev/null | head -50)
[ "$FIRST_RUN" = "true" ] && echo "PRDX initialized. Plans: $PLANS_DIR"
```

# /prdx:plan - Create Product Requirements Document

Uses Claude's **native plan mode** to explore the codebase and create a business-focused PRD.

**This command ONLY creates a PRD document — no application code, branches, tests, or commits.**

## Exploration Rules

> ALWAYS use `prdx:code-explorer` and `prdx:docs-explorer` agents via the Task tool for exploration.
> NEVER use Glob, Grep, Read, or `subagent_type: "Explore"` directly.

### Step 0: Parse Flags, Detect Project, and Derive Slug

**Parse `--lite` flag FIRST (before platform detection):**
- Strip `--lite` from arguments if present
- If `--lite` is present: set `LITE_MODE=true`
- If `--lite` is NOT present: set `LITE_MODE=false`

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

Extract the **core concept** (2-4 words max) from the description and convert to kebab-case to produce `{SLUG}`. Strip filler words (add, implement, create, update, fix, refactor, improve), prepositions (the, a, for, from, to, in, on, of, with), and implementation details — keep only the domain-specific nouns and key verbs. For lite mode, prefix with `lite-`.

Examples:
- "Add biometric authentication to Android app" → `biometric-auth`
- "Read monthly report directly from Firestore instead of aggregating daily reports" → `monthly-report-read`
- "Fix user login failures on slow networks" → `login-failures`
- "Refactor checkout flow to use new payment provider" → `checkout-payment-refactor`
- Lite: "fix login validation" → `lite-login-validation`

**Write state file immediately:**
```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "planning", "lite": {LITE_VALUE}}
EOF
```

This ensures the workflow is recoverable from the very start. The slug is derived from the description and stays consistent through the entire workflow — no tentative IDs needed.

### Step 1: Platform Detection

**1. Description keywords** — scan the user's description for these terms and add to `DETECTED_CONTEXTS` (deduplicated):

| keywords | context |
|---|---|
| backend, API, endpoint, server, REST, GraphQL, gRPC, microservice | `backend` |
| frontend, web, UI, React, Vue, Svelte, Next.js, HTML, CSS, browser | `frontend` |
| Android, Kotlin, Compose, Jetpack | `android` |
| iOS, Swift, SwiftUI, UIKit, Xcode | `ios` |
| mobile, app (no platform specifics) | `android` + `ios` |
| Python, Django, FastAPI, Flask, pip, conda, ML | `python` |
| Go, Golang | `go` |
| Rust, Cargo, crate | `rust` |
| Flutter, Dart | `flutter` |
| React Native, Expo | `react-native` |
| Java, Spring, Maven, Gradle (no Kotlin/Android) | `java` |
| data pipeline, ETL, dbt, Airflow, Spark, Kafka, warehouse | `data` |
| infrastructure, Terraform, Ansible, Kubernetes, k8s, Helm, IaC | `infra` |
| CLI, command line, terminal tool, shell script | `cli` |

**2. Filesystem heuristics + branch convention** — source the hook:

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/detect-platform.sh"
# → exports: DETECTED_CONTEXTS (filesystem-detected, space-separated),
#            BRANCH_PREFIX_FEAT (feat|feature), BRANCH_PREFIX_FIX (fix|bugfix|hotfix)
```

Merge the keyword-derived list with `$DETECTED_CONTEXTS` from the hook (deduplicate). Use `$BRANCH_PREFIX_FEAT` and `$BRANCH_PREFIX_FIX` when constructing branch names — they reflect the repo's dominant convention. If neither was triggered, fall back to defaults: feature→`feat/{slug}`, bug-fix→`fix/{slug}`, refactor→`refactor/{slug}`, spike→`chore/{slug}`.

**3. Multi-Platform Selection:**

**If LITE_MODE is true:** Skip multi-platform selection entirely. Auto-detect the single most relevant context from the description (prefer the most specific match). Lite mode always targets a single platform — omit `**Platforms:**` and `**Implementation Order:**` fields.

**If exactly one context is detected** AND **LITE_MODE is false:** Auto-select it without asking. No AskUserQuestion needed.

**If multiple contexts detected** AND **LITE_MODE is false:**

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

**4. Implementation Order (when 2+ platforms selected):**

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

**5. Single platform detected clearly** → use it directly (no selection needed)

### Step 2: Enter Plan Mode

> **⛔ Plan mode writes a DOCUMENT, not code. Approval = PRD ready, not permission to implement. After ExitPlanMode you MUST run Steps 4c→4.5→5→5.5 (decision point) and STOP — never call `/prdx:implement` directly.**

Use **EnterPlanMode** to begin. Explore the codebase using **ONLY the PRDX exploration agents**:

```
Task tool: subagent_type="prdx:code-explorer", prompt="[your exploration question]"
Task tool: subagent_type="prdx:docs-explorer", prompt="[your docs question]"
```

**NEVER use:** `subagent_type: "Explore"`, Glob, Grep, or Read for exploration. These pollute the main context.

### PRD Writing Style

Compress prose ruthlessly. Technical substance stays exact.

**Drop:** articles where natural, filler (just/really/basically/actually/simply/currently), pleasantries, hedging ("might", "could potentially", "it seems"), preambles ("This section describes...", "Below we outline..."), connective fluff ("however", "furthermore", "additionally"), "in order to" → "to", "the reason is because" → "because". No restating the title or type in the Problem statement.

**Preserve EXACTLY (substance, not prose — never compress, never count against budgets):**
- Code blocks and inline `backticks`
- File paths, function names, API names, type names
- **Data models, schemas, type definitions** (TypeScript interfaces, Pydantic models, SQL DDL, Protobuf, JSON Schema, etc.) — show them in full
- **Diagrams** — mermaid, ASCII art, sequence diagrams, ER diagrams, state machines
- **Example payloads** — request/response JSON, sample inputs/outputs, fixtures
- Tables, bullet hierarchy, headings
- Numbers, versions, error messages (quoted exact)

The brevity rules below apply to **explanatory prose only**. If a data model, diagram, or example belongs in the PRD, include it in full — section budgets cap surrounding sentences, not embedded artifacts.

**Style:** Fragments OK. Active voice, present tense. Short synonyms — "fix" not "implement a solution for", "use" not "utilize", "big" not "extensive". Pattern: `[thing] [action] [reason]. [next step].`

**Section budgets:**
- **Problem:** 1-3 sentences. What's broken + why it matters.
- **Goal:** 1 sentence. End state in user/business terms.
- **User Stories:** Max 3. Omit if user is obvious.
- **Acceptance Criteria:** Max 7 items. Each AC must be an **observable behavior** an engineer or QA could verify with a test or manual check — not an aspiration ("works well", "is fast"), not a solution ("uses Redis sliding window"). Start with a verb. No inline explanation. Cover the happy path AND at least one edge case or failure mode where one matters (empty input, auth failure, concurrent write, network timeout, etc.). If you have more than 7, collapse related conditions into one AC (e.g., "token is created and expires after 24h" — not two ACs).
- **Approach:** 1-3 sentences or a numbered list of explanatory prose. Direction only — mechanics go in the dev plan. Data models, schemas, and diagrams that belong here are exempt from the prose budget; show them in full.
- **Scope:** Omit by default. Include only for `spike` type or multi-platform parent PRDs. Bullets only, no prose intro.
- **Risks:** `risk → consequence` format. Max 3.

**If LITE_MODE — use this lightweight template:**

Lite mode does a brief codebase scan (not a deep dive) and uses a streamlined template:

```markdown
# [Title]

**Type:** bug-fix | feature | refactor
**Project:** {PROJECT_NAME}
**Platform:** {DETECTED_PLATFORM}
**Lite:** true
**Status:** planning
**Created:** {TODAY's DATE}
**Branch:** {BRANCH_NAME}

## Problem

[1-2 sentences — what's broken or what needs to change]

## Goal

[1 sentence — the desired outcome]

## Acceptance Criteria

- [ ] [Testable outcome]

## Approach

[1-2 sentences — how to fix/implement this]
```

Lite mode generates its own branch using the same convention as full mode (see "Branch naming convention" below). It is persistent — same lifecycle as a full PRD, just with a briefer template.

**Filename convention for lite mode:** `prdx-lite-{slug}.md` (e.g., `prdx-lite-fix-login-validation.md`)

**If NOT LITE_MODE — use the full PRD template:**

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

[1-3 sentences: what is broken/missing and why it matters]

## Goal

[1 sentence: desired end state in user/business terms]

## User Stories   ← include only when the feature has identifiable end users (omit for infra, data pipelines, CLI tools, libraries)

- As a [user type], I want to [action] so that [benefit]

## Acceptance Criteria

- [ ] [User-observable outcome - testable]
- [ ] [User-observable outcome - testable]

## Scope   ← OMIT by default. Include ONLY for `spike` type or multi-platform parent PRDs.

### Included
- [What this PRD covers]

### Excluded
- [What this PRD explicitly does NOT cover]

## Approach

[1-3 sentences or numbered steps. Direction only — no implementation details]

## Risks & Considerations   ← include only when non-trivial risks or constraints exist (omit for straightforward changes)

- [Risk → consequence. Max 3 unless genuinely more]

## Open Questions   ← include when there are genuine ambiguities that must be resolved before or during implementation (omit if there are none)

- [Question that needs an answer before / during implementation. State the decision required, not a vague concern.]
```

**Conditional section guidance:**
- **User Stories** — include when end users interact with the feature (web/mobile/API consumers). Omit for infrastructure changes, data pipelines, internal tooling, CLI tools, and library/SDK work where there are no human end users.
- **Scope** — OMIT by default. Include ONLY when type is `spike` (where bounding the exploration is the point) or for multi-platform parent PRDs (where per-platform boundaries clarify the split). For routine features, refactors, and bug-fixes, do not include this section — Problem + Goal already convey scope.
- **Risks & Considerations** — include when there are real technical risks (performance, security, backwards compatibility), external dependencies, or significant unknowns. Omit for well-understood, low-risk changes.
- **Open Questions** — include any decision that would block or stall implementation if left ambiguous (algorithm choice, ownership boundary, missing requirement, unclear edge-case behavior). Phrase each as the decision required, not a generic worry. Omit when the PRD is unambiguous.

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
## Open Questions   (include if relevant — see guidance above)
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

Lite mode uses the same branch naming convention as full mode (a new branch with `lite-{slug}` slug, e.g. `feat/lite-login-validation`).

### Step 3: Iterate Until Approval

Present the PRD draft and iterate based on user feedback:
- Revise sections as requested
- Add/remove scope items
- Adjust approach based on discussion

When the user approves (says "looks good", "approve", "let's do it"), Approval means the PRD document is ready — not permission to start implementing. Proceed to Step 4 (ExitPlanMode).

### Step 4: Save State and Exit Plan Mode

When the user approves:

**4a. Update state to `post-planning` BEFORE exiting plan mode.**

This is critical because Claude Code may offer a "clear context" option after ExitPlanMode. If the user chooses it, all post-exit steps are lost. By saving state first, re-running `/prdx:prdx` picks up from `post-planning` and shows the decision point correctly.

```bash
mkdir -p .prdx/state
cat > .prdx/state/{SLUG}.json << EOF
{"slug": "{SLUG}", "phase": "post-planning", "lite": {LITE_VALUE}}
EOF
```

**4b. Call ExitPlanMode** directly when the user approves — do not re-ask for permission to exit. If context is cleared after exit, the state file (`post-planning` from 4a) lets `/prdx:prdx` resume to the decision point.

**4c. Verify Plan File Naming:**

**Lite mode:** The filename **MUST** be `prdx-lite-{slug}.md` (e.g., `prdx-lite-fix-login-validation.md`).

**Normal mode:** The filename **MUST** be `prdx-{slug}.md` (e.g., `prdx-biometric-login.md`).

This prefix is how all PRDX commands discover plans. Without it, the plan is invisible to the workflow.

- Lite mode full path: `{PLANS_DIR}/prdx-lite-{slug}.md`
- Normal mode full path: `{PLANS_DIR}/prdx-{slug}.md`

### Step 4.5: Auto-Generate Child PRDs (Multi-Platform Only)

**Only run this step if ALL of the following are true:**
- `LITE_MODE` is `false`
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
echo '{"slug": "{parent-slug}-{platform}", "phase": "planning", "lite": false, "parent": "{parent-slug}"}' > .prdx/state/{parent-slug}-{platform}.json
```

### Step 4.6: Append Codebase Context to PRD

**Run this step after Step 4.5 (or after Step 4b if single-platform) for normal-mode PRDs only.**

**Skip conditions:**
- If `LITE_MODE=true` → skip entirely (lite PRDs use a streamlined template; codebase context is not worth the overhead).
- If the PRD is a multi-platform parent → write `## Codebase Context` into the **parent PRD only**. Children inherit context via the parent reference and do not get their own section.

**Construct the section from exploration summaries gathered during plan-mode Step 2.** Each Task tool result from `prdx:code-explorer` already has the right section structure — concatenate and deduplicate. The section seeds dev-planner; it is not a place to document the exploration.

**Hard caps (enforce these — do not exceed):**
- **Summary:** ≤3 sentences.
- **Key Files:** ≤8 bullets, one line each (`path — short description`).
- **Patterns Found:** ≤5 bullets, one line each.
- **No prose tables, no per-file maps, no algorithm writeups, no nested headings beyond `###`.** (Data-model tables and schema definitions discovered in the codebase are substance, not prose — keep them if load-bearing.)
- **Relevant Snippets:** omit unless a specific quote is load-bearing for the dev plan; if included, ≤2 snippets, ≤10 lines each.

**Format:**

```markdown
## Codebase Context

*Captured during planning — dev-planner uses this in preference to re-exploring.*

### Summary
[≤3 sentences]

### Key Files
- `path/to/file.ext` — [≤1 line]

### Patterns Found
- [≤1 line]
```

**Append to PRD file — this section MUST be the last section in the file.**

**This is a write-once step.** If plan mode is resumed (user exits and re-enters), do NOT re-run this append — the section already exists. Check first:

```bash
grep -q '^## Codebase Context' "{PLANS_DIR}/prdx-{slug}.md" || cat >> "{PLANS_DIR}/prdx-{slug}.md" << 'EOF'

## Codebase Context

*Captured during planning — dev-planner uses this in preference to re-exploring.*

### Summary
{2-3 sentence overview from code-explorer output}

### Key Files
{bullet list of relevant files from code-explorer output}

### Patterns Found
{bullet list of architectural/coding patterns observed}
EOF
```

Omit `### Relevant Snippets` if none are worth capturing.

---

### Step 5: Verify Plan File Naming

**After ExitPlanMode**, verify the saved plan has the correct prefix:

1. Check if the plan was saved with the correct name:
   ```bash
   # Lite mode:
   ls {PLANS_DIR}/prdx-lite-{slug}.md 2>/dev/null
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
   # Lite mode:
   mv {PLANS_DIR}/{old-name}.md {PLANS_DIR}/prdx-lite-{slug}.md
   # Normal mode:
   mv {PLANS_DIR}/{old-name}.md {PLANS_DIR}/prdx-{slug}.md
   ```

4. If no plan file is found at all, the plan may not have saved. Warn the user:
   ```
   Plan file not found at expected path.

   Check {PLANS_DIR}/ for recently created files and rename if needed.
   ```

**Display summary:**

**Lite mode:**
```
Lite plan created and saved

PRD: {PLANS_DIR}/prdx-lite-{slug}.md
Platform: {PLATFORM}
Status: planning
Branch: {BRANCH}

Next steps:
- Run /prdx:implement lite-{slug} to start implementation
- Or run /prdx:prdx lite-{slug} for guided workflow
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

Show the decision point via **AskUserQuestion** and STOP — display the choice only; do not call `/prdx:implement` or start coding. The parent workflow handles routing.

**Options (same for lite and normal mode):**
- "Publish to GitHub" — Create issue for team visibility
- "Implement now" — Start coding immediately
- "Stop here" — Review PRD later

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

### --lite

Use lightweight template for small changes that still need a branch and PR:
```bash
/prdx:plan --lite "fix login validation"
```

Creates `prdx-lite-{slug}.md` with a streamlined template (Problem, Goal, AC, Approach only). No User Stories, Scope, or Risks sections. Brief codebase scan instead of deep exploration. Generates its own branch and persists for the full lifecycle (same as full mode, just briefer).

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
2. **Follow the PRD template exactly** - Full template for normal mode, lightweight for `--lite`
3. **Plans auto-save** - To `{PLANS_DIR}/` directory
4. **Naming convention** - `prdx-{slug}.md` (normal) or `prdx-lite-{slug}.md` (lite mode)
5. **Status starts as `planning`** - Updated by implement/push commands
6. **Branch name in PRD** - Used by implement command
7. **Lite mode** - Adds `**Lite:** true` field, uses lightweight template, brief exploration. Same lifecycle as full mode (own branch, persistent PRD).
