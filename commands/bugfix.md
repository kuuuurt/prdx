---
description: "Quick bug fix workflow without PRD overhead"
argument-hint: "[description]"
---

## Pre-Computed Context

```bash
echo "=== Git Context ==="
echo "Branch: $(git branch --show-current)"
echo "Default: $(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')"
git status --short
```

# /prdx:bugfix - Lightweight Bug Fix

Streamlined workflow for quick bug fixes: **create branch → fix → review → PR**. No PRD, no dev-planner — just the platform agent fixing the bug directly.

## Usage

```bash
/prdx:bugfix "fix login validation not checking empty email"
/prdx:bugfix "crash on profile screen when avatar is nil"
/prdx:bugfix                                                    # Prompts for description
```

## How It Works

This command is a **simplified version of `/prdx:implement`**:
- Skips PRD creation
- Skips dev-planner (platform agent explores codebase itself)
- Creates a `fix/` branch automatically
- Runs code review after fix
- Creates PR via `/prdx:push` (standalone mode)

## Workflow

### Step 1: Get Bug Description

**If description provided:** Use it directly.

**If no description:**
Ask the user to describe the bug:
```
What bug are you fixing?

Describe the issue — what's broken, where it happens, and any error messages.
```

### Step 2: Load Configuration

**IMPORTANT: Read and parse prdx.json (same as /prdx:implement).**

1. Check for config file:
   - `prdx.json` (project root)
   - `.prdx/prdx.json`

2. Extract commit configuration values (format, coAuthor, extendedDescription).

3. If no config file, use defaults:
   - format: "conventional"
   - coAuthor.enabled: true
   - coAuthor.name: "Claude"
   - coAuthor.email: "noreply@anthropic.com"
   - extendedDescription.enabled: true
   - includeClaudeCodeLink: true

### Step 3: Detect Platform

Auto-detect platform from description keywords and codebase structure:

**From description:**
- "backend", "API", "endpoint", "server", "route" → backend
- "frontend", "web", "component", "page", "React", "Vue" → frontend
- "Android", "Kotlin", "Compose", "ViewModel" → android
- "iOS", "Swift", "SwiftUI", "UIKit" → ios

**From codebase (if description is ambiguous):**
```bash
# Check what exists
[ -f "package.json" ] && HAS_BACKEND=true
[ -d "android" ] || [ -f "build.gradle.kts" ] && HAS_ANDROID=true
[ -d "ios" ] || [ -f "Package.swift" ] && HAS_IOS=true
```

**If ambiguous (multiple platforms detected):**

Use AskUserQuestion:
```
Question: "Which platform is this bug on?"
Header: "Platform"
Options:
  - Label: "Backend"
    Description: "Server-side, API, or service issue"
  - Label: "Frontend"
    Description: "Web UI, component, or browser issue"
  - Label: "Android"
    Description: "Android app issue"
  - Label: "iOS"
    Description: "iOS app issue"
```

Only show options for platforms that exist in the codebase.

**If only one platform exists:** Use it automatically, no need to ask.

### Step 4: Create Branch

Generate a branch name from the description:

1. Slugify the description: lowercase, replace spaces with hyphens, remove special characters, truncate to 50 chars
2. Prefix with `fix/`:

```bash
# Example: "fix login validation not checking empty email"
# → fix/login-validation-not-checking-empty-email

BRANCH="fix/{SLUG}"
```

3. Ensure we're on the default branch first:
```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
git checkout "$DEFAULT_BRANCH"
git pull --ff-only origin "$DEFAULT_BRANCH" 2>/dev/null || true
```

4. Create and checkout the fix branch:
```bash
git checkout -b "$BRANCH"
```

Display:
```
Branch: {BRANCH}
Platform: {PLATFORM}
```

### Step 5: Build Commit Instructions

**Build commit instructions from prdx.json config (same logic as /prdx:implement Step 5b).**

Build based on config values:
- Format: conventional or simple
- Extended description: enabled or disabled
- Claude Code link: enabled or disabled
- Co-author: enabled or disabled

Include an example commit showing the exact format.

### Step 6: Invoke Platform Agent

Determine agent:
- backend → `prdx:backend-developer`
- frontend → `prdx:frontend-developer`
- android → `prdx:android-developer`
- ios → `prdx:ios-developer`

```
subagent_type: "{AGENT}"

prompt: "Fix this bug.

Bug Description: {DESCRIPTION}

Platform: {PLATFORM}

**YOUR ROLE:**

You are fixing a bug. There is no PRD or dev plan — explore the codebase yourself to understand the issue and implement the fix.

**CRITICAL - COMMIT FORMAT:**

You MUST follow the commit configuration below. This is from the project's prdx.json and OVERRIDES any defaults.

{COMMIT_INSTRUCTIONS from Step 5}

**Instructions:**

1. **Explore the codebase** to understand:
   - Where the bug likely lives
   - How the affected feature works
   - What tests exist for this area

2. **Write a failing test** that reproduces the bug (if testable)

3. **Fix the bug** — keep changes minimal and focused

4. **Verify the fix:**
   - Run existing tests to ensure no regressions
   - Run new test to confirm fix

5. **Commit the fix** using the format above

**Return only a summary:**

```markdown
## Bug Fix Summary

### Root Cause
[What caused the bug]

### Fix
[What was changed and why]

### Files Modified
- [List files]

### Tests
- [Tests added/modified]

### Commits
- [Commit messages]
```
"
```

### Step 7: Code Review

After the platform agent completes, run code review:

```
subagent_type: "prdx:code-reviewer"

prompt: "Review this bug fix.

Bug Description: {DESCRIPTION}

Review the diff (git diff {DEFAULT_BRANCH}..HEAD) for:
- Does the fix address the described bug?
- Any regressions introduced?
- Security issues?
- Missing edge cases?

Only report high-confidence issues.

Return only the review summary."
```

**If issues found:**
1. Display review summary
2. Feed issues back to platform agent for fixing:

```
subagent_type: "{AGENT}"

prompt: "Fix the following code review issues from your bug fix.

{REVIEW_ISSUES}

Fix each issue, run tests, and commit the fixes.

Return only a summary of fixes applied."
```

3. Re-review (max 2 cycles, same as /prdx:implement)

**If 2 cycles exhausted:**

Use AskUserQuestion:
- Option 1: "Proceed to PR" (Recommended) — Create PR with remaining issues noted
- Option 2: "Fix manually" — Stop here, let user fix
- Option 3: "Abort" — Discard branch and changes

### Step 8: Create PR

After review passes (or user chose to proceed):

Display summary and ask:

```
Bug fix complete!

Branch: {BRANCH}
Platform: {PLATFORM}

{FIX_SUMMARY}
```

Use AskUserQuestion:
- Option 1: "Create PR" (Recommended)
- Option 2: "Test first" — Let me verify before creating PR
- Option 3: "Stop here" — I'll create the PR later

**If Create PR:**

Run `/prdx:push` (standalone mode — no PRD exists, so it auto-detects standalone).

**If Test first:**
```
Test the fix and create PR when ready:
  /prdx:push
```

**If Stop here:**
```
Fix is on branch: {BRANCH}

When ready:
  /prdx:push          # Create PR
  /prdx:commit        # Commit additional changes
```

## Error Handling

### No Description

```
What bug are you fixing?

Describe the issue — what's broken, where it happens, and any error messages.

Example: /prdx:bugfix "login fails when email contains plus sign"
```

### Uncommitted Changes

```
You have uncommitted changes on the current branch.

Options:
1. Stash changes (git stash)
2. Commit changes first
3. Cancel
```

Use AskUserQuestion with these options.

### Branch Already Exists

```bash
# If fix/ branch already exists
git checkout "$BRANCH"
```

Inform user:
```
Branch {BRANCH} already exists. Switching to it.

Existing commits:
{LIST_EXISTING_COMMITS}

Continue fixing on this branch? (y/n)
```

## Examples

### Basic Bug Fix

```
User: /prdx:bugfix "crash when user avatar is nil"

→ Platform detected: iOS (from "nil" keyword + codebase)
→ Branch created: fix/crash-when-user-avatar-is-nil
→ prdx:ios-developer agent invoked
→ Agent finds bug, writes test, fixes it
→ prdx:code-reviewer validates fix
→ Asks: Create PR?
→ User: Yes
→ /prdx:push creates standalone PR

Bug fix complete!

PR: #47
URL: https://github.com/user/repo/pull/47
```

### Interactive Bug Fix

```
User: /prdx:bugfix

→ Asks: What bug are you fixing?
→ User: "the search endpoint returns 500 when query is empty"
→ Platform detected: backend
→ Branch created: fix/search-endpoint-returns-500-when-query-empty
→ prdx:backend-developer agent fixes it
→ Code review passes
→ Asks: Create PR?
→ User: Test first
→ Shows: Test the fix and create PR when ready: /prdx:push
```

## Key Points

1. **No PRD required** — Standalone workflow
2. **No dev-planner** — Platform agent explores and fixes directly
3. **Auto-detects platform** — From description and codebase
4. **Respects prdx.json** — Commit format, co-author, etc.
5. **Code review included** — Same quality gate as /prdx:implement
6. **PR via /prdx:push** — Reuses standalone mode
7. **Minimal overhead** — Branch → Fix → Review → PR
