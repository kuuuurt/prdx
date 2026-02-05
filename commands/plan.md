---
description: "Create PRD using native plan mode"
argument-hint: "[description]"
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
```

## How It Works

This command enters **native plan mode** to:
1. Detect platform from description/codebase
2. Explore codebase architecture
3. Create PRD using the PRDX template format
4. Iterate with user until approval
5. Plan auto-saved to `~/.claude/plans/`

## Workflow

### Step 1: Platform Detection

Auto-detect platform from:

**1. Description keywords:**
- "backend", "API", "endpoint" → backend
- "Android", "Kotlin", "Compose" → android
- "iOS", "Swift", "SwiftUI" → ios
- "mobile", "app" (without platform specifics) → mobile (needs platform selection)

**2. Directory structure:**
```bash
if [ -d "backend" ]; then HAS_BACKEND=true; fi
if [ -d "android" ]; then HAS_ANDROID=true; fi
if [ -d "ios" ]; then HAS_IOS=true; fi
```

**3. Config files:**
- `package.json` + `tsconfig.json` → backend
- `build.gradle.kts` → android
- `Package.swift` → ios

**4. Mobile Platform Selection:**

If detected platform is `mobile` OR codebase has both android and ios directories:

Use **AskUserQuestion** to ask which platforms this PRD should target:

```
Question: "Which platforms should this PRD cover?"
Header: "Platforms"
Options:
  - Label: "Android & iOS (Recommended)"
    Description: "Apply to both platforms - implement sequentially"
  - Label: "Android only"
    Description: "Platform-specific feature for Android"
  - Label: "iOS only"
    Description: "Platform-specific feature for iOS"
```

### Step 2: Enter Plan Mode

Use **EnterPlanMode** tool to begin planning.

Once in plan mode:

**Use exploration agents for deeper understanding:**

- **Code exploration**: When you need to understand how existing features work, trace code paths, or find patterns:
  ```
  Task tool with subagent_type: "prdx:code-explorer"
  prompt: "How is [feature] implemented? What patterns does it follow?"
  ```

- **Documentation lookup**: When you need current API docs, library usage, or framework guidance:
  ```
  Task tool with subagent_type: "prdx:docs-explorer"
  prompt: "How do I implement [feature] with [library]? What's the current best practice?"
  ```

These agents run in isolated context and return concise summaries, keeping your planning context clean.

**Then create a PRD following this exact format:**

```markdown
# [Title]

**Type:** feature | bug-fix | refactor | spike
**Platform:** {DETECTED_PLATFORM}
**Platforms:** {PLATFORMS_LIST} (only for mobile)
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

**Branch naming convention:**
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

Use **ExitPlanMode** tool when the PRD is complete and approved.

The plan will be automatically saved to `~/.claude/plans/` with the filename `prdx-{slug}.md`.

**IMPORTANT:** Name the plan file `prdx-{slug}.md` where slug is derived from the title (kebab-case, e.g., `prdx-biometric-login.md`).

**Display summary:**
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
2. **Follow the PRD template exactly** - See CLAUDE.md for format
3. **Plans auto-save** - To `~/.claude/plans/` directory
4. **Naming convention** - `prdx-{slug}.md` (e.g., `prdx-biometric-login.md`)
5. **Status starts as `planning`** - Updated by implement/push commands
6. **Branch name in PRD** - Used by implement command
