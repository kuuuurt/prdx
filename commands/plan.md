---
description: "Create implementation plan by delegating to Plan agent"
argument-hint: "[description]"
---

# /prdx:plan - Create Product Requirements Document

Delegates to the `prdx:planner` agent to explore the codebase and create a business-focused PRD.

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

This command is a **thin wrapper** that:
1. Runs pre-plan validation hook (if exists)
2. Detects platform from description/codebase
3. Invokes `prdx:planner` agent (runs in isolated context)
4. Agent explores codebase and creates PRD
5. Agent handles interactive iteration until approval
6. Returns PRD document (file contents stay in agent's context)
7. Writes PRD file

## Workflow

### Phase 1: Pre-Plan Hook

Run validation hook if it exists:

```bash
if [ -f hooks/prdx/pre-plan.sh ]; then
  ./hooks/prdx/pre-plan.sh
fi
```

Hook validates:
- Git repository exists
- `.claude/prds/` directory exists
- PRDs are in `.gitignore`

### Phase 2: Platform Detection

Auto-detect platform from:

**1. Description keywords:**
- "backend", "API", "endpoint" → backend
- "Android", "Kotlin", "Compose" → android
- "iOS", "Swift", "SwiftUI" → ios

**2. Directory structure:**
```bash
if [ -d "backend" ]; then PLATFORM="backend"; fi
if [ -d "android" ]; then PLATFORM="android"; fi
if [ -d "ios" ]; then PLATFORM="ios"; fi
```

**3. Config files:**
- `package.json` + `tsconfig.json` → backend
- `build.gradle.kts` → android
- `Package.swift` → ios

If ambiguous, ask user to clarify.

### Phase 3: Invoke Planner Agent

Use Task tool with prdx:planner agent:

```
subagent_type: "prdx:planner"

prompt: "Create a PRD for: {DESCRIPTION}

**Platform:** {PLATFORM}

Explore the codebase, assess feasibility, and create a business-focused PRD.
Iterate with the user until they approve the plan.

When approved, return the final PRD document."
```

**Agent runs in isolated context:**
- Explores codebase (file contents stay in agent's context)
- Creates PRD draft
- Handles user iteration
- Returns only the PRD document

### Phase 4: Write PRD File

After agent returns approved PRD:

**Generate slug:**
```bash
# Convert title to kebab-case
SLUG=$(echo "{TITLE}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')

# Add platform prefix for clarity
if [ "{PLATFORM}" != "backend" ]; then
  SLUG="{PLATFORM}-${SLUG}"
fi
```

**Write PRD:**
```bash
PRD_FILE=".claude/prds/${SLUG}.md"
echo "{PRD_CONTENT}" > "$PRD_FILE"
```

**Display summary:**
```
PRD created and saved

PRD: .claude/prds/{SLUG}.md
Platform: {PLATFORM}
Status: planning

Next steps:
1. Review the plan in the PRD file
2. Run `/prdx:implement {SLUG}` to start implementation
3. Or edit the PRD manually if needed

To implement: /prdx:implement {SLUG}
To view: /prdx:show {SLUG}
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

### Hook Validation Failed

```
Pre-plan validation failed

Check hooks/prdx/pre-plan.sh output above

Fix the issues and try again.
```

### Platform Detection Ambiguous

```
Could not detect platform from description

Please specify with --platform flag:
  /prdx:plan "description" --platform=backend
  /prdx:plan "description" --platform=android
  /prdx:plan "description" --platform=ios
```

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

## Context Efficiency

The `prdx:planner` agent runs in an **isolated context**:

| What stays in agent context | What returns to main conversation |
|-----------------------------|-----------------------------------|
| All explored file contents | PRD document only (~2KB) |
| Architecture analysis | Suggested slug |
| Similar feature research | Approval status |

This keeps the main conversation context small.

## Examples

### Example 1: New Feature

```
User: /prdx:plan "add biometric login to Android app"

→ Pre-plan hook validates environment
→ Platform detected: android
→ prdx:planner agent invoked (isolated context)
→ Agent explores codebase
→ Agent creates PRD draft
→ Agent displays for user review
→ User: "looks good"
→ Agent returns approved PRD
→ PRD written to .claude/prds/android-biometric-login.md

PRD created and saved

PRD: .claude/prds/android-biometric-login.md
Platform: android
Status: planning

To implement: /prdx:implement android-biometric-login
```

### Example 2: With Iteration

```
User: /prdx:plan "fix crash when API returns null user"

→ Agent creates initial PRD
→ User: "Can we also add better error logging?"
→ Agent revises PRD
→ User: "approve"
→ PRD written to file
```

## Implementation Notes

### Agent vs Native Plan Agent

| Before | After |
|--------|-------|
| Native Plan agent | prdx:planner agent |
| File contents in main context | File contents in agent context |
| PRD + all explored files | PRD only |

### Division of Labor

```
/prdx:plan
└── prdx:planner → PRD (what, why, high-level how)

/prdx:implement
├── prdx:dev-planner → Dev Plan (detailed how)
└── prdx:{platform}-developer → Code (execution)
```
