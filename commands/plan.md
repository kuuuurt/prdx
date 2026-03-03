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
5. Plan auto-saved to `~/.claude/plans/`

## Workflow

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

If **multiple platform types detected** (e.g., backend + android, or android + ios):

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

**First, parse `--quick` flag:**
- Strip `--quick` from arguments if present
- If `--quick` is present: set `QUICK_MODE=true`

Use **EnterPlanMode** tool to begin planning.

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
**Platform:** {DETECTED_PLATFORM}
**Quick:** true
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

**Filename convention for quick mode:** `prdx-quick-{slug}.md` (e.g., `prdx-quick-fix-login-validation.md`)

**If NOT QUICK_MODE — use the full PRD template:**

```markdown
# [Title]

**Type:** feature | bug-fix | refactor | spike
**Platform:** {DETECTED_PLATFORM}   ← single platform only
**Platforms:** {PLATFORMS_LIST}      ← multiple platforms only (omit Platform)
**Implementation Order:**            ← only when Platforms has 2+ entries
1. {first step platforms}
2. {second step platforms}
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

**Field rules:**
- **Single platform:** Include `**Platform:**`, omit `**Platforms:**` and `**Implementation Order:**`
- **Multiple platforms:** Include `**Platforms:**` and `**Implementation Order:**`, omit `**Platform:**`

**Branch naming convention (both modes):**
- feature → `feat/{slug}`
- bug-fix → `fix/{slug}`
- refactor → `refactor/{slug}`
- spike → `chore/{slug}`

### Step 3: Iterate Until Approval

Present the PRD draft and iterate based on user feedback:
- Revise sections as requested
- Add/remove scope items
- Adjust approach based on discussion

When user approves (says "looks good", "approve", "let's do it", etc.), finalize the plan.

### Step 4: Exit Plan Mode

When the user approves, call **ExitPlanMode** immediately.

**IMPORTANT:** Do NOT ask "Should I exit plan mode?" or "Ready to exit?" - just call ExitPlanMode directly when the user approves the plan. The approval to exit is implicit in their approval of the plan.

**CRITICAL — Plan File Naming:**

**Quick mode:** The filename **MUST** be `prdx-quick-{slug}.md` (e.g., `prdx-quick-fix-login-validation.md`).

**Normal mode:** The filename **MUST** be `prdx-{slug}.md` (e.g., `prdx-biometric-login.md`).

This prefix is how all PRDX commands discover plans. Without it, the plan is invisible to the workflow.

- Derive `{slug}` from the title in kebab-case (e.g., "Add Biometric Login" → `biometric-login`)
- Quick mode full path: `~/.claude/plans/prdx-quick-{slug}.md`
- Normal mode full path: `~/.claude/plans/prdx-{slug}.md`

### Step 5: Verify Plan File Naming

**After ExitPlanMode**, verify the saved plan has the correct prefix:

1. Check if the plan was saved with the correct name:
   ```bash
   # Quick mode:
   ls ~/.claude/plans/prdx-quick-{slug}.md 2>/dev/null
   # Normal mode:
   ls ~/.claude/plans/prdx-{slug}.md 2>/dev/null
   ```

2. If not found, search for the plan by its title or recent creation:
   ```bash
   # Find recently created plans without prdx- prefix
   find ~/.claude/plans/ -name "*.md" -newer .prdx/last-slug -not -name "prdx-*" 2>/dev/null
   # Or search by title content
   grep -rl "^# {TITLE}" ~/.claude/plans/*.md 2>/dev/null | grep -v "prdx-"
   ```

3. If a non-prefixed plan is found, rename it:
   ```bash
   # Quick mode:
   mv ~/.claude/plans/{old-name}.md ~/.claude/plans/prdx-quick-{slug}.md
   # Normal mode:
   mv ~/.claude/plans/{old-name}.md ~/.claude/plans/prdx-{slug}.md
   ```

4. If no plan file is found at all, the plan may not have saved. Warn the user:
   ```
   Plan file not found at expected path.

   Check ~/.claude/plans/ for recently created files and rename if needed.
   ```

**Display summary:**

**Quick mode:**
```
Quick plan created and saved

PRD: ~/.claude/plans/prdx-quick-{slug}.md
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

PRD: ~/.claude/plans/prdx-{slug}.md
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

PRD: ~/.claude/plans/prdx-{slug}.md
Platforms: {PLATFORMS_LIST}
Implementation Order: {ORDER_SUMMARY}
Status: planning
Branch: {BRANCH}

Next steps:
- Run /prdx:implement {slug} to start implementation
- Or run /prdx:prdx {slug} for guided workflow
```

### Step 5.5: Save Workflow State and Decision Point

**Save last-used slug:**
```bash
mkdir -p .prdx && echo "{SLUG}" > .prdx/last-slug
```
(Use `quick-{slug}` for quick mode, e.g., `echo "quick-fix-login" > .prdx/last-slug`)

**Check if this was called from a `/prdx:prdx` workflow:**

Read `.prdx/workflow.json`:
```bash
cat .prdx/workflow.json 2>/dev/null
```

**If `.prdx/workflow.json` exists with `"phase": "planning"`** (this was called from `/prdx:prdx`):

1. Update workflow.json with the final slug and phase:
   ```bash
   cat > .prdx/workflow.json << EOF
   {"slug": "{SLUG}", "phase": "post-planning", "quick": {QUICK_VALUE}}
   EOF
   ```
   (Use the final `{SLUG}` — for quick mode, use `quick-{slug}`. `{QUICK_VALUE}` is `true` or `false` from the existing workflow.json.)

2. Show the decision point via **AskUserQuestion**:

   **Normal mode** (quick field is false):
   - Option 1: "Publish to GitHub" — Create issue for team visibility
   - Option 2: "Implement now" — Start coding immediately
   - Option 3: "Stop here" — Review PRD later

   **Quick mode** (quick field is true):
   - Option 1: "Implement now" (Recommended) — Start coding immediately
   - Option 2: "Stop here" — Review plan later

3. **Do NOT proceed beyond this AskUserQuestion.** Display the user's choice and stop. The `/prdx:prdx` workflow (if still in context) or the user's next invocation will handle routing based on the choice.

**If `.prdx/workflow.json` does NOT exist** (standalone `/prdx:plan` call):

Just display the summary above and end. No decision point needed. No workflow.json interaction.

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
3. **Plans auto-save** - To `~/.claude/plans/` directory
4. **Naming convention** - `prdx-{slug}.md` (normal) or `prdx-quick-{slug}.md` (quick mode)
5. **Status starts as `planning`** - Updated by implement/push commands
6. **Branch name in PRD** - Used by implement command
7. **Quick mode** - Adds `**Quick:** true` field, uses lightweight template, brief exploration
