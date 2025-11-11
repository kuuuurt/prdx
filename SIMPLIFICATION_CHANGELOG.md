# PRDX Simplification Changelog

## v0.2.0 - UX Simplification Release

**Date**: 2025-11-11
**Focus**: Developer Experience & Command Consolidation

### 🎯 Executive Summary

Reduced command count from **14 to 7 commands** (50% reduction) while adding intelligent automation and context awareness.

**Before**: Manual, repetitive workflows with many commands
**After**: Smart, automated workflows with context memory

---

## 🗑️ Removed Commands (7)

### 1. `/prdx:wizard` - DELETED (516 lines)
**Why**: Overly complex wrapper around `/prdx:plan` that forced sequential Q&A

**Replaced by**: Enhanced `/prdx:plan` with smart defaults
- Auto-infers type from description keywords
- Auto-detects platform from directory/description
- Auto-searches for duplicates
- Only asks questions that can't be inferred

**Developer win**: One command instead of 7-step wizard

---

### 2. `/prdx:list` - MERGED into `/prdx:show` (134 lines saved)
**Why**: Separate command for browsing PRDs

**Replaced by**: `/prdx:show` with no arguments
```bash
# Before:
/prdx:list --status draft --platform android

# After:
/prdx:show --status draft --platform android
```

---

### 3. `/prdx:search` - MERGED into `/prdx:show` (166 lines saved)
**Why**: Separate command for keyword search

**Replaced by**: `/prdx:show <keyword>`
```bash
# Before:
/prdx:search auth

# After:
/prdx:show auth
```

---

### 4. `/prdx:status` - MERGED into `/prdx:show` (366 lines saved)
**Why**: Separate command for detailed status

**Replaced by**: `/prdx:show <slug>`
```bash
# Before:
/prdx:status android-219

# After:
/prdx:show android-219
```

---

### 5. `/prdx:deps` - MERGED into `/prdx:show` (221 lines saved)
**Why**: Dependencies are part of status, not a separate view

**Replaced by**: Dependency section in `/prdx:show <slug>`

---

### 6. `/prdx:sync` - AUTO-SYNCS (431 lines saved)
**Why**: Manual GitHub sync is tedious and forgettable

**Replaced by**: Automatic sync in relevant commands
- `/prdx:publish` → Creates issue, saves number to PRD
- `/prdx:update` → Auto-syncs changes to issue (if linked)
- `/prdx:dev:push` → Auto-syncs PR creation to issue

**Add `--skip-sync` flag to disable if needed**

**Developer win**: Never forget to sync GitHub again

---

### 7. `/prdx:dev:check` - AUTO-RUNS (512 lines saved)
**Why**: Separate verification step is easy to skip

**Replaced by**: Automatic verification in `/prdx:dev:push`
- Runs all quality checks before creating PR
- Shows verification results
- Blocks bad PRs automatically

**Add `--skip-check` flag to override (not recommended)**

**Developer win**: Catch issues before PR, not after

---

## ✨ New Features

### 1. Context Awareness
**File**: `.prdx-context` (auto-managed)

Commands remember your last PRD:
```bash
/prdx:dev:start android-219    # Start work, sets context
/prdx:dev:start                # Continues android-219
/prdx:dev:start "add tests"    # Still android-219, with prompt
/prdx:dev:push                 # Creates PR for android-219
```

**No more repeating slug 10 times per session!**

---

### 2. Smart Type Inference
Enhanced `/prdx:plan` analyzes description for keywords:

**Keywords → Type mapping:**
- "fix", "bug", "error", "crash" → `bug-fix`
- "refactor", "simplify", "optimize" → `refactor`
- "investigate", "explore", "research" → `spike`
- Default → `feature`

```bash
# Before:
/prdx:plan "fix memory leak" --type bug-fix

# After:
/prdx:plan "fix memory leak"
→ Auto-infers: bug-fix
```

**Override with `--type` when needed**

---

### 3. Smart Platform Detection
Enhanced `/prdx:plan` detects platform from:

1. **Current directory**: `pwd` - are you in backend/, android/, ios/?
2. **Description keywords**: "API" → backend, "Compose" → android
3. **Recent PRDs**: Pattern matching from last 5 PRDs
4. **Only asks if truly ambiguous**

```bash
# Before:
/prdx:plan "add biometric login" --platform android

# After:
cd android/ && /prdx:plan "add biometric login"
→ Auto-detects: android
```

---

### 4. Auto-Duplicate Detection
Enhanced `/prdx:plan` searches existing PRDs before creating:

- Extracts key nouns from description
- Searches for similar PRDs
- Warns if >50% keyword overlap
- Prevents accidental duplicates

```bash
/prdx:plan "add biometric authentication"
→ ⚠️ Found similar: android-biometric-auth.md (draft)
→ "Is this the same work? (y/n)"
```

---

### 5. Unified Viewer
New `/prdx:show` command does 3 things intelligently:

**Mode 1 - List** (no args):
```bash
/prdx:show
→ Lists all PRDs, grouped by platform
```

**Mode 2 - Search** (keyword):
```bash
/prdx:show auth
→ Searches for "auth" in all PRDs
```

**Mode 3 - Status** (slug):
```bash
/prdx:show android-219
→ Shows detailed status dashboard
```

**One command, smart routing!**

---

### 6. Automatic Quality Checks
Enhanced `/prdx:dev:push` runs verification before PR:

**Auto-checks:**
- ✅ Acceptance criteria complete
- ✅ Implementation tasks complete
- ✅ Code quality score (agent-powered)
- ✅ Test coverage percentage
- ✅ Security & performance scan
- ✅ Git commits follow conventions

**If verification fails:**
```
⚠️ Verification Issues Found:
❌ Test Coverage: 45% (Target: 70%)
❌ Security: API keys not stored securely

Options:
1. Fix issues and run again
2. Continue anyway (not recommended)
3. Cancel
```

**Developer win**: Catch issues before creating PR

---

### 7. Automatic GitHub Sync
Commands auto-sync to GitHub issues:

**`/prdx:publish`** → Creates issue, saves #number to PRD
**`/prdx:update`** → Posts update comment to issue (if linked)
**`/prdx:dev:push`** → Posts PR link + verification results to issue

**No separate sync command needed!**

Add `--skip-sync` to any command to disable.

---

### 8. Streamlined Questions
Enhanced `/prdx:plan` asks ONLY essential questions:

**Before** (wizard):
- Project structure? (auto-detectable)
- PRD type? (inferable from description)
- Title? (use description)
- Description? (already provided)
- Search for similar? (auto-search)
- Dependencies? (optional flag)
- Slug? (auto-generate)
- Review? (always yes)

**After**:
- "Steps to reproduce?" (only for bug-fixes if not mentioned)
- "Time box?" (only for spikes, required)
- "Platform?" (only if truly ambiguous)

**From 7-8 questions → 0-2 questions**

---

## 📊 Metrics

### Code Reduction
- **Commands deleted**: 7
- **Lines removed**: ~2,400 lines
- **Command count**: 14 → 7 (50% reduction)

### UX Improvements
- **Questions asked**: 7-8 → 0-2 (75% reduction)
- **Manual steps eliminated**: 5 (check, sync, list/search, duplicate check, type selection)
- **Context memory**: 0 → Full (remembers last PRD)

### Workflow Comparison

**Before** (Full cycle):
```bash
/prdx:wizard               # 7 questions...
→ /prdx:plan                # (invoked by wizard)
/prdx:publish android-219
/prdx:list --status published
/prdx:status android-219
/prdx:dev:start android-219
# ...work...
/prdx:dev:check android-219
/prdx:dev:push android-219
/prdx:sync android-219
/prdx:close android-219
```
**Total**: 10+ command invocations, 7+ questions

**After** (Full cycle):
```bash
/prdx:plan "add biometric login"  # 0-2 questions
/prdx:dev:start
# ...work...
/prdx:dev:push
```
**Total**: 3 command invocations, 0-2 questions

**70% fewer interactions!**

---

## 🎓 Migration Guide

### Old Command → New Command

| Old | New | Notes |
|-----|-----|-------|
| `/prdx:wizard` | `/prdx:plan` | Just use plan directly |
| `/prdx:list` | `/prdx:show` | No args = list |
| `/prdx:search <keyword>` | `/prdx:show <keyword>` | Same syntax |
| `/prdx:status <slug>` | `/prdx:show <slug>` | Same syntax |
| `/prdx:deps <slug>` | `/prdx:show <slug>` | Shown in status |
| `/prdx:sync <slug>` | N/A | Auto-syncs now |
| `/prdx:dev:check <slug>` | `/prdx:dev:push <slug>` | Auto-runs first |

### Old Workflow → New Workflow

**Creating PRD:**
```bash
# Old:
/prdx:wizard
→ Answer 7 questions...

# New:
/prdx:plan "add feature"
→ Answer 0-2 questions (only if ambiguous)
```

**Finding PRD:**
```bash
# Old:
/prdx:search auth
/prdx:list --status draft
/prdx:status android-219

# New:
/prdx:show auth          # Search
/prdx:show --status draft  # List filtered
/prdx:show android-219    # Status
```

**Creating PR:**
```bash
# Old:
/prdx:dev:check android-219
/prdx:dev:push android-219
/prdx:sync android-219

# New:
/prdx:dev:push android-219
→ Checks + pushes + syncs automatically
```

**Continuing work:**
```bash
# Old:
/prdx:dev:start android-219
# ...work...
/prdx:dev:start android-219
# ...more work...

# New:
/prdx:dev:start android-219  # First time only
# ...work...
/prdx:dev:start              # Uses context
# ...more work...
```

---

## 🛠️ Breaking Changes

### Removed Commands
The following commands are **no longer available**:
- `/prdx:wizard`
- `/prdx:list`
- `/prdx:search`
- `/prdx:status`
- `/prdx:deps`
- `/prdx:sync`
- `/prdx:dev:check`

**All functionality preserved** in remaining 7 commands.

### New Context File
`.prdx-context` file created automatically (add to `.gitignore`):
```gitignore
# Add to your .gitignore:
.prdx-context
```

### Auto-Sync Behavior
Commands now sync to GitHub by default:
- Use `--skip-sync` to disable
- Set `PRDX_AUTO_SYNC=false` environment variable to disable globally

### Auto-Check Behavior
`/prdx:dev:push` now verifies by default:
- Use `--skip-check` to disable (not recommended)

---

## 📝 Documentation Updates

### Updated Files
- `commands/help.md` - Complete rewrite
- `commands/plan.md` - Added smart defaults
- `commands/dev/start.md` - Added context awareness
- `commands/dev/push.md` - Added auto-check and auto-sync
- `CLAUDE.md` - Updated with new structure
- `README.md` - Will be updated with v0.2.0 notes

### New Files
- `commands/show.md` - Unified viewer
- `.prdx-context` - Context tracking (auto-generated)
- `SIMPLIFICATION_CHANGELOG.md` - This file

### Deleted Files
- `commands/wizard.md`
- `commands/list.md`
- `commands/search.md`
- `commands/status.md`
- `commands/deps.md`
- `commands/sync.md`
- `commands/dev/check.md` (kept for reference, but not invoked directly)

---

## 🚀 Future Enhancements

### Planned (v0.3.0)
1. **AC-to-Test Validation Tool** - Enforce "every AC needs a test" rule
2. **Hook System** - Examples and templates for customization
3. **Web Platform Agent** - React/Next.js specialist
4. **Tech Lead Orchestrator** - Multi-platform coordination agent

### Under Consideration
1. Template customization per project
2. Metrics & analytics tracking
3. MCP server integrations (Linear, Jira, Sentry)
4. Dependency graph visualization

---

## 💬 Feedback

This simplification was focused on **developer experience**:
- Fewer commands to remember
- Less repetition
- Smarter automation
- Context awareness

**Is this simpler?** Let us know!
- GitHub Issues: https://github.com/kuuuurt/prdx/issues
- Discussion: https://github.com/kuuuurt/prdx/discussions

---

## 🙏 Credits

Simplification driven by UX analysis identifying:
- Command overlap (list/search/status/deps)
- Repetitive manual steps (check, sync)
- Unnecessary Q&A (wizard)
- Lack of context memory
- Missing automation opportunities

**Result**: 50% fewer commands, 70% fewer interactions, same power.
